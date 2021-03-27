
--Demo 0 The Stock Problem
--Be sure to run script to generate the StockHistory table.
--Change to the database where you have run the script
USE Demo;
GO
SELECT *
FROM StockHistory
--WHERE TradeDate BETWEEN '2017-01-03' AND '2017-01-05'
ORDER BY TickerSymbol,
         TradeDate;

--Using window functions
SELECT TickerSymbol,
       TradeDate,
       ClosePrice,
       LAG(ClosePrice) OVER (PARTITION BY TickerSymbol ORDER BY TradeDate) AS LastPrice,
       ClosePrice - LAG(ClosePrice) OVER (PARTITION BY TickerSymbol ORDER BY TradeDate) AS Diff
FROM StockHistory
WHERE TradeDate BETWEEN '2017-01-03' AND '2017-02-03'
ORDER BY TickerSymbol,
         TradeDate;

--Demo 1 Ranking Functions
USE AdventureWorks2019;
GO
--Get AdventureWorks from GitHub

--Row_number
SELECT SalesOrderID, OrderDate, CustomerID, 
	ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY OrderDate)
FROM Sales.SalesOrderHeader
ORDER BY SalesOrderID;


--What's the difffence between ROW_NUMBER, RANK and DENSE_RANK?
SELECT SalesOrderID, OrderDate, CustomerID, 
	ROW_NUMBER() OVER(ORDER BY orderdate) As RowNum,
	RANK()       OVER(ORDER BY OrderDate) As Rnk,
	DENSE_RANK() OVER(ORDER BY OrderDate) As DenseRnk
FROM Sales.SalesOrderHeader
WHERE CustomerID = 11078
ORDER BY orderdate;
/*
ROW_NUMBER only cares about the position
DENSE_RANK is logical, the nth unique value
RANK is both positional and logical, finds ties,
	but otherwise uses position

*/
--The bonus problem
--NTILE
SELECT SP.FirstName, SP.LastName,
	SUM(SOH.TotalDue) AS TotalSales, 
	NTILE(4) OVER(ORDER BY SUM(SOH.TotalDue))  * 1000 AS Bonus
FROM [Sales].[vSalesPerson] SP 
JOIN Sales.SalesOrderHeader SOH ON SP.BusinessEntityID = SOH.SalesPersonID 
WHERE SOH.OrderDate >= '2012-01-01' AND SOH.OrderDate < '2013-01-01'
GROUP BY FirstName, LastName;

--The first 4 orders placed in each year
--Can't use window functions outside of SELECT and ORDER BY
SELECT CustomerID, SalesOrderID, OrderDate, 
		ROW_NUMBER() OVER(PARTITION BY YEAR(OrderDate) 
		ORDER BY OrderDate) AS RowNum, 
		YEAR(OrderDate) AS OrderYear
	FROM Sales.SalesOrderHeader
	WHERE ROW_NUMBER() OVER(PARTITION BY YEAR(OrderDate) ORDER BY orderDate) < 5

--Must separate the logic. One way is by using a CTE
;WITH Orders AS(
	SELECT CustomerID, SalesOrderID, OrderDate, 
		ROW_NUMBER() OVER(PARTITION BY YEAR(OrderDate) 
		ORDER BY OrderDate) AS RowNum, 
		YEAR(OrderDate) AS OrderYear
	FROM Sales.SalesOrderHeader
	)
SELECT CustomerID, SalesOrderID, OrderDate, OrderYear
FROM Orders
WHERE RowNum < 5;


--END Demo 1

--Demo 2 window aggregates

--Calculate aggregates without an aggregate query
--with window aggregate functions
--All the products for sale
SELECT ProductID, name, ListPrice, FinishedGoodsFlag
FROM Production.Product
WHERE FinishedGoodsFlag = 1;


--Need a list of products along with overall count and average list price
--This will not work
SELECT ProductID, name, ListPrice,
	COUNT(*)  CountOfProduct, 
	AVG(ListPrice) AS AvgListPrice
FROM Production.Product 
WHERE FinishedGoodsFlag = 1;

--Add a group by, but not the desired results
SELECT ProductID, name, ListPrice,
	COUNT(*)  CountOfProduct,
	AVG(ListPrice) AS AvgListPrice
FROM Production.Product
WHERE FinishedGoodsFlag = 1
GROUP BY ProductID, name, ListPrice;

