--Tính revenue, purchas expense qua các năm
	--Calculate Revenue throughout the year
WITH Revenue AS (
SELECT 
	YEAR(OrderDate) 'Year',
	SUM(TotalDue) 'Revenue'
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)
)
SELECT 
	Year,
	Revenue,
	LAG(Revenue) OVER (ORDER BY Year) AS PreRevenue,
    CASE
        WHEN  LAG(Revenue) OVER (ORDER BY Year) IS NULL THEN NULL
        ELSE 
			FORMAT((Revenue -  LAG(Revenue) OVER (ORDER BY Year)) / LAG(Revenue) OVER (ORDER BY Year) * 100, 'N2') + '%'
    END AS Percentage_growth
FROM Revenue;
	--Calculate Expense throughout the year
WITH Expense AS (
SELECT 
	YEAR(OrderDate) AS 'Year',
	SUM(TotalDue) AS 'Expense'
FROM Purchasing.PurchaseOrderHeader
GROUP BY YEAR(OrderDate)
)
SELECT 
	Year,
	Expense,
	LAG(Expense) OVER (ORDER BY Year) AS Pre,
    CASE
        WHEN  LAG(Expense) OVER (ORDER BY Year) IS NULL THEN NULL
        ELSE 
			FORMAT((Expense -  LAG(Expense) OVER (ORDER BY Year)) / LAG(Expense) OVER (ORDER BY Year) * 100, 'N2') + '%'
    END AS Percentage_growth
FROM Expense;
--Calculate Profit and Percentage growth throughout the year
WITH financials AS (
SELECT 
	YEAR(OrderDate) AS 'Year',
	ROUND(SUM(TotalDue),0) AS 'Total',
	'Revenue' AS 'Category'
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)
UNION ALL
SELECT 
	YEAR(OrderDate) AS 'Year',
	ROUND(SUM(TotalDue),0) AS 'Total',
	'PurchaseExpense' AS 'Category'
FROM Purchasing.PurchaseOrderHeader
GROUP BY YEAR(OrderDate)
),
PivotTable AS (
    SELECT 
        Year,
        SUM(CASE WHEN Category = 'Revenue' THEN Total ELSE 0 END) AS TotalRevenue,
        SUM(CASE WHEN Category = 'PurchaseExpense' THEN Total ELSE 0 END) AS TotalPurchaseExpense
    FROM 
        financials
    GROUP BY 
        Year
),
ProfitTable AS (
    SELECT 
        Year,
        TotalRevenue,
        TotalPurchaseExpense,
        (TotalRevenue - TotalPurchaseExpense) AS Profit
    FROM 
        PivotTable
),
GrowthTable AS (
    SELECT
        Year,
        Profit,
        LAG(Profit) OVER (ORDER BY Year) AS PreviousYearProfit
    FROM 
        ProfitTable
)
SELECT 
    Year,
    Profit,
    PreviousYearProfit,
    CASE
        WHEN PreviousYearProfit IS NULL THEN NULL
        ELSE CONCAT(ROUND(((Profit - PreviousYearProfit) / PreviousYearProfit) * 100, 2), '%')
    END AS PercentageGrowth
FROM 
    GrowthTable
ORDER BY 
    Year;
--Calculate revenue and percentage growth throughout the year category by territory
WITH RevenueTerritory AS (
    SELECT 
        YEAR(OrderDate) AS year,
        TerritoryID,
        SUM(TotalDue) AS TerritoryRev
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), TerritoryID
),
AggregatedRevenue AS (
    SELECT 
        a.year,
        b.Name,
        b.CountryRegionCode,
        b.[Group],
        SUM(a.TerritoryRev) AS TotalRev
    FROM RevenueTerritory a
    LEFT JOIN Sales.SalesTerritory b 
        ON a.TerritoryID = b.TerritoryID
    GROUP BY 
        a.year,
        b.Name,
        b.CountryRegionCode,
        b.[Group]
),
RevenueWithGrowth AS (
    SELECT
        year,
        Name,
        CountryRegionCode,
        [Group],
        TotalRev,
        LAG(TotalRev) OVER (PARTITION BY Name, CountryRegionCode, [Group] ORDER BY year) AS PrevYearRev
    FROM AggregatedRevenue
)
SELECT
    year,
    Name,
    [Group],
    TotalRev,
    PrevYearRev,
    CASE 
        WHEN PrevYearRev IS NULL THEN NULL
        ELSE CAST(ROUND(((TotalRev - PrevYearRev) / PrevYearRev) * 100, 0) AS NVARCHAR(10)) + '%'
    END AS PercentageGrowth
