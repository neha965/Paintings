use famous_paintings;

--1) Fetch all the paintings which are not displayed on any museums?
SELECT [name] FROM work
WHERE museum_id IS NULL;

--2) Are there museuems without any paintings?
SELECT * FROM museum 
WHERE museum_id NOT IN (
	       SELECT museum_id FROM work )

--Alternative Solution:
SELECT * FROM museum m
WHERE NOT EXISTS (
        SELECT 1 FROM work w
		WHERE m.museum_id = w.museum_id)

--3) How many paintings have an asking price of more than their regular price? 
SELECT COUNT(work_id) as count_paintings
FROM product_size
WHERE sale_price>regular_price

--4) Identify the paintings whose asking price is less than 50% of its regular price
SELECT * FROM product_size
WHERE sale_price< (regular_price*0.5)

--5) Which canva size costs the most?
SELECT TOP 1 cs.label as canva, ps.sale_price
FROM product_size ps
JOIN canvas_size cs
ON cs.size_id=ps.size_id
ORDER BY ps.sale_price DESC

--Alternative Solution:
WITH cte as (
SELECT *, RANK() OVER(ORDER BY sale_price DESC)
AS rnk_price
FROM product_size
)
SELECT cs.label as canva, cte.sale_price
FROM canvas_size cs
JOIN cte
ON cs.size_id=cte.size_id
WHERE rnk_price=1
	
--6) Delete duplicate records from work, product_size, subject and image_link tables
DELETE w1
FROM work w1
JOIN work w2
WHERE w1.[name]= w2.[name] 
AND w1.artist_id= w2.artist_id 
AND w1.style= w2.style 
AND w1.museum_id= w2.museum_id 
AND w1.work_id > w2.work_id; 

DELETE ps1
FROM product_size ps1
JOIN product_size ps2
ON ps1.size_id = ps2.size_id
AND ps1.regular_price = ps2.regular_price
AND ps1.work_id > ps2.work_id;

DELETE s1
FROM subject s1
JOIN subject s2
ON s1.subject_id = s2.subject_id
AND s1.subject_name = s2.subject_name
AND s1.subject_id > s2.subject_id;

DELETE il1
FROM image_link il1
JOIN image_link il2
ON il1.link_id = il2.link_id
AND il1.link_url = il2.link_url
AND il1.link_id > il2.link_id;

--Using ROW_NUMBER()
WITH cte as (
SELECT *, ROW_NUMBER() OVER(PARTITION BY [name], artist_id, style, museum_id ORDER BY work_id) AS row_num
FROM work
)

DELETE FROM work
WHERE work_id IN (
    SELECT work_id
    FROM cte
    WHERE row_num > 1
);

WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY size_id, regular_price ORDER BY size_id) AS row_num
    FROM product_size
)
DELETE FROM product_size
WHERE size_id IN (
    SELECT size_id
    FROM CTE
    WHERE row_num > 1
);

WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY subject_id, subject_name ORDER BY subject_id) AS row_num
    FROM subject
)
DELETE FROM subject
WHERE subject_id IN (
    SELECT subject_id
    FROM CTE
    WHERE row_num > 1
);

WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY link_id, link_url ORDER BY link_id) AS row_num
    FROM image_link
)
DELETE FROM image_link
WHERE link_id IN (
    SELECT link_id
    FROM CTE
    WHERE row_num > 1
);


--7) Identify the museums with invalid city information in the given dataset
SELECT museum_id, [name], city
FROM museum
WHERE city LIKE '%[0-9]%';

--8) Museum_Hours table has 1 invalid entry. Identify it and remove it. [Duplicate Value]
with cte as (
select *, ROW_NUMBER() OVER (PARTITION BY museum_id,[day] ORDER BY museum_id) AS row_num
FROM museum_hours
)
DELETE FROM museum_hours
WHERE museum_id IN (
        SELECT museum_id FROM cte
		WHERE row_num>1)

--9) Fetch the top 10 most famous painting subject
SELECT TOP 10 s.[subject], COUNT(s.[subject]) as no_of_paintings
FROM [subject] s
JOIN work w
on s.work_id=w.work_id
group by s.[subject]
Order by COUNT(s.[subject]) DESC

