--FIGURA 1

SELECT
    YEAR(OrderDate) AS Año,
    ROUND(SUM(TotalDue), 2) AS Ventas_totales
FROM  Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY Año ASC;

--FIGURA 2

SELECT
    YEAR(soh.OrderDate) AS Año,
    st.Name AS Territorio,
    SUM(soh.TotalDue) AS Ventas_totales
FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY YEAR(soh.OrderDate), st.Name
ORDER BY Año ASC, Ventas_totales DESC

--FIGURA 3

SELECT
    YEAR(OrderDate) AS año,
    COUNT(DISTINCT CustomerID) AS Cantidad_clientes
FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) BETWEEN 2011 AND 2014
GROUP BY YEAR(OrderDate)
ORDER BY año

-- FIGURA 4

with vendidos_2011 as (
    select *
        from (select soh.CustomerID
                , sum(TotalDue) as cantidad
                , row_number() over (order by sum(TotalDue) desc) as ranking
                from Sales.SalesOrderHeader soh
                left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
                where year(OrderDate) = 2011
                group by soh.CustomerID) v2011
        WHERE  v2011.ranking <= 1400
    ) ,
vendidos_2012 as (
    select *
        from (select soh.CustomerID
                , sum(TotalDue) as cantidad
                , row_number() over (order by sum(TotalDue) desc) as ranking
                from Sales.SalesOrderHeader soh
                left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
                where year(OrderDate) = 2012
                group by soh.CustomerID) v2012
        WHERE  v2012.ranking <= 1400
    )
,
vendidos_2013 as (
    select *
        from (select soh.CustomerID
                , sum(TotalDue) as cantidad
                , row_number() over (order by sum(TotalDue) desc) as ranking
                from Sales.SalesOrderHeader soh
                left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
                where year(OrderDate) = 2013
                group by soh.CustomerID) v2013
        WHERE  v2013.ranking <= 1400
    )
,
vendidos_2014 as (
    select *
        from (select soh.CustomerID
                , sum(TotalDue) as cantidad
                , row_number() over (order by sum(TotalDue) desc) as ranking
                from Sales.SalesOrderHeader soh
                left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
                where year(OrderDate) = 2014
                group by soh.CustomerID) v2014
        WHERE  v2014.ranking <= 1400
    ),
conjunto as (
select
    v2011.CustomerID as producto2011
    , CASE WHEN v2012.CustomerID IS NULL THEN 0 ELSE 1 END as c_2012
    , CASE WHEN v2013.CustomerID IS NULL THEN 0 ELSE 1 END as c_2013
    , CASE WHEN v2014.CustomerID IS NULL THEN 0 ELSE 1 END as c_2014
        from vendidos_2011 v2011
        left join vendidos_2012 v2012 on v2011.CustomerID = v2012.CustomerID
        left join vendidos_2013 v2013 on v2011.CustomerID = v2013.CustomerID
        left join vendidos_2014 v2014 on v2011.CustomerID = v2014.CustomerID)
select count(distinct c.producto2011) as top_producto_2011 , sum (c.c_2012) as productos_retenidos_2012, sum (c.c_2013) as productos_retenidos_2013, sum(c.c_2014) as productos_retenidos_2014
from conjunto c

-- FIGURA 5


WITH primera_compra AS (
    SELECT
        CustomerID,
        MIN(YEAR(OrderDate)) AS año_primera_compra
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) BETWEEN 2011 AND 2014
    GROUP BY CustomerID
),
compras_por_cliente AS (
    SELECT
        soh.CustomerID,
        pc.año_primera_compra AS cohorte,
        YEAR(soh.OrderDate) AS año_observado
    FROM Sales.SalesOrderHeader soh
    JOIN primera_compra pc ON soh.CustomerID = pc.CustomerID
    WHERE YEAR(soh.OrderDate) BETWEEN 2011 AND 2014
        AND pc.año_primera_compra BETWEEN 2011 AND 2014
        AND YEAR(soh.OrderDate) >= pc.año_primera_compra
),
clientes_cohorte_retencion AS (
    SELECT
        cohorte,
        año_observado - cohorte AS año_desde_cohorte,
        COUNT(DISTINCT CustomerID) AS clientes_retenidos
    FROM compras_por_cliente
    GROUP BY cohorte, año_observado - cohorte
)
SELECT
    ccr.cohorte,
    ccr.año_desde_cohorte+cohorte as año_desde_cohorte ,
    round((CAST(ccr.clientes_retenidos AS FLOAT) /
     CAST(FIRST_VALUE(ccr.clientes_retenidos) OVER (PARTITION BY ccr.cohorte ORDER BY ccr.año_desde_cohorte) AS FLOAT)),2) * 100
     AS porcentaje
