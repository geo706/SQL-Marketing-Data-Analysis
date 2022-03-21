/* 
Exploring marketing data 
Skills used: Aggregate, CASE, Joins, Subqueries, CTE's, Windows Functions
*/

SELECT *
FROM `marketing-analysis-316905.marketing_data.marketing_data` 
order by ID
LIMIT 100

 -- Calculating the age of customers given their birth year
 
SELECT year_birth, age
FROM (select year_birth, (EXTRACT(year from current_date)- year_birth) AS age
FROM `marketing-analysis-316905.marketing_data.marketing_data`)



-- Looking at the company's most *common* customer age and their average income, by country

select year_birth, (EXTRACT(year from current_date)- year_birth) as current_age, count(year_birth) as count, avg(_income_) as average_income
from `marketing-analysis-316905.marketing_data.marketing_data` 
group by 1
ORDER BY 3 DESC



-- Splitting age into 4 tiers (25 - 49, 50 - 74, 75 - 99, 100+) and seeing which group spent the most on meat in the past 2 years
-- Age tiers were originally created based on the youngest and oldest customers

SELECT CASE 
    WHEN (2021-year_birth) >= 25 AND (2021-year_birth) <= 49 THEN '25-49'
    WHEN (2021-year_birth) >= 50 AND (2021-year_birth) <=74 THEN '50-74'
    WHEN (2021-year_birth) >= 75 AND (2021-year_birth) <= 99 THEN '75 - 99'
    WHEN (2021-year_birth) >= 100 THEN '100+' END AS age_range,
    sum(MntMeatProducts) as amount_spent_meat, count(MntMeatProducts) as frequency_meat_purchased
FROM `marketing-analysis-316905.marketing_data.marketing_data`  
GROUP BY age_range



-- From the previous query, it seems like the meat buyers were concentrated in the 25-74 age range so I wanted to a more accurate view on the 
-- age range of those who have spent the most on meat, as well as their average income and how many customers were the same age

SELECT year_birth, avg(_income_) as average_income, (EXTRACT(year from current_date)- year_birth) AS age, count(year_birth) AS number_of_customer, 
	sum(MntMeatProducts) as amount_spent_meat
FROM `marketing-analysis-316905.marketing_data.marketing_data` 
GROUP BY 1
order by 5 desc



--Calculating which product sells the best across all customers

select AVG(MntWines) as spent_wine, AVG(MntFruits) as spent_fruits, AVG(MntMeatProducts) as spent_meat, AVG(MntFishProducts) as spent_fish, 
    AVG(MntSweetProducts) as spent_sweet, AVG(MntGoldProds) as spent_gold
FROM `marketing-analysis-316905.marketing_data.marketing_data`



-- Joining another table that has information on the number of purchases made through the companies website, the catalogue, or directly in store

select *
from `marketing-analysis-316905.marketing_data.marketing_data` amount
join `marketing-analysis-316905.marketing_data.marketing_data_web` web
on amount.id = web.ID



-- Looking at customers who have spent the most on all products combined in the last two years and their medium of choice for 
-- purchasing (through web, catalogic, or in store)

select amount.id, (MntWines + MntFruits +  MntMeatProducts + MntFishProducts +  MntSweetProducts + MntGoldProds) AS total_spent, web.NumWebPurchases, 
	web.NumCatalogPurchases, web.NumStorePurchases
from `marketing-analysis-316905.marketing_data.marketing_data` amount
join `marketing-analysis-316905.marketing_data.marketing_data_web` web
on amount.id = web.ID
ORDER BY 2 DESC



-- Breaking the data down by country and showing the total number of web, catalog, and store purchases as well as their respective percentages out 
-- of total purchases. According to the data, most customers are from Spain. For all countries, the majority of their purchases are from the 
-- store, then from the web, then from the catalog.

select *, (total_web_purchases/total)*100 AS percentage_web_purchases, (total_catalog_purchases/total)*100 AS percentage_catalog_purchases, 
	(total_store_purchases/total)*100 AS percentage_store_purchases
from (
    select *, (total_web_purchases + total_catalog_purchases  + total_store_purchases ) as total
    from (
        select amount.country, sum(web.NumWebPurchases) as total_web_purchases, sum(web.NumCatalogPurchases) as total_catalog_purchases, 
			sum(web.NumStorePurchases) as total_store_purchases
            from `marketing-analysis-316905.marketing_data.marketing_data` amount
            join `marketing-analysis-316905.marketing_data.marketing_data_web` web
            on amount.id = web.ID
        GROUP BY 1)
    order by 2 desc )


-- Another way to calculate the above query using Common Table Expressions 

with totals as (
    select amount.country, sum(web.NumWebPurchases) as total_web_purchases, sum(web.NumCatalogPurchases) as total_catalog_purchases, 
		sum(web.NumStorePurchases) as total_store_purchases,
		(sum(web.NumWebPurchases) + sum(web.NumCatalogPurchases)  + sum(web.NumStorePurchases) ) as total
        from `marketing-analysis-316905.marketing_data.marketing_data` amount
        join `marketing-analysis-316905.marketing_data.marketing_data_web` web
        on amount.id = web.ID
    GROUP BY 1
    order by 2 desc ),

percentage as (
    select *, (total_web_purchases/total)*100 AS percentage_web_purchases, (total_catalog_purchases/total)*100 AS percentage_catalog_purchases, 
		(total_store_purchases/total)*100 AS percentage_store_purchases
    from totals)

select * 
from percentage



-- Finding all of the biggest spenders in the last 2 years whose days since last purchase is longer than the average. Since these customers 
-- have a proven history of purchasing, yet haven't purchased for a while, it may be effective to send them a discount code to incentivize 
-- them to purchase again.

select ID, (MntWines + MntFruits +  MntMeatProducts + MntFishProducts +  MntSweetProducts + MntGoldProds) AS total_spent, recency
from `marketing-analysis-316905.marketing_data.marketing_data`
where recency > (select avg(recency) from `marketing-analysis-316905.marketing_data.marketing_data`)
ORDER BY 2 DESC


-- Checking to see if the average days since last purchase was skewed, so I looked for the median days since a customer's last purchase instead. 
-- The result ended up being very close to the average.

with median_recency as (
    select recency, ROW_NUMBER() OVER (ORDER BY recency) as ranking, 
		(SELECT count(recency) from `marketing-analysis-316905.marketing_data.marketing_data`) as count
    from `marketing-analysis-316905.marketing_data.marketing_data`
    )
    
select avg(recency) as median
from median_recency 
where ranking between count/2 AND (count/2)+1



-- Seeing if a higher average income leads to more spend at the store. Income split in quartiles per country. 

select Country,  Quartile, sum(total_spent) AS amount_spent, 
	ROUND(AVG(_Income_), 2) AS average_income--AVG(_Income_) OVER (PARTITION BY Quartile) AS average_income
from (
    select Country, _Income_, NTILE(4) OVER (PARTITION BY Country ORDER BY _Income_ DESC) AS Quartile, 
    (MntWines + MntFruits +  MntMeatProducts + MntFishProducts +  MntSweetProducts + MntGoldProds) AS total_spent
    from `marketing-analysis-316905.marketing_data.marketing_data`)
GROUP BY 1, 2
ORDER BY 1, 3 DESC

