USE db
GO

--============================================================================================================================
-- CREATE TEST DATA

DROP TABLE IF EXISTS [dbo].[tbl]

CREATE TABLE [dbo].[tbl](
	Pid INT, 
	Id INT NOT NULL, 
	Amount FLOAT NOT NULL
)

INSERT INTO [dbo].[tbl]
SELECT Pid, Id, ABS(CHECKSUM(NEWID())) % 100 AS Amount
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

--============================================================================================================================

;WITH Cte_ids AS (

	SELECT
		Pid, 
		Id, 
		CAST(CONCAT(0, '.', ROW_NUMBER() OVER(ORDER BY Id)) AS NVARCHAR(100)) AS Branch_id
	FROM [dbo].[tbl]
	WHERE Pid IS NULL -- Roots

	UNION ALL

	SELECT
		c.Pid, 
		c.id, 
		CAST(CONCAT(Branch_id, '.', ROW_NUMBER() OVER(ORDER BY c.Id)) AS NVARCHAR(100)) AS Branch_id
	FROM Cte_ids AS p
	INNER JOIN [dbo].[tbl] as c
	ON p.Id = c.Pid
) 

,Cte_branches AS (

	SELECT
		Id,
		Branch_id,
		LEFT(Branch_id, 7) AS Cut_branch_id,
		5 AS N
	FROM Cte_ids

	UNION ALL

	SELECT 
	    Id,
		Branch_id,
		LEFT(Cut_branch_id, N) AS Cut_branch_id,
		N - 2 AS N
	FROM Cte_Branches
	WHERE N - 2 > 0 	
)

,Cte_agg AS (

	SELECT 
		Cut_branch_id,
		SUM(Amount) AS Amount
	FROM [dbo].[tbl] AS t
	INNER JOIN (
		SELECT
			Id,
			Branch_id,
			Cut_branch_id
		FROM Cte_branches
		WHERE LEN(Cut_branch_id) = N + 2 
	) AS cut
	ON t.id = cut.id
	GROUP BY Cut_branch_id
)

--============================================================================================================================
-- TEST

SELECT
	t.Pid,
	t.Id,
	t.Amount,
	agg.Amount as Acc_childs_amount
FROM [dbo].[tbl] AS t
INNER JOIN Cte_ids AS i
ON t.Id = i.Id
INNER JOIN Cte_agg AS agg
ON i.Branch_id = agg.Cut_branch_id