--Add OVER clause instead
SELECT ProductID, name, ListPrice,
	COUNT(*) OVER() CountOfProduct,
	AVG(ListPrice) OVER() AS AvgListPrice
FROM Production.Product
WHERE FinishedGoodsFlag = 1;

/*
You can also add window aggregates to an existing aggregate
query, but the window aggregate is treated as an ordinary expression
*/

/* Display each year and total sales, also 
display as a percentage of overall sales*/

--List of years and sales
SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalDue) AS YearlySales
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate);

--Add the overall sales
SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalDue) AS YearlySales,
	SUM(TotalDue) OVER() AS OverallSales
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate);

--That didn't work, because the window aggregate is not an aggregate function
--Must apply the window function to the aggregate expression
SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalDue) AS YearlySales,
	SUM(SUM(TotalDue)) OVER() AS OverallSales
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate);

--Add the calculation
SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalDue) AS YearlySales,
	SUM(SUM(TotalDue)) OVER() AS OverallSales,
	FORMAT(SUM(TotalDue)/SUM(SUM(TotalDue)) OVER(),'P') AS PercentOfSales
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate);

--Here's another way to do it
WITH Sales AS (
	SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalDue) AS YearlySales
	FROM Sales.SalesOrderHeader
	GROUP BY YEAR(OrderDate)
)
SELECT OrderYear, YearlySales, SUM(YearlySales) OVER() AS OverallSales, 
	FORMAT(YearlySales/SUM(YearlySales) OVER(),'P') AS PercentOfSales
FROM Sales; 


--End Demo 2

--Demo 3 Accumulating Aggregates
SELECT  SalesOrderID,OrderDate, CustomerID, TotalDue,
	SUM(TotalDue) OVER(ORDER BY SalesOrderID) AS RunningTotal,
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID) 
	AS CustomerRunningTotal
FROM Sales.SalesOrderHeader SOH
ORDER BY SalesOrderID 
--ORDER BY CustomerID, SalesOrderID;

--End Demo 3 

--Demo 4 Framing
USE AdventureWorks2019;
GO
SELECT  OrderDate, CustomerID, TotalDue,
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID 
		ROWS BETWEEN UNBOUNDED PRECEDING and CURRENT ROW) AS RunningTotal
		,
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID 
		ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS ReverseTotal
FROM Sales.SalesOrderHeader SOH
ORDER BY CustomerID, SalesOrderID;

--If you don't specify the frame, it uses the default
--RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
SELECT  OrderDate, CustomerID, TotalDue,
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY SalesOrderID
		) AS RunningTotal
FROM Sales.SalesOrderHeader SOH
ORDER BY CustomerID, SalesOrderID;

--Range has a performance penalty (fixed 2019 Enterprise)
--Using range with a non-unique order by can give 
--possibly unexpected results
SELECT CustomerID, OrderDate, SalesOrderID, TotalDue, 
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY OrderDate) AS RunningTotal,
	SUM(TotalDue) OVER(PARTITION BY CustomerID ORDER BY OrderDate
		ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotalWithFrame
FROM Sales.SalesOrderHeader 
WHERE CustomerID IN ('11433','11078','18758');




--Solution: use unique order by
--preferably specify the frame

--Same problem with old method
SELECT CustomerID, SalesOrderID, OrderDate, TotalDue, 
	(SELECT SUM(TotalDue) 
	FROM Sales.SalesOrderHeader
	WHERE CustomerID = a.CustomerID
		AND OrderDate <= a.OrderDate) AS RunningTotal
FROM Sales.SalesOrderHeader a
WHERE CustomerID IN ('11433','11078','18758');

--Moving average
WITH MonthlySales AS (
	SELECT YEAR(OrderDate) AS OrderYear, MONTH(OrderDate) AS OrderMonth,
		SUM(TotalDue) AS Sales 
	FROM Sales.SalesOrderHeader
	GROUP BY YEAR(OrderDate), MONTH(OrderDate) 
)
SELECT OrderYear, OrderMonth, Sales, 
	AVG(Sales) OVER(ORDER BY OrderYear, OrderMonth 
		ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg
FROM MonthlySales
ORDER BY OrderYear, OrderMonth;



--End Demo 4


--Demo 5 LAG and LEAD
USE Demo
GO
SELECT * FROM StockHistory;

SELECT TickerSymbol, TradeDate, ClosePrice, 
	LAG(ClosePrice) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) Yesterday,
	ClosePrice - LAG(ClosePrice) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) AS PriceChange
