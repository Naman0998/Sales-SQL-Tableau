USE salesdb
GO

SELECT * FROM [dbo].[sales_data_sample];

-- Checking Unique values
SELECT DISTINCT status from [dbo].[sales_data_sample]; -- Nice to report
SELECT DISTINCT YEAR_ID from [dbo].[sales_data_sample];
SELECT DISTINCT PRODUCTLINE from [dbo].[sales_data_sample]; -- Report
SELECT DISTINCT COUNTRY from [dbo].[sales_data_sample]; -- Report
SELECT DISTINCT DEALSIZE from [dbo].[sales_data_sample]; -- Report
SELECT DISTINCT TERRITORY from [dbo].[sales_data_sample];


--- ANALYSIS
--Grouping Sales by ProductLine
select PRODUCTLINE, round(sum(sales),2) Revenue 
from [salesdb].[dbo].[sales_data_sample]
group by PRODUCTLINE
order by 2 desc

-- Yearly Sales
select YEAR_ID, round(sum(sales),2) Revenue 
from [salesdb].[dbo].[sales_data_sample]
group by YEAR_ID
order by 2 desc

-- Deal Size Sales
select DEALSIZE, round(sum(sales),2) Revenue 
from [salesdb].[dbo].[sales_data_sample]
group by DEALSIZE
order by 2 desc

-- What is the best month for sales in a specific year? How much in earned in that month
select MONTH_ID, round(sum(sales),2) Revenue, count(ORDERNUMBER) Frequency
from [salesdb].[dbo].[sales_data_sample]
where YEAR_ID = 2003
group by MONTH_ID
order by 2 desc;

--It Seems in all years, maximum sales is reported in November, now find the product sold most in November
select MONTH_ID, PRODUCTLINE, round(sum(sales),2) Revenue, count(ORDERNUMBER) Frequency
from [salesdb].[dbo].[sales_data_sample]
where YEAR_ID = 2003 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by 3 desc; 

--Performing RFM(Recency - Frequency - Monetary) which is an indexing technique that uses past purchase behavior to segment customer.
-- in our case Recency = last order date
-- Frequency = count of total Orders
-- Monetary Value = total spend

DROP TABLE IF EXISTS #rfm
;with rfm as
(
	select 
	CUSTOMERNAME,
		round(sum(sales),2) Monetary_Value,
		round(avg(sales),2) Avg_MonV,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from [salesdb].[dbo].[sales_data_sample]) max_order_date,
		DATEDIFF(DD,max(ORDERDATE),(select max(ORDERDATE) from [salesdb].[dbo].[sales_data_sample])) Recency
	from [salesdb].[dbo].[sales_data_sample]

	group by CUSTOMERNAME
),
rfm_calc as
(
	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency desc) rfm_frequency,
		NTILE(4) OVER (order by Monetary_Value desc) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) rfm_cell_st
into #rfm
from rfm_calc c


select * from #rfm

select CUSTOMERNAME, rfm_recency , rfm_frequency , rfm_monetary,
	case
		when rfm_cell_st in (111, 112, 121, 122, 123, 132, 211, 212, 314, 341) then 'lost_customers' -- we lost these customers
		when rfm_cell_st in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- Big Customers who havn't purchased lately, slipping
		when rfm_cell_st in (311, 411, 331) then 'new_customers'
		when rfm_cell_st in (222, 223, 232, 322) then 'potential churners'
		when rfm_cell_st in (323, 333, 321, 422, 332, 432) then 'active' -- Who buy regularly but buy low amount
		when rfm_cell_st in (433, 434, 443, 444) then 'loyal'
	end rfm_segment

from #rfm

-- Which Products are usually sold together

select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from [salesdb].[dbo].[sales_data_sample] p
	where ORDERNUMBER in
		(
			select ORDERNUMBER
			from (
					select ORDERNUMBER, count(*) rn
					from [salesdb].[dbo].[sales_data_sample]
					where STATUS = 'Shipped'
					group by ORDERNUMBER
					) m
					where rn = 3
				)
				and p.ORDERNUMBER = s.ORDERNUMBER
				for xml path(''))

				, 1, 1, '') ProductCodes

from [salesdb].[dbo].[sales_data_sample] s
order by 2 desc