USE db
GO

--===================================================================================================================================
--TABLE FUNCTION TO MULTIPLICATION MATRIXES

CREATE TYPE MATRIXTYPE AS TABLE (R INT, a1 DECIMAL(38,0), a2 DECIMAL(38,0))

CREATE OR ALTER FUNCTION dbo.Matrix_multiplication(
	@MATRIX1 MATRIXTYPE READONLY,
	@MATRIX2 MATRIXTYPE READONLY
)
RETURNS TABLE 
AS 
RETURN(
	SELECT 
		R,
		CASE WHEN R = 1 THEN (SELECT f.a1 * s.a1 FROM @MATRIX2 AS s WHERE R = 1) + (SELECT f.a2 * s.a1 FROM @MATRIX2 AS s WHERE R = 2)
			 ELSE (SELECT f.a1 * s.a1 FROM @MATRIX2 AS s WHERE R = 1) + (SELECT f.a2 * s.a1 FROM @MATRIX2 AS s WHERE R = 2)
		END AS a1,
		CASE WHEN R = 1 THEN (SELECT f.a1 * s.a2 FROM @MATRIX2 AS s WHERE R = 1) + (SELECT f.a2 * s.a2 FROM @MATRIX2 AS s WHERE R = 2)
			 ELSE (SELECT f.a1 * s.a2 FROM @MATRIX2 AS s WHERE R = 1) + (SELECT f.a2 * s.a2 FROM @MATRIX2 AS s WHERE R = 2)
		END AS a2
	FROM @MATRIX1 AS f
)

--===================================================================================================================================
-- SCALAR FUNCTION RETURN "N" MEMBER OF FIBO SIQUENCE

CREATE OR ALTER FUNCTION dbo.Get_N_member_Fibonachi_seq(@N BIGINT)
RETURNS DECIMAL(38,0)
AS
BEGIN	
	
	DECLARE @TEMP AS MATRIXTYPE 
	DECLARE @MATRIX AS MATRIXTYPE 
	DECLARE @SQUARE_MATRIX AS MATRIXTYPE 
	DECLARE @I AS INT = 2
	DECLARE @FIBO AS DECIMAL(38,0) = 0

	INSERT INTO @MATRIX
	SELECT
		ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) as R,
		a1,
		a2
	FROM (VALUES(0,1),(1,1)) AS t(a1, a2)

	INSERT INTO @SQUARE_MATRIX
	SELECT R, a1, a2 
	FROM dbo.Matrix_multiplication(@MATRIX, @MATRIX)

	IF @N = 0 RETURN 0

	IF @N = 1 OR @N = 2  RETURN 1

	IF @N = 3 RETURN 2

	IF @N >= 4 AND @N % 2 = 0
	BEGIN
		INSERT INTO  @TEMP
		SELECT * FROM @SQUARE_MATRIX

		WHILE @I < @N
		BEGIN
			SET @I = @I + 2

			UPDATE t
			SET t.a1 = f.a1, t.a2 = f.a2
			FROM @TEMP AS t
			INNER JOIN dbo.Matrix_multiplication(@TEMP, @SQUARE_MATRIX) AS f
			ON t.R = f.R
		END
	END

	IF @N >= 5 AND @N % 2 = 1
	BEGIN
		INSERT INTO  @TEMP
		SELECT * FROM @SQUARE_MATRIX

		WHILE @I < @N - 1
		BEGIN
			SET @I = @I + 2

			UPDATE t
			SET t.a1 = f.a1, t.a2 = f.a2
			FROM @TEMP AS t
			INNER JOIN dbo.Matrix_multiplication(@TEMP, @SQUARE_MATRIX) AS f
			ON t.R = f.R
		END

		UPDATE t
		SET t.a1 = f.a1, t.a2 = f.a2
		FROM @TEMP AS t
		INNER JOIN dbo.Matrix_multiplication(@TEMP, @MATRIX) AS f
		ON t.R = f.R

	END

	SELECT @FIBO = a2
	FROM @TEMP
	WHERE R = 1

	RETURN @FIBO
	
END

--===================================================================================================================================
-- TEST
SELECT dbo.Get_N_member_Fibonachi_seq(100) AS FIBO


