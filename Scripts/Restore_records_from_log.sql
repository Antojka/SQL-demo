
USE db
GO
--=================================================================================
--CREATE LOGGED TABLE 

DROP TABLE IF EXISTS dbo.tbl

CREATE TABLE dbo.tbl(
	Col1 NVARCHAR(10) NOT NULL,
	Col2 NVARCHAR(10) NOT NULL,
	Col3 NVARCHAR(10) NOT NULL,
	Col4 NVARCHAR(10) NOT NULL
)

--=================================================================================
--TABLE TO SAVE LOG

DROP TABLE IF EXISTS dbo.LogData

CREATE TABLE [dbo].[LogData](
	[id] BIGINT IDENTITY(1,1) NOT NULL,
	[Base_ID] BIGINT NOT NULL,
	[Table_ID] BIGINT NOT NULL,
	[DateAdd] DATETIME NOT NULL,
	[is_type] INT NOT NULL,
	[Proc_ID] BIGINT NULL,
	[SystemUser] NVARCHAR(100) NULL,
	[Str_json]  NVARCHAR(MAX) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

--=================================================================================
--TRIGGER TO WRITE LOG

CREATE OR ALTER TRIGGER [dbo].[LogActions] ON [dbo].[tbl] AFTER DELETE, INSERT
AS 
BEGIN

	DECLARE @Base_ID AS BIGINT
	DECLARE @Table_ID AS BIGINT

	SELECT @Base_ID = database_id
	FROM SYS.DATABASES
	WHERE name = 'db' -- replace with your database name

	SELECT @Table_ID  = OBJECT_ID ('db.dbo.tbl') -- replace with your table name

	IF EXISTS (SELECT * FROM Deleted) AND NOT EXISTS(SELECT * FROM Inserted) 
	BEGIN
		INSERT INTO dbo.LogData
		(Base_ID, Table_ID, [DateAdd], is_type, Proc_ID, SystemUser, Str_json)
		SELECT 
			@Base_ID, 
			@Table_ID, 
			GETDATE(), 
			1, 
			@@PROCID, 
			SYSTEM_USER, 
			(SELECT D.* FOR JSON PATH)
		FROM Deleted D
	END

	IF EXISTS (SELECT * FROM Inserted) AND NOT EXISTS(SELECT * FROM Deleted)
	BEGIN
		INSERT INTO dbo.LogData
		(Base_ID, Table_ID, [DateAdd], is_type, Proc_ID, SystemUser, Str_json)
		SELECT 
			@Base_ID, 
			@Table_ID,
			GETDATE(), 
			0, 
			@@PROCID, 
			SYSTEM_USER, 
			(SELECT I.* FOR JSON PATH)
		FROM Inserted I
	END
END

--=================================================================================
--CREATE TEST DATA

INSERT INTO dbo.tbl
SELECT 
	LEFT(NEWID(), 10) AS Col1,
	LEFT(NEWID(), 10) AS Col2,
	LEFT(NEWID(), 10) AS Col3,
	LEFT(NEWID(), 10) AS Col4
FROM STRING_SPLIT(REPLICATE('#', 99), '#')

--=================================================================================
--PROCEDUTE TO RESTORE DELETED RECORDS

CREATE OR ALTER  PROCEDURE [dbo].[RestoreRecords] (
	@IDs NVARCHAR(MAX) -- delimitered list of ids
)
AS
BEGIN
	DECLARE @FirstJson AS NVARCHAR(MAX)
	DECLARE @Base_ID AS BIGINT
	DECLARE @Table_ID AS BIGINT
	DECLARE @ColNames AS NVARCHAR(MAX)
	DECLARE @ColCount AS INTEGER
	DECLARE @DynamicSQL AS NVARCHAR(MAX)
	

	DECLARE @TargetTable AS NVARCHAR(100)

	SELECT TOP 1 
		@FirstJson = Str_json,
		@Base_ID = Base_ID,
		@Table_ID = Table_ID
	FROM dbo.LogData
	WHERE id in (SELECT Value FROM STRING_SPLIT(@IDs, ','))
		AND is_type = 1

	SELECT @ColNames = STRING_AGG(KeyVal.[key], ',')
	FROM OPENJSON(@FirstJson) Obj
		OUTER APPLY OPENJSON(Obj.value) KeyVal

	SELECT @ColCount = COUNT(*)
	FROM STRING_SPLIT(@ColNames, ',')

	DROP TABLE IF EXISTS #ParsedJson

	CREATE TABLE #ParsedJson (
		Rnum BIGINT IDENTITY NOT NULL, 
		Keys NVARCHAR(100) NOT NULL, 
		Val NVARCHAR(MAX) NOT NULL
	)

	INSERT INTO #ParsedJson
	SELECT 
		KeyVal.[key] AS Keys,
		KeyVal.[value] AS Val
	FROM dbo.LogData
		OUTER APPLY OPENJSON(Str_json) Obj
		OUTER APPLY OPENJSON(Obj.Value) KeyVal
	WHERE id in (SELECT Value FROM STRING_SPLIT(@IDs, ','))
		AND is_type = 1

	DROP TABLE IF EXISTS #RowGroups

	SELECT
		Keys,
		Val,
		SUM(CASE WHEN (Rnum - 1) % @ColCount = 0 THEN 1 ELSE 0 END) OVER(ORDER BY Rnum) AS RowGroup
	INTO #RowGroups
	FROM #ParsedJson

	SELECT @TargetTable = CONCAT(Db.Name, '.', OBJECT_SCHEMA_NAME (@Table_ID , @Base_ID), '.', OBJECT_NAME (@Table_ID, @Base_ID))
	FROM sys.databases Db
	WHERE database_id = @Base_ID

	SET @DynamicSQL  = '
			INSERT INTO ' + @TargetTable  + ' 
			SELECT ' + @ColNames + ' 
			FROM #RowGroups 
			PIVOT (
				MAX(Val) 
				FOR Keys IN (' + @ColNames  + ')
			) AS Pvt
	'
	EXEC(@DynamicSQL)	

	DROP TABLE IF EXISTS #ParsedJson
	DROP TABLE IF EXISTS #RowGroups
	
END


--=================================================================================
--DELETE TO LOG THIS OPERATION

DELETE FROM dbo.tbl

--=================================================================================
--CHECK LOGDATA

SELECT * FROM dbo.LogData

--=================================================================================
--TEST RESTORE

DECLARE @IDs_list AS NVARCHAR(MAX)

SELECT @IDs_list = STRING_AGG(id, ',')
FROM dbo.LogData
WHERE is_type = 1

EXEC dbo.RestoreRecords @IDs = @IDs_list

SELECT * FROM dbo.tbl
	