FROM clientes_cohorte_retencion ccr
order by ccr.cohorte, ccr.año_desde_cohorte asc

--FIGURA 6


WITH clientes_por_trimestre AS (
    SELECT
        YEAR(soh.OrderDate) AS año,
        (DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1) AS trimestre,
        soh.CustomerID,
        COUNT(*) AS compras_realizadas
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(soh.OrderDate) BETWEEN 2011 AND 2014
    GROUP BY
        YEAR(soh.OrderDate),
        (DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1),
        soh.CustomerID
),
top_clientes_por_año AS (
    SELECT
        año,
        trimestre,
        CustomerID
    FROM (
        SELECT
            año,
            trimestre,            
            CustomerID,
            ROW_NUMBER() OVER (PARTITION BY trimestre ORDER BY compras_realizadas DESC) AS ranking
        FROM clientes_por_trimestre
    ) ranked
    
),
combinaciones_clientes AS (
    SELECT
        c1.trimestre AS cohorte,
        c2.trimestre AS trimestre_observado,
        c1.CustomerID
    FROM top_clientes_por_año c1
    JOIN top_clientes_por_año c2
        ON c1.CustomerID = c2.CustomerID
        AND c2.trimestre >= c1.trimestre
),
retencion_clientes AS (
    SELECT
        cohorte,
        trimestre_observado - cohorte AS trimestre_desde_cohorte,
        COUNT(DISTINCT CustomerID) AS clientes_retenidos
    FROM combinaciones_clientes
    GROUP BY cohorte, trimestre_observado - cohorte
),
porcentajes_retencion AS (
    SELECT
        rc.cohorte AS trimestre_original,
        rc.trimestre_desde_cohorte AS trimestre_desde_original,
        ROUND(
            (CAST(rc.clientes_retenidos AS FLOAT) /
             CAST(FIRST_VALUE(rc.clientes_retenidos) OVER (PARTITION BY rc.cohorte ORDER BY rc.trimestre_desde_cohorte) AS FLOAT) * 100),
            2
        ) AS porcentaje
    FROM retencion_clientes rc
)
SELECT
    pr.trimestre_original,
    CASE
        WHEN pr.trimestre_original = 2 THEN '2T 2011'
        WHEN pr.trimestre_original = 3 THEN '3T 2011'
        WHEN pr.trimestre_original = 4 THEN '4T 2011'
        WHEN pr.trimestre_original = 5 THEN '1T 2012'
        WHEN pr.trimestre_original = 6 THEN '2T 2012'
        WHEN pr.trimestre_original = 7 THEN '3T 2012'
        WHEN pr.trimestre_original = 8 THEN '4T 2012'
        WHEN pr.trimestre_original = 9 THEN '1T 2013'
        WHEN pr.trimestre_original = 10 THEN '2T 2013'
        WHEN pr.trimestre_original = 11 THEN '3T 2013'
        WHEN pr.trimestre_original = 12 THEN '4T 2013'  
        WHEN pr.trimestre_original = 13 THEN '1T 2014'
        WHEN pr.trimestre_original = 14 THEN '2T 2014'
    END AS trimestre_label,
    pr.trimestre_desde_original+pr.trimestre_original,
    pr.porcentaje
FROM porcentajes_retencion pr


--FIGURA 7

WITH compradores_reincidentes_trimestre AS (
    SELECT
        soh.CustomerID AS cliente,
        DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1 AS trimestre,
        COUNT(soh.CustomerID) AS cantidad_pedidos
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    GROUP BY soh.CustomerID, DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1
    HAVING COUNT(soh.CustomerID) >= 2
),
total_compradores_trimestre AS (
    SELECT
        soh.CustomerID AS cliente,
        DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1 AS trimestre,
        COUNT(soh.CustomerID) AS cantidad_pedidos
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    GROUP BY soh.CustomerID, DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1
),
cantidad_reincidentes_trimestre AS (
    SELECT
        crt.trimestre,
        COUNT(crt.cliente) AS clientes_reincidentes
    FROM compradores_reincidentes_trimestre crt
    GROUP BY crt.trimestre
),
cantidad_totales_trimestre AS (
    SELECT
        tct.trimestre,
        COUNT(tct.cliente) AS clientes_totales
    FROM total_compradores_trimestre tct
    GROUP BY tct.trimestre
)
SELECT
    crt.trimestre,
    crt.clientes_reincidentes,
    ctt.clientes_totales,
    ROUND(CAST(crt.clientes_reincidentes AS FLOAT) / CAST(ctt.clientes_totales AS FLOAT) * 100, 2) AS porcentaje
