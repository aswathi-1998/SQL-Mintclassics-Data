use mintclassics;
-- Rearranging the warehouses
#Descriptive Statistics of Quantity In Stock of all the vehicles
SELECT MIN(quantityInStock) , MAX(quantityInStock) , SUM(quantityInStock) , AVG(quantityInStock) FROM products;

SELECT warehousecode,MIN(quantityInStock) , MAX(quantityInStock) , SUM(quantityInStock) , AVG(quantityInStock) FROM products
GROUP BY warehousecode;

#Current quantity of Stock in each warehouse
SELECT warehousename,warehouses.warehousePctCap ,sum(quantityInStock) as quantity FROM products join warehouses
on products.warehousecode = warehouses.warehousecode
GROUP BY warehousename,warehouses.warehousePctCap 
ORDER BY quantity;
#Potential Stock in each warehouse
WITH ware AS (
	SELECT warehousename,sum(quantityInStock) as quantity FROM products join warehouses
	on products.warehousecode = warehouses.warehousecode
	GROUP BY warehousename
	ORDER BY quantity)

SELECT ware.warehousename,
ware.quantity as TotalQuantityInStock,
warehousePctCap,
round(ware.quantity*100/warehousePctCap) as max_capacity,
round(ware.quantity*85/warehousePctCap) as 85PctCapacity, 
round(ware.quantity*100/warehousePctCap)-ware.quantity as max_remaining_capacity,
round(ware.quantity*85/warehousePctCap)-ware.quantity as 85Pct_remaining_capacity
FROM ware JOIN warehouses
on  ware.warehousename =  warehouses.warehousename
ORDER BY TotalQuantityInStock DESC;

# Productlines in each warehouse

SELECT p.productline as productline,
w.warehouseName as warehouse,
sum(p.quantityinstock) as quantityInStock
FROM
warehouses w JOIN products p 
ON w.warehouseCode = p.warehouseCode
GROUP BY productline,warehouse;

-- INVENTORY ANALYSIS
# Checking for excess quantity
SELECT
p.productName,
p.quantityInStock,
sum(o.quantityOrdered) as quantityOrdered,
p.quantityInStock-sum(o.quantityOrdered) AS ExcessStock
FROM products p LEFT JOIN orderdetails o
ON p.productCode = o.productCode
GROUP BY p.productName, p.quantityInStock
ORDER BY  ExcessStock
LIMIT 15;
# Deficit stock products
SELECT
p.productName,
p.quantityInStock,
sum(o.quantityOrdered) as quantityOrdered,
p.quantityInStock-sum(o.quantityOrdered) AS ExcessStock
FROM products p LEFT JOIN orderdetails o
ON p.productCode = o.productCode
GROUP BY p.productName, p.quantityInStock
HAVING  ExcessStock <0;
# Top Ordered models and their excess stock
SELECT
p.productName,
p.productLine,
p.quantityInStock,
sum(o.quantityOrdered) as quantityOrdered,
p.quantityInStock-sum(o.quantityOrdered) AS ExcessStock
FROM products p LEFT JOIN orderdetails o
ON p.productCode = o.productCode
GROUP BY p.productName, p.quantityInStock,p.productLine
ORDER BY  quantityOrdered desc;
# Action to be taken
WITH CTE AS (
	SELECT
p.productName,
p.quantityInStock,
sum(o.quantityOrdered) as quantityOrdered,
p.quantityInStock-sum(o.quantityOrdered) AS ExcessStock
FROM products p LEFT JOIN orderdetails o
ON p.productCode = o.productCode
GROUP BY p.productName, p.quantityInStock
) ,
CTE2 AS (
	SELECT *,
	ExcessStock*100/QuantityOrdered as ExcessPct,
	DENSE_RANK() OVER (ORDER BY quantityOrdered DESC) as Rnk FROM CTE),
