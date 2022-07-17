DECLARE @Phrase AS NVARCHAR(MAX) = 'Streng fur oor tist'
DECLARE @Vowels AS NVARCHAR(MAX) = 'aeiou'

;WITH Cte AS (
	SELECT 
		R,
		CASE WHEN CHARINDEX(char_, @Vowels) > 0 THEN 1 ELSE 0 END AS flag,
		ROW_NUMBER() OVER(PARTITION BY CASE WHEN CHARINDEX(char_, @Vowels) > 0 THEN 1 ELSE 0 END ORDER BY R ASC)  AS do,
		ROW_NUMBER() OVER(PARTITION BY CASE WHEN CHARINDEX(char_, @Vowels) > 0 THEN 1 ELSE 0 END ORDER BY R DESC) AS ro,
		char_
	FROM (
		SELECT 
			ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS R,
			SUBSTRING(s.s, t.n + 1, 1) AS char_
		FROM (SELECT @Phrase s) s
		INNER JOIN (
			SELECT ROW_NUMBER() OVER(ORDER BY VALUE) - 1 AS n
			FROM STRING_SPLIT(REPLICATE('#', LEN(@Phrase) + 1), '#')
		) AS t 
		ON t.n < LEN(s.s)
	) AS t
)


SELECT
	STRING_AGG(CASE WHEN d.flag = 0 THEN d.char_ ELSE r.char_ END, '') WITHIN GROUP (ORDER BY d.R) AS Phrase
FROM Cte AS d
LEFT JOIN Cte AS r
ON d.do = r.ro
	AND d.flag = r.flag