FROM cantidad_reincidentes_trimestre crt
JOIN cantidad_totales_trimestre ctt ON crt.trimestre = ctt.trimestre


-- FIGURA 8 


with vendidos_2011 as (
    select *
        from (select sod.ProductID
                , count(*) as cantidad
                , row_number() over (order by count(*) desc) as ranking
                from Sales.SalesOrderHeader soh
                left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
                where year(OrderDate) = 2011
                group by sod.ProductID) v2011
        WHERE  v2011.ranking <= 100
    ) ,
vendidos_2012 as (
select * from (select sod.ProductID, count(*) as cantidad, row_number() over (order by count(*) desc) as ranking
from Sales.SalesOrderHeader soh
left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
where year(OrderDate) = 2012
group by sod.ProductID) v2012
WHERE  v2012.ranking <= 100
)
,
vendidos_2013 as (
select * from (select sod.ProductID, count(*) as cantidad, row_number() over (order by count(*) desc) as ranking
from Sales.SalesOrderHeader soh
left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
where year(OrderDate) = 2013
group by sod.ProductID) v2013
WHERE  v2013.ranking <= 100
)
,
vendidos_2014 as (
select * from (select sod.ProductID, count(*) as cantidad, row_number() over (order by count(*) desc) as ranking
from Sales.SalesOrderHeader soh
left join Sales.SalesOrderDetail sod on soh.SalesOrderID = sod.SalesOrderID
where year(OrderDate) = 2014
group by sod.ProductID) v2014
WHERE  v2014.ranking <= 100
)
,
conjunto as (
select
    v2011.ProductID as producto2011
    , CASE WHEN v2012.ProductID IS NULL THEN 0 ELSE 1 END as c_2012
    , CASE WHEN v2013.ProductID IS NULL THEN 0 ELSE 1 END as c_2013
    , CASE WHEN v2014.ProductID IS NULL THEN 0 ELSE 1 END as c_2014
        from vendidos_2011 v2011
        left join vendidos_2012 v2012 on v2011.ProductID = v2012.ProductID
        left join vendidos_2013 v2013 on v2011.ProductID = v2013.ProductID
        left join vendidos_2014 v2014 on v2011.ProductID = v2014.ProductID)
select count(distinct c.producto2011) as top_producto_2011 , sum (c.c_2012) as productos_retenidos_2012, sum (c.c_2013) as productos_retenidos_2013, sum(c.c_2014) as productos_retenidos_2014
from conjunto c


-- FIGURA 9 


WITH productos_por_año AS (
    SELECT
        YEAR(soh.OrderDate) AS año,
        sod.ProductID,
        COUNT(*) AS cantidad_vendida
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(soh.OrderDate) BETWEEN 2011 AND 2014
    GROUP BY YEAR(soh.OrderDate), sod.ProductID
),
top1000_por_año AS (
    SELECT
        año,
        ProductID
    FROM (
        SELECT
            año,
            ProductID,
            ROW_NUMBER() OVER (PARTITION BY año ORDER BY cantidad_vendida DESC) AS ranking
        FROM productos_por_año
    ) ranked
    WHERE ranking <= 1000
),
combinaciones AS (
    SELECT
        c1.año AS cohorte,
        c2.año AS año_observado,
        c1.ProductID
    FROM top1000_por_año c1
    JOIN top1000_por_año c2
        ON c1.ProductID = c2.ProductID
        AND c2.año >= c1.año  
),
productos_finales as (
SELECT
    cohorte,
    año_observado - cohorte AS año_desde_cohorte,
    COUNT(DISTINCT ProductID) AS productos_retenidos
FROM combinaciones
GROUP BY cohorte, año_observado - cohorte
)
SELECT
    pf.cohorte,
    pf.año_desde_cohorte+cohorte as año_desde_cohorte,
    round((CAST(pf.productos_retenidos AS FLOAT) /
     CAST(FIRST_VALUE(pf.productos_retenidos) OVER (PARTITION BY pf.cohorte ORDER BY pf.año_desde_cohorte) AS FLOAT)),2) * 100
     AS porcentaje
FROM productos_finales pf
order by pf.cohorte, pf.año_desde_cohorte asc

-- FIGURA 10

