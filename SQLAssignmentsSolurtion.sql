--Exercise-1
--1
/*	Display the number of records in the [SalesPerson] table. 
(Schema(s) involved: Sales)
*/
SELECT COUNT(*) AS 'Number of Records' 
FROM Sales.SalesPerson;

--2
/*	Select both the FirstName and LastName of records from 
the Person table where the FirstName begins with the letter ‘B’
(Schema(s) involved: Person)
*/
SELECT FirstName
	, LastName
FROM Person.Person 
WHERE FirstName LIKE 'B%'

--3
/*	Select a list of FirstName and LastName for employees 
where Title is one of Design Engineer, Tool Designer 
or Marketing Assistant. (Schema(s) involved: HumanResources, Person)	
*/
SELECT p.FirstName
	, p.LastName 
FROM Person.Person AS p  
INNER JOIN HumanResources.Employee AS e  
ON p.BusinessEntityID = e.BusinessEntityID  
WHERE e.JobTitle IN ('Design Engineer', 'Tool Designer', 'Marketing Assistant');

--4
/*	Display the Name and Color of the Product with the 
maximum weight. (Schema(s) involved: Production)	
*/
DECLARE @MaxWeight int =
	(	SELECT MAX(Weight) FROM Production.Product	);
SELECT Name
	, Color
	, Weight
FROM Production.product 
WHERE weight = @MaxWeight;


--5
/*	Display Description and MaxQty fields from the SpecialOffer table. 
Some of the MaxQty values are NULL, in this case display 
the value 0.00 instead. (Schema(s) involved: Sales)
*/
SELECT COALESCE(CAST(MaxQty AS VARCHAR),'0.00') AS 'Weight'
	, Description
FROM Sales.SpecialOffer

--6
/*	Display the overall Average of the [CurrencyRate].[AverageRate] 
values for the exchange rate ‘USD’ to ‘GBP’ for the year 2005 
i.e. FromCurrencyCode = ‘USD’ and ToCurrencyCode = ‘GBP’. 
Note: The field [CurrencyRate].[AverageRate] is defined as 
'Average exchange rate for the day.' (Schema(s) involved: Sales)
*/
SELECT AVG(AverageRate) AS 'Average exchange rate for the day'
FROM Sales.CurrencyRate
WHERE datepart(year,CurrencyRateDate)=2005 
	AND FromCurrencyCode='USD'
	AND ToCurrencyCode='GBP'; 


--7
/*	Display the FirstName and LastName of records from the 
Person table where FirstName contains the letters ‘ss’.
Display an additional column with sequential numbers for each 
row returned beginning at integer 1. (Schema(s) involved: Person)
*/
SELECT ROW_NUMBER() OVER(ORDER BY FirstName) AS 'Row Number'
	, FirstName
	, LastName
FROM Person.Person 
WHERE FirstName like '%ss%'

--8
/*	Sales people receive various commission rates that 
belong to 1 of 4 bands. (Schema(s) involved: Sales)
CommissionPct	Commission Band
0.00			Band 0
Up To 1%		Band 1
Up To 1.5%		Band 2
Greater 1.5%	Band 3
Display the [SalesPersonID] with an additional 
column entitled ‘Commission Band’ indicating the appropriate band as above.
*/
SELECT BusinessEntityID As 'SalesPersonId'
	, CASE 
	WHEN CommissionPct = 0 THEN 'band 0'
	WHEN CommissionPct > 0 and CommissionPct <= 0.01 THEN 'band 1'
	WHEN CommissionPct > 0.01 and CommissionPct <= 0.015 THEN 'band 2'
	WHEN CommissionPct > 0.015 THEN 'band 3'
	END AS 'Commison Band'
FROM Sales.SalesPerson
ORDER BY CommissionPct

--9
/*	Display the managerial hierarchy from 
Ruth Ellerbrock (person type – EM) up to CEO Ken Sanchez. 
Hint: use [uspGetEmployeeManagers] 
(Schema(s) involved: [Person], [HumanResources]) 
*/
DECLARE @RuthEllerbrockID int = 
	(
	SELECT BusinessEntityID
	FROM Person.Person
	WHERE PersonType = 'EM'
		AND FirstName = 'Ruth'
		AND LastName = 'Ellerbrock'
	);

EXEC dbo.uspGetEmployeeManagers @RuthEllerbrockID; 
GO

--10
/*	Display the ProductId of the product with the largest stock level. 
Hint: Use the Scalar-valued function [dbo]. 
[UfnGetStock]. (Schema(s) involved: Production)
*/
DECLARE @MaxStock INT = 
(
	SELECT MAX(dbo.ufnGetStock(ProductID)) 
	FROM Production.Product
);

SELECT ProductID 
FROM Production.Product
WHERE dbo.ufnGetStock(ProductID) = @MaxStock;


--Exercise-2
/*	Write separate queries using a join, 
a subquery, a CTE, and then an EXISTS to list all 
AdventureWorks customers who have not placed an order.
*/
-- Using JOIN
SELECT c.CustomerID 
FROM Sales.Customer AS c
WHERE c.CustomerID NOT IN(
SELECT c.CustomerID
FROM Sales.Customer AS c
INNER JOIN Sales.SalesOrderHeader AS soh 
ON c.CustomerID = soh.CustomerID);


