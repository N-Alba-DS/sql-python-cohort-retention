# sql-python-cohort-retention

El presente trabajo tiene como objetivo realizar análisis de retención y reincidencia de cohortes y estudios
de tendencias por periodos temporales. Este trabajo es realizado en la base de datos
AdventureWorks2019, a tales efectos se utiliza Python en conjunto con la librería PYODBC para realizar
consultas SQL y obtener los datos que servirán como base para la creación de gráficos con la asistencia
de PANDAS, SEABORN y MATPLOTLIB.
El análisis se centra en dos dimensiones principales: clientes y productos. Ambas dimensiones
analizadas en relación a las ventas. De esta manera el esquema Sales será el más utilizado con sus
tablas Sales.SalesOrderHeader y Sales.SalesOrderDetail. Sin embargo excepcionalmente cuando el
análisis lo requiera se pueden incluir otro tipo de tablas del esquema Production para enfocarnos en sí
determinada tendencia responde a la naturaleza del producto ofrecido.
El análisis comienza por un análisis de tendencias temporales de las ganancias obtenidas por la empresa
(Figura 1). Se observa un salto significativo en el año 2013 alcanzando un monto de 48 millones de
dolares. Esto nos sirvió para pensar una pregunta de si había alguna causalidad en dicho incremento o
era producto del azar.
<p align="center">
  <img src="img/1_Ganancias_a_lo_largo_de_los_años.png" alt="Ganancias" width="600"/>
</p>

