USE AdventureWorks2022;
WITH Monetary_Raw AS (
SELECT
CustomerID,
SUM(Subtotal) TotalRev,
PERCENT_RANK() OVER(ORDER BY SUM(Subtotal) ASC) AS Percent_Rank_Rev
FROM Sales.SalesOrderHeader
GROUP BY CustomerID),

Monetary_Category AS (
SELECT 
CustomerID,
TotalRev,
CASE
	WHEN Percent_Rank_Rev <= 0.25 THEN 1
	WHEN Percent_Rank_Rev <= 0.5 THEN 2
	WHEN Percent_Rank_Rev <= 0.75 THEN 3
	ELSE 4
END Monetary
FROM Monetary_Raw
),

Frequency_Raw AS (
SELECT
CustomerID,
COUNT(DISTINCT SalesOrderNumber) TotalOrder,
PERCENT_RANK() OVER(ORDER BY COUNT(DISTINCT SalesOrderNumber) ASC) AS Percent_Rank_Order
FROM Sales.SalesOrderHeader
GROUP BY CustomerID),

Frequency_Category AS (
SELECT 
CustomerID,
TotalOrder,
CASE
	WHEN Percent_Rank_Order <= 0.25 THEN 1
	WHEN Percent_Rank_Order <= 0.5 THEN 2
	WHEN Percent_Rank_Order <= 0.75 THEN 3
	ELSE 4
END Frequency
FROM Frequency_Raw
),

Recency_Raw AS (
SELECT
CustomerID,
DATEDIFF(DAY, MAX(OrderDate), '2014-06-30') GapDay,
PERCENT_RANK() OVER(ORDER BY DATEDIFF(DAY, MAX(OrderDate), '2014-06-30') DESC) AS Percent_Rank_Rev
FROM Sales.SalesOrderHeader
GROUP BY CustomerID),

Recency_Category AS (
SELECT 
CustomerID,
GapDay,
CASE
	WHEN Percent_Rank_Rev <= 0.25 THEN 1
	WHEN Percent_Rank_Rev <= 0.5 THEN 2
	WHEN Percent_Rank_Rev <= 0.75 THEN 3
	ELSE 4
END Recency_Raw
FROM Recency_Raw
),

Final AS (
SELECT 
a.*,
b.TotalOrder,
b.Frequency,
c.GapDay,
c.Recency_Raw
FROM
Monetary_Category a
LEFT JOIN Frequency_Category b ON a.CustomerID = b.CustomerID
LEFT JOIN Recency_Category c ON a.CustomerID = c.CustomerID
),
Final2 AS (
SELECT *,
CONCAT(Monetary, Frequency, Recency_Raw) RFM
FROM Final),
Final3 AS (
SELECT
*,
CASE
	WHEN RFM LIKE '444' THEN 'Best Customer'
	WHEN RFM LIKE '1%1' THEN 'Lost Cheap Customer'
	WHEN RFM LIKE '1%4' THEN 'Lost Big Customer'
	WHEN RFM LIKE '2%4' THEN 'Almost Big Customer'
	WHEN RFM LIKE '%4' THEN 'Big Spender'
	WHEN RFM LIKE '%4%' THEN 'Loyal'
	WHEN RFM LIKE '2%' THEN 'Almost Lost'
END Cus_Category
FROM Final2
)
SELECT * FROM Final3 WHERE Cus_Category IS NOT NULL