-- Using Subquery
SELECT CustomerID
FROM Sales.Customer
WHERE CustomerID NOT IN
	(
	SELECT CustomerID 
	FROM Sales.SalesOrderHeader
	); 

-- Using CTE
WITH CustomersWithOrders (CustomerID)
AS
	(
	SELECT CustomerID 
	FROM Sales.SalesOrderHeader
	)

SELECT CustomerID
FROM Sales.Customer AS c
WHERE CustomerID NOT IN (SELECT * FROM CustomersWithOrders); 

-- Using EXISTS

SELECT CustomerID
FROM Sales.Customer AS c
WHERE NOT EXISTS
(
	SELECT CustomerID 
	FROM Sales.SalesOrderHeader AS soh 
	WHERE c.CustomerID = soh.CustomerID
); 

--Exercise-3
/*	Show the most recent five orders that were purchased from account 
numbers that have spent more than $70,000 with AdventureWorks.
*/
SELECT TOP 5 SalesOrderID
		   , AccountNumber
		   , OrderDate
		   , TotalDue
FROM Sales.SalesOrderHeader
WHERE AccountNumber IN (SELECT AccountNumber
	FROM Sales.SalesOrderHeader 
	WHERE TotalDue>70000)
ORDER BY OrderDate DESC;
GO

--Exercise-4
/*	Create a function that takes as inputs a SalesOrderID, a Currency Code, 
and a date, and returns a table of all the SalesOrderDetail 
rows for that Sales Order including Quantity, ProductID, 
UnitPrice, and the unit price converted to the target currency based on 
the end of day rate for the date provided. 
Exchange rates can be found in the Sales.CurrencyRate table. (Use AdventureWorks)
*/
CREATE FUNCTION dbo.ufOrderDetails(@SalesOrderID int, @CurrencyCode nchar(3), @Date datetime)
RETURNS @Result TABLE (SalesOrderID int, QrderQty int,ProductID int, UnitPrice money,TargetCurrencyPrice money)
AS
BEGIN
	DECLARE @ConversionRate money = 
	(
		SELECT EndOfDayRate
		FROM Sales.CurrencyRate
		WHERE ToCurrencyCode = @CurrencyCode
			AND CurrencyRateDate = @Date
	)

	INSERT INTO @Result
	SELECT SalesOrderID
		, OrderQty
		 , ProductID
		 , UnitPrice
		 , UnitPrice * @ConversionRate AS 'TargetCurrencyPrice'
	FROM Sales.SalesOrderDetail 
	WHERE SalesOrderID = @SalesOrderID
	RETURN;
END;
GO

-- For Testing Function
DECLARE @SalesOrderID int = 54199;
DECLARE @CurrencyCode nchar(3) = 'AUD'
DECLARE @Date datetime = '2005-07-01 00:00:00.000';
SELECT * FROM ufOrderDetails(@SalesOrderID, @CurrencyCode, @Date);
GO

--Exercise-5
/*	Write a Procedure supplying name information from the 
Person.Person table and accepting a filter for the first name. 
Alter the above Store Procedure to supply Default Values if user 
does not enter any value.( Use AdventureWorks)
*/
CREATE PROCEDURE upfilterByFirstName
	@FirstName varchar(50)
AS
SELECT FirstName
FROM Person.Person
WHERE FirstName LIKE '%' + @FirstName + '%';
GO
--For Test Filter by Name
EXEC upfilterByFirstName @FirstName = 'ss'
GO

--Alter Method
ALTER PROCEDURE upfilterByFirstName
	@FirstName varchar(50) = ''
AS
SELECT FirstName
FROM Person.Person
WHERE FirstName LIKE '%' + @FirstName + '%';
GO
--For Test Alter method
EXEC upfilterByFirstName
GO


--Exercise-6
/*	Write a trigger for the Product table to ensure the list price 
can never be raised more than 15 Percent in a single change. 
Modify the above trigger to execute its check code only if the 
ListPrice column is updated (Use AdventureWorks Database).
*/

CREATE TRIGGER [Production].[PriceChangesLimit]
ON [Production].[Product]
FOR UPDATE
AS
    IF EXISTS
        (
        SELECT *
        FROM inserted i
        JOIN deleted d
            ON i.ProductID = d.ProductID
        WHERE i.ListPrice > (d.ListPrice * 1.15)
        )
    BEGIN
        RAISERROR('Price increase may not be greater than 15 percent.Transaction Failed.',16,1)
        ROLLBACK TRAN       
    END
GO

-- Check Value
SELECT ListPrice FROM Production.Product Order By ListPrice DESC;
GO
--Trigger Test 1
UPDATE Production.Product
SET ListPrice = ListPrice * 1.10
GO
--Trigger Test 2
UPDATE Production.Product
SET ListPrice = ListPrice * 1.50
GO

--UPDATED TRIGGER
ALTER TRIGGER [Production].[PriceChangesLimit]
ON [Production].[Product]
FOR UPDATE
AS
    IF UPDATE(ListPrice)
    BEGIN
        IF EXISTS
            (
            SELECT *
            FROM inserted i
            JOIN deleted d
                ON i.ProductID = d.ProductID
            WHERE i.ListPrice > (d.ListPrice * 1.15)
            )
        BEGIN
            RAISERROR('List Price cannot be raised more than 15 % ',16,1)
            ROLLBACK TRAN
        END
		ELSE
		BEGIN
			PRINT 'SUCCESS'
		END
END