--Using RANK():
with cte as (
		select s.subject,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as ranking
		from work w
		join subject s on s.work_id=w.work_id
		group by s.subject ) 

SELECT * FROM cte
where ranking <= 10;

--10) Identify the museums which are open on both Sunday and Monday. Display museum name, city.
SELECT DISTINCT m.name as museum_name, m.city, m.state,m.country
	FROM museum_hours mh 
	JOIN museum m ON m.museum_id=mh.museum_id
	WHERE day='Sunday'
	AND EXISTS (SELECT 1 FROM museum_hours mh2 
				WHERE mh2.museum_id=mh.museum_id 
			    AND mh2.day='Monday');

--Alternative:
SELECT DISTINCT m.name as museum_name, m.city, m.state,m.country
	FROM museum_hours mh 
	JOIN museum m ON m.museum_id=mh.museum_id
	WHERE day='Sunday'
	AND mh.museum_id IN (SELECT mh.museum_id FROM museum_hours mh2 
				WHERE mh2.museum_id=mh.museum_id 
			    AND mh2.day='Monday');

--11) How many museums are open every single day?
WITH cte AS (
    SELECT *, COUNT(museum_id) OVER (PARTITION BY day ORDER BY museum_id) AS count_museum
    FROM museum_hours
)
SELECT COUNT(*)
FROM (
    SELECT museum_id
    FROM cte
    GROUP BY museum_id
    HAVING COUNT(museum_id) = 7
) AS subquery;

--Directly using subquery:
select count(*)
	from (select museum_id
		  from museum_hours
		  group by museum_id
		  having count(museum_id) = 7) x;

--12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
WITH cte AS (
    SELECT m.museum_id, COUNT(w.name) AS paintings_count, RANK() OVER (ORDER BY COUNT(w.name) DESC) AS rnk
    FROM museum m
    JOIN work w ON m.museum_id = w.museum_id
    GROUP BY m.museum_id
)
SELECT cte.rnk, m.museum_id, m.name, cte.paintings_count
FROM cte
JOIN museum m ON m.museum_id = cte.museum_id
WHERE cte.rnk <= 5;

--Using subquery
select m.name as museum, m.city,m.country,x.no_of_painintgs
	from (	select m.museum_id, count(1) as no_of_painintgs
			, rank() over(order by count(1) desc) as rnk
			from work w
			join museum m on m.museum_id=w.museum_id
			group by m.museum_id) x
	join museum m on m.museum_id=x.museum_id
	where x.rnk<=5;

--13) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
WITH cte AS (
SELECT a.artist_id, COUNT(w.work_id) AS no_of_paintings, RANK() OVER (ORDER BY COUNT(w.work_id) DESC) AS rnk
FROM artist a
JOIN work w
ON a.artist_id=w.artist_id
GROUP BY a.artist_id
)
SELECT cte.rnk, a.full_name, a.nationality, cte.no_of_paintings
FROM cte
JOIN artist a
ON a.artist_id=cte.artist_id
WHERE cte.rnk<=5

--Using subquery:
select a.full_name as artist, a.nationality,x.no_of_painintgs
	from (	select a.artist_id, count(1) as no_of_painintgs
			, rank() over(order by count(1) desc) as rnk
			from work w
			join artist a on a.artist_id=w.artist_id
			group by a.artist_id) x
	join artist a on a.artist_id=x.artist_id
	where x.rnk<=5;

--14) Display the 3 least popular canva sizes (Least number of canvas used in paintings)
WITH cte AS (
    SELECT cs.size_id, cs.label, COUNT(cs.size_id) as no_of_paintings, 
	DENSE_RANK() over(order by count(cs.size_id)) as ranking
    FROM 
        work w
    JOIN 
        product_size ps ON ps.work_id = w.work_id
    JOIN 
        canvas_size cs ON CAST(cs.size_id AS varchar)= ps.size_id    --As size_id is in bigint data type in cavas_size table
    GROUP BY cs.size_id, cs.label
)
SELECT label, ranking, no_of_paintings
FROM 
    cte
WHERE 
    ranking <= 3;

--15) Which museum has the most no of most popular painting style?
with pop_style as
           (select style
			,rank() over(order by count(1) desc) as rnk
			from work
			group by style),
