DECLARE @Phrase AS NVARCHAR(MAX) = 'Streng fer tho tist'
DECLARE @Vowels AS NVARCHAR(MAX) = 'aeiou'

;WITH Cte AS (
	SELECT 
		R,
		Flag,
		ROW_NUMBER() OVER(PARTITION BY Flag ORDER BY R ASC)  AS Do, -- Direct order
		ROW_NUMBER() OVER(PARTITION BY Flag ORDER BY R DESC) AS Ro, -- Reverse order
		Char_
	FROM (
		SELECT 
			N + 1 AS R,
			SUBSTRING(s.S, t.N + 1, 1) AS Char_,
			CASE WHEN CHARINDEX(SUBSTRING(s.S, t.N + 1, 1), @Vowels) > 0 THEN 1 ELSE 0 END AS Flag
		FROM (SELECT @Phrase  AS S) s
		INNER JOIN (
			SELECT ROW_NUMBER() OVER(ORDER BY VALUE) - 1 AS N
			FROM STRING_SPLIT(REPLICATE('#', LEN(@Phrase) + 1), '#')
		) AS t 
		ON t.N < LEN(s.S)
	) AS t
)


SELECT
	STRING_AGG(CASE WHEN d.Flag = 0 THEN d.Char_ ELSE r.Char_ END, '') WITHIN GROUP (ORDER BY d.R) AS Phrase
FROM Cte AS d
LEFT JOIN Cte AS r
ON d.Do = r.Ro
	AND d.Flag = r.Flag