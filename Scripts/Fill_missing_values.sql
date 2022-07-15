USE db
GO

--===============================================================================================
-- CREATE TEST DATA

DROP TABLE IF EXISTS dbo.tbl

CREATE TABLE dbo.tbl (
	Fin_period INT NOT NULL,
	Fin_item NVARCHAR(100) NOT NULL,
	Amount FLOAT NOT NULL
)

INSERT INTO dbo.tbl
SELECT 
	Fin_period,
	Fin_item,
	Amount
FROM (
	SELECT 
		 202000 + VALUE AS Fin_period, 
		'Salaty' AS Fin_item,
		ABS(CHECKSUM(NEWID())) % 100 AS  Amount
	FROM STRING_SPLIT('1,2,3,4,5,6,7,8,9,10,11,12', ',')

	UNION ALL

	SELECT 
		 202000 + VALUE AS Fin_period, 
		'Rent' AS Fin_item,
		ABS(CHECKSUM(NEWID())) % 100 AS  Amount
	FROM STRING_SPLIT('1,2,3,4,5,6,7,8,9,10,11,12', ',')

	UNION ALL

	SELECT 
		 202000 + VALUE AS Fin_period, 
		'Business trips' AS Fin_item,
		ABS(CHECKSUM(NEWID())) % 100 AS  Amount
	FROM STRING_SPLIT('1,2,5,6,7,8,10,11', ',') -- There is no Business trip in 3,4,9,12 months

	UNION ALL

	SELECT 
		 202000 + VALUE AS Fin_period, 
		'Penalty' AS Fin_item,
		ABS(CHECKSUM(NEWID())) % 100 AS  Amount
	FROM STRING_SPLIT('1,5,8,11', ',') -- 'ØThere is no Penalty in 2,3,4,6,7,9,10,12 months
) AS t(Fin_period, Fin_item, Amount)


ALTER TABLE dbo.tbl ADD Fin_year AS CAST(LEFT(Fin_period, 4) AS INT), Fin_month AS CAST(RIGHT(Fin_period, 2) AS INT)

CREATE INDEX IX_item_period ON dbo.tbl(Fin_item, Fin_year, Fin_month)

--===============================================================================================
-- PROCEDURE ADD ZERO IN MISSING MONTHS

CREATE OR ALTER PROCEDURE dbo.Fill_missing_values
AS
BEGIN

DECLARE @Check_string NVARCHAR(26) = N'1,2,3,4,5,6,7,8,9,10,11,12' -- required month set

SET @Check_string = replace(@Check_string, '10,11,12', 'o,n,d') -- for function TRANSLATE change 10,11,12 to october, november, december

;WITH Cte_need_add AS (
	SELECT
		Fin_item,
		Fin_year,
		REPLACE(REPLACE(REPLACE(need_add , ',', ',#'),'#,', ''), '#', '') AS need_add
	FROM (
		SELECT
			Fin_item,
			Fin_year,
			TRANSLATE(@Check_string, Month_list, REPLICATE(',', LEN(Month_list))) AS need_add
		FROM (
			SELECT
				Fin_item,
				Fin_year,
				STRING_AGG(
					CASE WHEN Fin_month = 10 THEN N'o'  -- for function TRANSLATE change 10,11,12 to october, november, december
						 WHEN Fin_month = 11 THEN N'n'
						 WHEN Fin_month = 12 THEN N'd' 
						 ELSE CAST(Fin_month AS NVARCHAR(1))
					END
				, ',') AS Month_list
			FROM dbo.tbl
			GROUP BY 
				Fin_item, 
				Fin_year
		) AS t
		WHERE Month_list != @Check_string --IX_item_period provide correct order
	) AS t
)

SELECT 
	CAST(CONCAT(Fin_year, RIGHT(CONCAT('0', Fin_month), 2)) AS INT) AS Fin_period,
	Fin_item,
	Amount
FROM (
	SELECT
		Fin_year,
		CASE WHEN VALUE = N'o' THEN N'10' 
			 WHEN VALUE = N'n' THEN N'11'
			 WHEN VALUE = N'd' THEN N'12' 
			 ELSE VALUE
		END AS Fin_month,
		Fin_item,
		0 AS Amount
	FROM Cte_need_add
	CROSS APPLY STRING_SPLIT(TRIM(',' FROM need_add), ',')
) AS t

END
;

--===============================================================================================
-- TEST

EXEC dbo.Fill_missing_values