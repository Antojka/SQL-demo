USE db
GO

DROP TABLE IF EXISTS #t

SELECT Pid, Id, ABS(CHECKSUM(NEWID())) % 100 AS Amount
INTO #t
FROM (
VALUES
	(null, 1),
	(null, 2),
	(1, 11),
	(1, 12),
	(11, 111),
	(11, 112),
	(12, 121),
	(12, 122),
	(2, 21),
	(2, 22),
	(2, 23),
	(21, 211),
	(21, 212),
	(22, 221),
	(22, 222)
) AS t(Pid, Id)

DROP TABlE IF EXISTS #Hierarchy

;WITH Cte_ids AS (

	SELECT
		Pid, 
		Id, 
		CAST(CONCAT(0, '.', ROW_NUMBER() OVER(ORDER BY Id)) AS NVARCHAR(100)) AS Hierarchy_id
	FROM #t
	WHERE Pid IS NULL -- Roots

	UNION ALL

	SELECT
		c.pid, 
		c.id, 
		CAST(CONCAT(Hierarchy_id, '.', ROW_NUMBER() OVER(ORDER BY c.Id)) AS NVARCHAR(100)) AS Hierarchy_id
	FROM Cte_ids AS p
	INNER JOIN #t as c
	ON p.Id = c.Pid
) 

SELECT
	Pid,
	Id,
	Hierarchy_id
INTO #Hierarchy
FROM Cte_ids 

;WITH Cte_branchs AS (

	SELECT
		Id,
		Hierarchy_id,
		LEFT(Hierarchy_id, 7) AS Cut_Hierarchy_id,
		5 AS N
	FROM #Hierarchy

	UNION ALL

	SELECT 
	    Id,
		Hierarchy_id,
		LEFT(Cut_Hierarchy_id, N) AS  Cut_Hierarchy_id,
		N - 2 AS N
	FROM Cte_branchs
	WHERE N - 2 > 0 
	
)

SELECT 
	Cut_Hierarchy_id,
	SUM(Amount) AS Amount
FROM #t AS t
INNER JOIN (
	SELECT
		Id,
		Hierarchy_id,
		Cut_Hierarchy_id
	FROM Cte_branchs
	WHERE LEN(Cut_Hierarchy_id) = N + 2 
) AS cut
ON t.id = cut.id
GROUP BY Cut_Hierarchy_id