WITH productos_por_trimestre AS (
    SELECT
        YEAR(soh.OrderDate) AS año,
        (DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1) AS trimestre,
        sod.ProductID,
        COUNT(*) AS cantidad_vendida
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(soh.OrderDate) BETWEEN 2011 AND 2014
    GROUP BY
        YEAR(soh.OrderDate),
        (DATEDIFF(QUARTER, '2011-01-01', soh.OrderDate) + 1),
        sod.ProductID
),
top1000_por_año AS (
    SELECT
        año,
        trimestre,
        ProductID
    FROM (
        SELECT
            año,
            trimestre,            
            ProductID,
            ROW_NUMBER() OVER (PARTITION BY trimestre ORDER BY cantidad_vendida DESC) AS ranking
        FROM productos_por_trimestre
    ) ranked
    WHERE ranking <= 1000
),
combinaciones AS (
    SELECT
        c1.trimestre AS cohorte,
        c2.trimestre AS trimestre_observado,
        c1.ProductID
    FROM top1000_por_año c1
    JOIN top1000_por_año c2
        ON c1.ProductID = c2.ProductID
        AND c2.trimestre >= c1.trimestre
),
productos_finales AS (
    SELECT
        cohorte,
        trimestre_observado - cohorte AS trimestre_desde_cohorte,
        COUNT(DISTINCT ProductID) AS productos_retenidos
    FROM combinaciones
    GROUP BY cohorte, trimestre_observado - cohorte
),
porcentajes AS (
    SELECT
        pf.cohorte AS trimestre_original,
        pf.trimestre_desde_cohorte AS trimestre_desde_original,
        ROUND(
            (CAST(pf.productos_retenidos AS FLOAT) /
             CAST(FIRST_VALUE(pf.productos_retenidos) OVER (PARTITION BY pf.cohorte ORDER BY pf.trimestre_desde_cohorte) AS FLOAT)) * 100,
            2
        ) AS porcentaje
    FROM productos_finales pf
)
SELECT
    ps.trimestre_original,
    CASE
        WHEN ps.trimestre_original = 2 THEN '2T 2011'
        WHEN ps.trimestre_original = 3 THEN '3T 2011'
        WHEN ps.trimestre_original = 4 THEN '4T 2011'
        WHEN ps.trimestre_original = 5 THEN '1T 2012'
        WHEN ps.trimestre_original = 6 THEN '2T 2012'
        WHEN ps.trimestre_original = 7 THEN '3T 2012'
        WHEN ps.trimestre_original = 8 THEN '4T 2012'
        WHEN ps.trimestre_original = 9 THEN '1T 2013'
        WHEN ps.trimestre_original = 10 THEN '2T 2013'
        WHEN ps.trimestre_original = 11 THEN '3T 2013'
        WHEN ps.trimestre_original = 12 THEN '4T 2013'  
        WHEN ps.trimestre_original = 13 THEN '1T 2014'
        WHEN ps.trimestre_original = 14 THEN '2T 2014'
    END AS trimestre_label,
    ps.trimestre_desde_original+ps.trimestre_original as trimestre_desde_original,
    ps.porcentaje
FROM porcentajes ps

-- FIGURA 11


with productos_por_anio as (    
SELECT
    year(soh.orderDate) as anio,
    p.productID,
    p.Name AS ProductName,
    ps.Name as CategoryName,
    sum(sod.OrderQty) AS total_unidades_vendidas
FROM
    sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod on sod.SalesOrderID = soh.SalesOrderID
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    join Production.ProductSubcategory ps on p.ProductSubcategoryID = ps.ProductSubcategoryID
    group by year(soh.orderDate), p.productID, p.Name, ps.Name
    ),
  ranking_5 as ( select *
                , row_number () over (partition by ppa.anio order by ppa.total_unidades_vendidas desc) as rank5
                    from productos_por_anio ppa)
select *
from ranking_5 r
where r.rank5 <= 5  
order by anio , rank5

-- FIGURA 12