cte as
			(select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings
			,rank() over(order by count(1) desc) as rnk
			from work w
			join museum m on m.museum_id=w.museum_id
			join pop_style ps on ps.style = w.style
			where w.museum_id is not null
			and ps.rnk=1
			group by w.museum_id, m.name,ps.style)

select museum_name,style,no_of_paintings, rnk
	from cte;

--16) Identify the artists whose paintings are displayed in multiple countries
with cte as (select distinct a.full_name as artist
		--, w.name as painting, m.name as museum
		, m.country
		from work w
		join artist a on a.artist_id=w.artist_id
		join museum m on m.museum_id=w.museum_id) 

select artist,count(1) as no_of_countries
from cte
group by artist
having count(1)>1
order by 2 desc;

--17) Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.

WITH cte_country AS (
    SELECT distinct country, COUNT(1) AS cnt,
           RANK() OVER (ORDER BY COUNT(1) DESC) AS rnk
    FROM museum
    GROUP BY country
),
cte_city AS (
    SELECT city, COUNT(1) AS cnt,
           RANK() OVER (ORDER BY COUNT(1) DESC) AS rnk
    FROM museum
    GROUP BY city
)
select string_agg(country.country,', ') AS top_countries, string_agg(city.city,', ') AS top_cities
	from cte_country country
	cross join cte_city city
	where country.rnk = 1
	and city.rnk = 1;

--18) Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label
with cte as (SELECT *, RANK() OVER (ORDER BY sale_price) as rnk_max
, RANK() OVER (ORDER BY sale_price DESC) as rnk_min
FROM product_size
)

SELECT w.name as painting, a.full_name as artist_name, m.name as museum_name, w.work_id, m.city, cte.sale_price
FROM work w
JOIN artist a ON a.artist_id=w.artist_id
JOIN museum m ON m.museum_id=w.museum_id
JOIN cte ON cte.work_id=w.work_id
join canvas_size cz on cz.size_id = CAST(cte.size_id as integer)
WHERE rnk_max= 1 or rnk_min =1 --OR is used beacuse it's not possible that a painting is both most and least expensive

--19) Which country has the 5th highest no of paintings?
with cte AS (SELECT m.country, COUNT(w.work_id) AS no_of_paintings, DENSE_RANK() OVER(ORDER BY COUNT(w.work_id)) AS rnk
FROM work w
JOIN museum m
ON w.museum_id= m.museum_id
GROUP BY m.country)

SELECT country, no_of_paintings
FROM cte
WHERE rnk=5

--20) Which are the 3 most popular and 3 least popular painting styles?
with cte as(SELECT w.style, COUNT(a.style) AS count_style, DENSE_RANK() OVER(ORDER BY COUNT(a.style) DESC) AS most_popular, 
DENSE_RANK() OVER(ORDER BY COUNT(a.style) ) AS least_popular
FROM work w
JOIN artist a
ON w.artist_id=a.artist_id
GROUP BY w.style
HAVING w.style IS NOT NULL)

SELECT style, count_style
FROM cte
WHERE most_popular<=3 
UNION
SELECT style, count_style
FROM cte
WHERE least_popular<=3 

--Alternative Solution:
with cte as 
		(select style, count(1) as cnt
		, rank() over(order by count(1) desc) rnk
		, count(1) over() as no_of_records
		from work
		where style is not null
		group by style)
	select style
	, case when rnk <=3 then 'Most Popular' else 'Least Popular' end as remarks 
	from cte
	where rnk <=3
	or rnk > no_of_records - 3;


--21) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.

with cte as (
SELECT a.full_name as artist_name, a.nationality as nationality, COUNT(w.work_id) as no_of_paintings,
RANK() OVER (ORDER BY COUNT(w.work_id) DESC) as rnk
FROM artist a
JOIN work w ON w.artist_id=a.artist_id
JOIN museum m ON m.museum_id=w.museum_id
JOIN subject s ON s.work_id=w.work_id
WHERE s.subject = 'Portraits' AND m.country != 'USA'
GROUP BY a.full_name, a.nationality
)

SELECT artist_name, nationality, no_of_paintings
FROM cte
WHERE rnk=1;

