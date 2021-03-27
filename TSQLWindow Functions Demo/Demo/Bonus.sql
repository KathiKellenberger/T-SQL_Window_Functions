--2-7.1 Create a table that will hold duplicate rows    
CREATE TABLE #dupes ( Col1 INT, Col2 CHAR(1) );       
--2-7.2 Insert some rows    
INSERT  INTO #dupes
        ( Col1, Col2 )
VALUES  ( 1, 'a' ),
        ( 1, 'a' ),
        ( 2, 'b' ),
        ( 3, 'c' ),
        ( 4, 'd' ),
        ( 4, 'd' ),
        ( 5, 'e' );       
--2-7.3    
SELECT Col1, Col2    
FROM #dupes;   

-- Add ROW_NUMBER and Partition by all of the columns    
SELECT  Col1 ,
        Col2 ,
        ROW_NUMBER() OVER ( PARTITION BY Col1, Col2 ORDER BY Col1 ) AS RowNumber
FROM    #dupes;       
-- Delete the rows with RowNumber > 1    
WITH    Dupes
          AS ( SELECT   Col1 ,
                        Col2 ,
                        ROW_NUMBER() OVER ( PARTITION BY Col1, Col2 ORDER BY Col1 ) AS RowNumber
               FROM     #dupes
             )
    DELETE  Dupes
    WHERE   RowNumber > 1;       
-- The results    
SELECT Col1, Col2    
FROM #dupes;   


-- Create the #Islands table    
 CREATE TABLE #Islands ( ID INT NOT NULL );       
 -- Populate the #Islands table    
 INSERT INTO #Islands
        ( ID )
 VALUES ( 101 ),
        ( 102 ),
        ( 103 ),
        ( 106 ),
        ( 108 ),
        ( 108 ),
        ( 109 ),
        ( 110 ),
        ( 111 ),
        ( 112 ),
        ( 112 ),
        ( 114 ),
        ( 115 ),
        ( 118 ),
        ( 119 );       
-- View the data    
SELECT ID    
FROM #Islands;      

-- Add ROW_NUMBER to the data    
SELECT  ID ,
        ROW_NUMBER() OVER ( ORDER BY ID ) AS RowNum
FROM    #Islands;       
-- Subtract the RowNum from the ID    
SELECT  ID ,
        ROW_NUMBER() OVER ( ORDER BY ID ) AS RowNum ,
        ID - ROW_NUMBER() OVER ( ORDER BY ID ) AS Diff
FROM    #Islands;       
-- Change to DENSE_RANK since there are duplicates    
SELECT  ID ,
        DENSE_RANK() OVER ( ORDER BY ID ) AS DenseRank ,
        ID - DENSE_RANK() OVER ( ORDER BY ID ) AS Diff
FROM    #Islands;       
-- The complete Islands solution    
WITH    Islands
          AS ( SELECT   ID ,
                        DENSE_RANK() OVER ( ORDER BY ID ) AS DenseRank ,
                        ID - DENSE_RANK() OVER ( ORDER BY ID ) AS Diff
               FROM     #Islands
             )
    SELECT  MIN(ID) AS IslandStart ,
            MAX(ID) AS IslandEnd
    FROM    Islands
    GROUP BY Diff;   

--Save the DLL at c:\Custom
--3-12.1 Enable CRL
EXEC sp_configure 'clr_enabled', 1;
GO
RECONFIGURE;
GO
--3-12.2 Enable an unsigned assembly
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'clr strict security',0
GO
RECONFIGURE;
--3-12.3 Register the DLL
CREATE ASSEMBLY CustomAggregate FROM
 'C:\Custom\CustomAggregate.dll' WITH PERMISSION_SET = SAFE;
GO

--3-12.4 Create the function
CREATE Aggregate Median (@Value INT) RETURNS INT
EXTERNAL NAME CustomAggregate.Median;
GO

--3-12.5 Test the function
WITH Orders AS (
    SELECT CustomerID, SUM(OrderQty) AS OrderQty, SOH.SalesOrderID 
    FROM Sales.SalesOrderHeader AS SOH
    JOIN Sales.SalesOrderDetail AS SOD 
        ON SOH.SalesOrderID = SOD.SalesOrderDetailID
    GROUP BY CustomerID, SOH.SalesOrderID)
SELECT CustomerID, OrderQty, dbo.Median(OrderQty) OVER(PARTITION BY CustomerID) AS Median
FROM Orders
WHERE CustomerID IN (13011, 13012, 13019);