WITH clientes_por_trimestre AS (
    SELECT
        YEAR(soh.OrderDate) AS año,
        DATEDIFF(QUARTER,'2011-01-01',soh.OrderDate)+1 AS trimestre,
        soh.CustomerID,
        COUNT(*) AS compras_realizadas
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(soh.OrderDate) BETWEEN 2011 AND 2014
    GROUP BY YEAR(soh.OrderDate),
             DATEDIFF(QUARTER,'2011-01-01',soh.OrderDate)+1,
             soh.CustomerID
),
top_clientes_por_año AS (
    SELECT año,trimestre,CustomerID
    FROM (
        SELECT  año,trimestre,CustomerID,
                ROW_NUMBER() OVER (PARTITION BY trimestre
                                   ORDER BY compras_realizadas DESC) AS ranking
        FROM clientes_por_trimestre
    ) AS r
   
),
combinaciones_clientes AS (
    SELECT c1.trimestre        AS cohorte,
           c2.trimestre        AS trimestre_observado,
           c1.CustomerID
    FROM top_clientes_por_año c1
    JOIN top_clientes_por_año c2
         ON c1.CustomerID = c2.CustomerID
        AND c2.trimestre >= c1.trimestre
),
retencion_clientes AS (
    SELECT cohorte,
           trimestre_observado - cohorte AS trimestres_desde_cohorte,
           COUNT(DISTINCT CustomerID)    AS clientes_retenidos
    FROM combinaciones_clientes
    GROUP BY cohorte, trimestre_observado - cohorte
),
tabla_pivot AS (
    SELECT  cohorte,
            ISNULL([0],0)  AS trimestre0,
            ISNULL([1],0)  AS trimestre1,
            ISNULL([2],0)  AS trimestre2,
            ISNULL([3],0)  AS trimestre3,
            ISNULL([4],0)  AS trimestre4,
            ISNULL([5],0)  AS trimestre5,
            ISNULL([6],0)  AS trimestre6,
            ISNULL([7],0)  AS trimestre7,
            ISNULL([8],0)  AS trimestre8,
            ISNULL([9],0)  AS trimestre9,
            ISNULL([10],0) AS trimestre10,
            ISNULL([11],0) AS trimestre11,
            ISNULL([12],0) AS trimestre12
    FROM retencion_clientes
    PIVOT (
        SUM(clientes_retenidos)
        FOR trimestres_desde_cohorte IN
            ([0],[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
    ) AS p
)
SELECT
    cohorte,
    CAST(2011 + (cohorte-1)/4 AS VARCHAR)          
+ 'Q' +
CAST(((cohorte-1) % 4) + 1 AS VARCHAR)        
      AS periodo_cohorte_corregido,
    trimestre0,  trimestre1,  trimestre2,  trimestre3,
    trimestre4,  trimestre5,  trimestre6,  trimestre7,
    trimestre8,  trimestre9,  trimestre10, trimestre11, trimestre12,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre0 *100.0/trimestre0, 2) ELSE 0 END AS ret_t0_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre1 *100.0/trimestre0, 2) ELSE 0 END AS ret_t1_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre2 *100.0/trimestre0, 2) ELSE 0 END AS ret_t2_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre3 *100.0/trimestre0, 2) ELSE 0 END AS ret_t3_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre4 *100.0/trimestre0, 2) ELSE 0 END AS ret_t4_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre5 *100.0/trimestre0, 2) ELSE 0 END AS ret_t5_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre6 *100.0/trimestre0, 2) ELSE 0 END AS ret_t6_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre7 *100.0/trimestre0, 2) ELSE 0 END AS ret_t7_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre8 *100.0/trimestre0, 2) ELSE 0 END AS ret_t8_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre9 *100.0/trimestre0, 2) ELSE 0 END AS ret_t9_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre10*100.0/trimestre0, 2) ELSE 0 END AS ret_t10_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre11*100.0/trimestre0, 2) ELSE 0 END AS ret_t11_pct,
    CASE WHEN trimestre0>0 THEN ROUND(trimestre12*100.0/trimestre0, 2) ELSE 0 END AS ret_t12_pct
FROM tabla_pivot
ORDER BY cohorte

-- FIGURA 13

SELECT
    YEAR(OrderDate) AS Año,
    MONTH(OrderDate) AS Mes,
    DATENAME(MONTH, OrderDate) AS Mes_nombre,
    ROUND(SUM(TotalDue), 2) AS Ventas_totales
FROM
    Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
ORDER BY Año ASC, Mes ASC

-- FIGURA 14


SELECT
    YEAR(soh.OrderDate) AS Año,
    MONTH(soh.OrderDate) AS Mes,
    DATENAME(MONTH, soh.OrderDate) AS Mes_nombre,
    st.Name AS Territorio,
    ROUND(SUM(soh.TotalDue), 2) AS Ventas_totales
FROM
    Sales.SalesOrderHeader soh
    LEFT JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate), DATENAME(MONTH, soh.OrderDate), st.Name
ORDER BY Año ASC, Mes ASC, Territorio ASC