FROM RevenueWithGrowth
ORDER BY Name, CountryRegionCode, [Group], year;
--Calculate revenue according Category and Subcategory
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
FROM UnionCategory;
--Bikes revenue Statistic
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
)
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
FROM BikesRevenue;
--Others Revenue Statistic
WITH OthersRevenue AS (
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
)
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
FROM OthersRevenue;
--Order quantitative statistic
WITH OrderQty AS (
SELECT 
	YEAR(a.OrderDate) 'Year',
	SUM(b.OrderQty) 'TotalQty'
FROM Sales.SalesOrderHeader a 
LEFT JOIN Sales.SalesOrderDetail b ON a.SalesOrderID=b.SalesOrderID
GROUP BY YEAR(a.OrderDate)
),
GrowthTable AS (
SELECT
        Year,
        TotalQty,
        LAG(TotalQty) OVER (ORDER BY Year) AS PreviousYearTotalQty
    FROM 
        OrderQty
)
SELECT 
    Year,
    TotalQty,
    PreviousYearTotalQty,
    CASE
        WHEN PreviousYearTotalQty IS NULL THEN NULL
        ELSE CONCAT(ROUND(((CAST(TotalQty AS DECIMAL(10, 2)) - CAST(PreviousYearTotalQty AS DECIMAL(10, 2))) / CAST(PreviousYearTotalQty AS DECIMAL(10, 2))) * 100, 2) , '%')
    END AS PercentageGrowth
FROM 
    GrowthTable
ORDER BY 
    Year;
--Average weekday and weekend order quantity statistic
WITH TotalQtyTable AS (
SELECT 
	a.OrderDate,
	SUM(b.OrderQty) TotalQty
FROM Sales.SalesOrderHeader a
LEFT JOIN Sales.SalesOrderDetail b ON a.SalesOrderID=b.SalesOrderID
GROUP BY a.OrderDate
)
SELECT 
	YEAR(OrderDate) AS 'Year',
	AVG(CASE WHEN 
		DATEPART(WEEKDAY,OrderDate) BETWEEN 2 AND 6 THEN TotalQty 
		ELSE NULL END) AS AvgWeekDay,
	AVG(CASE WHEN 
	DATEPART(WEEKDAY,OrderDate) IN (1,7) THEN TotalQty 
		ELSE NULL END) AS AvgWeekKend
FROM TotalQtyTable
GROUP BY YEAR(OrderDate) 
ORDER BY Year;
--Using RFM model to segregate type customer, calculate percentage growth of each customer segments
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
),
Count_Final AS (
SELECT 
	a.CustomerID,
	a.TotalRev,
	a.GapDay,
	a.Cus_Category,
	YEAR(b.OrderDate) AS 'Year'
FROM Final3 a
LEFT JOIN Sales.SalesOrderHeader b ON a.CustomerID=b.CustomerID
WHERE Cus_Category IS NOT NULL
),
RankedCustomers AS (
SELECT 
	Year,
	Cus_Category,
	COUNT(Cus_Category) CountCustomer,
	LAG(COUNT(Cus_Category)) OVER (PARTITION BY Cus_Category ORDER BY Year) AS PrevCountCustomer
FROM Count_Final
GROUP BY Year,Cus_Category
)
SELECT
    Year,
    Cus_Category,
    CountCustomer,
    PrevCountCustomer,
    CASE
        WHEN PrevCountCustomer IS NULL THEN NULL
        ELSE FORMAT((CountCustomer - PrevCountCustomer) / CAST(PrevCountCustomer AS DECIMAL) * 100, 'N2') + '%'
    END AS CountCustomer_growth
FROM
    RankedCustomers
ORDER BY
    Cus_Category,
    Year;
--Comparing actual and budget expense
WITH CostCTE AS (
SELECT 
	ProductID,
	SUM(LineTotal) AS Cost,
	'Recent' AS 'Category'
FROM Purchasing.PurchaseOrderDetail
GROUP BY ProductID
UNION ALL
SELECT 
	ProductID,
	SUM(StandardCost) AS Cost,
	'Budget' AS 'Category'
FROM Production.ProductCostHistory
GROUP BY ProductID
),
Costs AS (
SELECT 
	Category,
	SUM(Cost) AS TotalCost
FROM CostCTE
GROUP BY Category
)
SELECT 
    (SELECT TotalCost FROM Costs WHERE Category = 'Recent') AS RecentTotalCost,
    (SELECT TotalCost FROM Costs WHERE Category = 'Budget') AS BudgetTotalCost,
    CAST(ROUND(((SELECT TotalCost FROM Costs WHERE Category = 'Recent') - 
                 (SELECT TotalCost FROM Costs WHERE Category = 'Budget')) /
                (SELECT TotalCost FROM Costs WHERE Category = 'Budget') * 100, 2) AS VARCHAR) + '%' AS GrowthRate;
--Purchasing reason statistic
SELECT 
	Name,
	ReasonType,
	COUNT(Name) AS CountReason
FROM Sales.SalesOrderHeaderSalesReason a
LEFT JOIN Sales.SalesReason b ON a.SalesReasonID = b.SalesReasonID
GROUP BY Name,ReasonType
ORDER BY COUNT(Name);


