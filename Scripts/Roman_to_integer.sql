DECLARE @RomeNumber AS NVARCHAR(100) = 'XIX'
DECLARE @ModRomeNumber AS NVARCHAR(100) = ''

SET @ModRomeNumber = REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(@RomeNumber,'IV','IIII'),
											'XL','XXXX'
										),
										'IX','VIIII'
									),
									'XC','LXXXX'
								),
								'CD','CCCC'
							),
							'CM','DCCCC'
						)


SELECT SUM(Int_) AS Int_
FROM (
	SELECT SUBSTRING(s.S, t.N, 1) as Chr
	FROM (SELECT @ModRomeNumber AS S) AS s
	INNER JOIN (
		SELECT
			ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS N
		FROM STRING_SPLIT(REPLICATE('#', LEN(@ModRomeNumber)), '#')
	) AS t
	ON  t.N <= LEN(s.S)
) AS w
LEFT JOIN (
	VALUES 
		('I', 1), 
		('V', 5), 
		('X', 10), 
		('L', 50), 
		('C', 100), 
		('D', 500), 
		('M', 1000)
) AS d(Rome, Int_)
ON w.Chr = d.Rome