FROM StockHistory
ORDER BY TickerSymbol, TradeDate;

--Default value
SELECT TickerSymbol, TradeDate, ClosePrice, 
	LAG(ClosePrice,1,0) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) Yesterday,
	ClosePrice - LAG(ClosePrice,1,0) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) AS PriceChange
FROM StockHistory
ORDER BY TickerSymbol, TradeDate;

--Can move more rows backwards
SELECT TickerSymbol, TradeDate, ClosePrice, 
	LAG(ClosePrice,2,0) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) TwoDaysAgo
FROM StockHistory
ORDER BY TickerSymbol, TradeDate;

--Can't go forward with LAG
SELECT TickerSymbol, TradeDate, ClosePrice, 
	LAG(ClosePrice,-2,0) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) TwoDaysAhead
FROM StockHistory
ORDER BY TickerSymbol, TradeDate;

--Use LEAD
SELECT TickerSymbol, TradeDate, ClosePrice, 
	LEAD(ClosePrice,2,0) OVER(PARTITION BY TickerSymbol ORDER BY TradeDate) TwoDaysAhead
FROM StockHistory
ORDER BY TickerSymbol, TradeDate;

--Last_Value and First_value
--FRAME suported -- RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW by default
USE AdventureWorks2019;
GO
SELECT CustomerID, OrderDate, TotalDue ,
      FIRST_VALUE(TotalDue) OVER(PARTITION BY CustomerID 
	  ORDER BY SalesOrderID) AS FirstTotalDue, 
	  FIRST_VALUE(OrderDate) OVER(PARTITION BY CustomerID 
	  ORDER BY SalesOrderID) AS FirstOrderDate 
FROM Sales.SalesOrderHeader
ORDER BY CustomerID, SalesOrderID;

--Last Value, doesn't work right without specifying frame
SELECT CustomerID, OrderDate, TotalDue ,
      LAST_VALUE(TotalDue) OVER(PARTITION BY CustomerID 
	  ORDER BY SalesOrderID) AS LastTotalDue, 
	  LAST_VALUE(OrderDate) OVER(PARTITION BY CustomerID 
	  ORDER BY SalesOrderID) AS LastOrderDate 
FROM Sales.SalesOrderHeader
ORDER BY CustomerID, SalesOrderID;

--What is wrong? 
--The default frame only goes to current row
SELECT CustomerID, OrderDate, TotalDue ,
      LAST_VALUE(TotalDue) OVER(PARTITION BY CustomerID 
	  ORDER BY SalesOrderID
	  ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS LastTotalDue, 
	  LAST_VALUE(OrderDate) OVER(PARTITION BY CustomerID 
	  ORDER BY SalesOrderID 
	  ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS LastOrderDate 
FROM Sales.SalesOrderHeader
ORDER BY CustomerID, SalesOrderID;
--End Demo 5

--Demo 6 Statistical functions
/*
PERCENT_RANK = My score is higher than 89% of the scores
CUME_DIST = My score is at 90%
*/


CREATE TABLE #MonthlyTempsStl(MNo Int, MName varchar(15), AvgHighTemp INT)

INSERT INTO #MonthlyTempsStl
VALUES(1,'Jan',40),(2,'Feb',45),(3,'Mar',55),(4,'Apr',67),(5,'May',77),(6,'Jun',85),
	(7,'Jul',89),(8,'Aug',88),(9,'Sep',81),(10,'Oct',69),(11,'Nov',56),(12,'Dec',43)

SELECT MName, AvgHighTemp, RANK() OVER(ORDER BY AvgHighTemp) AS Rnk,
	PERCENT_RANK() OVER(ORDER BY AvgHighTemp) * 100.0 AS PR,
	CUME_DIST() OVER(ORDER BY AvgHighTemp) * 100.0 AS CD
FROM #MonthlyTempsStl;

--What is the median temp?
SELECT MName, AvgHighTemp,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY AvgHighTemp) OVER() AS Median,
	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY AvgHighTemp) OVER() AS NotExactlyTheMedian2
FROM #MonthlyTempsStl;

--End Demo 6