CTE3 AS (
	SELECT *,
	CASE
		WHEN Rnk < ceil((SELECT max(Rnk) FROM CTE2)/4) THEN 200
		WHEN Rnk < ceil((SELECT max(Rnk) FROM CTE2)/2) THEN 150
		WHEN Rnk < ceil((SELECT max(Rnk) FROM CTE2)*3/4) THEN 100
		ELSE 50
	END AS ExcessPctRequired
	 FROM CTE2)
 SELECT * ,
 ROUND(ExcessPctRequired*quantityOrdered/100) as ExcessSugg,
 IF(ExcessPctRequired<ExcessPct,"Reduce Stock","Increase Stock") AS Action_ 
 FROM CTE3
 WHERE quantityOrdered IS NOT NULL;
 #HAVING Action_ = 'Increase Stock'; Execute this line to find those models to increase stock

# PROFIT ANALYSIS
#Top 15 profitable products
SELECT p.productName,p.productLine,
sum(od.quantityOrdered*od.priceEach) as Sales,
sum(od.quantityOrdered*p.buyprice) as cost,
sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice)  AS Profit,
(sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice))*100/ sum(od.quantityOrdered*p.buyprice) as profitpct
FROM
products p RIGHT JOIN orderdetails od
on p.productCode=od.productCode
JOIN orders o ON o.orderNumber = od.orderNumber
WHERE o.status <> 'Cancelled'
GROUP BY p.productName,p.productLine 
ORDER BY Profit DESC,profitpct DESC
LIMIT 15
;
# LEAST 15 PROFITABLE PRODUCTS
SELECT p.productName,p.productLine,
sum(od.quantityOrdered*od.priceEach) as Sales,
sum(od.quantityOrdered*p.buyprice) as cost,
sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice)  AS Profit,
(sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice))*100/ sum(od.quantityOrdered*p.buyprice) as profitpct
FROM
products p RIGHT JOIN orderdetails od
on p.productCode=od.productCode
JOIN orders o ON o.orderNumber = od.orderNumber
WHERE o.status <> 'Cancelled'
GROUP BY p.productName,p.productLine 
ORDER BY PROFIT ASC
LIMIT 15
;
#PROFIT By ProductLines
WITH CTE AS (
SELECT p.productLine,
sum(od.quantityOrdered*od.priceEach) as Sales,
sum(od.quantityOrdered*p.buyprice) as cost,
sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice)  AS Profit,
(sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice))*100/ sum(od.quantityOrdered*p.buyprice) as profitpct
FROM
products p RIGHT JOIN orderdetails od
on p.productCode=od.productCode
JOIN orders o ON o.orderNumber = od.orderNumber
WHERE o.status <> 'Cancelled'
GROUP BY p.productLine )
SELECT *, round((Profit*100)/SUM(Profit)  OVER (),2) AS ProfitShare FROM CTE
ORDER BY ProfitShare DESC;

#Profit Share VS Inventory Share
WITH CTE AS (
SELECT p.productLine,
sum(od.quantityOrdered*od.priceEach) as Sales,
sum(od.quantityOrdered*p.buyprice) as cost,
sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice)  AS Profit,
(sum(od.quantityOrdered*od.priceEach) - sum(od.quantityOrdered*p.buyprice))*100/ sum(od.quantityOrdered*p.buyprice) as profitpct
FROM
products p RIGHT JOIN orderdetails od
on p.productCode=od.productCode
JOIN orders o ON o.orderNumber = od.orderNumber
WHERE o.status <> 'Cancelled'
GROUP BY p.productLine ),
 Pro as (
SELECT *, round((Profit*100)/SUM(Profit)  OVER (),2) AS ProfitShare FROM CTE),
CTE2 AS (SELECT p.productline as productline,
sum(p.quantityinstock) as quantityInStock
FROM products p 
GROUP BY productline),
Inv AS (
SELECT *, round((quantityInStock*100)/SUM(quantityInStock) OVER (),2) AS InventoryShare FROM CTE2)
SELECT Inv.productline,Inv.InventoryShare,Pro.ProfitShare FROM Inv JOIN Pro
ON Pro.productLine = Inv.productLine
ORDER BY Inv.InventoryShare DESC;




