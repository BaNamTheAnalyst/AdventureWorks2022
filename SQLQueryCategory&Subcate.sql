--Thống kê doanh thu của sản phẩm chính Bikes
WITH BikesRevenue AS (
SELECT 
	YEAR(a.OrderDate) AS 'Year',
	d.Name 'SubCategoryName',
	e.Name AS 'CategoryName',
	SUM(a.TotalDue) 'RevenuePerYear'
FROM Sales.SalesOrderHeader a
LEFT JOIN Sales.SalesOrderDetail b ON a.SalesOrderID = b.SalesOrderID
LEFT JOIN Production.Product c ON c.ProductID = b.ProductID
LEFT JOIN Production.ProductSubcategory d ON d.ProductSubcategoryID = c.ProductSubcategoryID
LEFT JOIN Production.ProductCategory e ON d.ProductCategoryID=e.ProductCategoryID
WHERE d.Name LIKE '%Bikes%'
GROUP BY YEAR(a.OrderDate),d.Name,e.Name
),
BikeRevenue1 AS (
SELECT 
    Year,
    SubCategoryName,
	CategoryName,
    RevenuePerYear,
    LAG(RevenuePerYear) OVER (PARTITION BY SubCategoryName ORDER BY Year) AS PreYearRevenue,
    CASE
        WHEN  LAG(RevenuePerYear) OVER (PARTITION BY SubCategoryName ORDER BY Year) IS NULL THEN NULL
        ELSE 
			FORMAT((RevenuePerYear -  LAG(RevenuePerYear) OVER (PARTITION BY SubCategoryName ORDER BY Year)) / LAG(RevenuePerYear) OVER (PARTITION BY SubCategoryName ORDER BY Year) * 100, 'N2') + '%'
    END AS Percentage_growth
FROM BikesRevenue),
OthersRevenue AS (
SELECT 
	YEAR(a.OrderDate) AS 'Year',
	d.Name 'SubcategoryName',
	e.Name 'CategoryName',
	SUM(a.TotalDue) 'RevenuePerYear'
FROM Sales.SalesOrderHeader a
LEFT JOIN Sales.SalesOrderDetail b ON a.SalesOrderID = b.SalesOrderID
LEFT JOIN Production.Product c ON c.ProductID = b.ProductID
LEFT JOIN Production.ProductSubcategory d ON d.ProductSubcategoryID = c.ProductSubcategoryID
LEFT JOIN Production.ProductCategory e ON d.ProductCategoryID=e.ProductCategoryID
WHERE d.Name NOT LIKE '%Bikes%'
GROUP BY YEAR(a.OrderDate),d.Name,e.Name
),
UnionCategory AS (
SELECT 
    Year,
    SubcategoryName,
	CategoryName,
    RevenuePerYear,
    LAG(RevenuePerYear) OVER (PARTITION BY SubcategoryName ORDER BY Year) AS PreYearRevenue,
    CASE
        WHEN  LAG(RevenuePerYear) OVER (PARTITION BY SubcategoryName ORDER BY Year) IS NULL THEN NULL
        ELSE 
			FORMAT((RevenuePerYear -  LAG(RevenuePerYear) OVER (PARTITION BY SubcategoryName ORDER BY Year)) / LAG(RevenuePerYear) OVER (PARTITION BY SubcategoryName ORDER BY Year) * 100, 'N2') + '%'
    END AS Percentage_growth
FROM OthersRevenue
UNION ALL
SELECT * FROM BikeRevenue1
)
SELECT 
	* 
FROM UnionCategory
WHERE CategoryName = 'Components'

