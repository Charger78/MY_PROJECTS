/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Журавлева Анастасия
 * Дата:09.11.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
categories AS (
    SELECT a.id,
           a.days_exposition,
           a.last_price,
           f.total_area,
           f.rooms,
           f.balcony,
           f.ceiling_height,
           f.floors_total,
           c.city,
           t.type,
        CASE WHEN c.city = 'Санкт-Петербург' THEN 'Saint_petersburg'
            ELSE 'Leningrad_region'
            END AS region,
        CASE WHEN a.days_exposition IS NULL THEN 'active'
             WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'up_to_month'
             WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'up_to_three_months'
             WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'up_to_six_months'
             WHEN a.days_exposition >= 181 THEN 'more_than_six_months'
             END AS activity,
             a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm
    FROM real_estate.advertisement AS a
    INNER JOIN filtered_id AS fi USING (id)
    INNER JOIN real_estate.flats AS f USING (id)
    INNER JOIN real_estate.city AS c USING (city_id)
    INNER JOIN real_estate.type AS t USING (type_id)
    WHERE t.type = 'город'
      AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
)
SELECT region,
       activity,
       ROUND(AVG(price_per_sqm)::numeric, 2) AS avg_price_per_sqm,
       ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors,
       COUNT(*) as listings_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY region), 2) AS region_percentage,
       ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
       ROUND(COUNT(CASE WHEN rooms = 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS studio_apartments_percentage,
       ROUND(COUNT(CASE WHEN rooms = 1 THEN 1 END) * 100.0 / COUNT(*), 2) AS one_room_apartments_percentage,
       ROUND(COUNT(CASE WHEN rooms >= 3 THEN 1 END) * 100.0 / COUNT(*), 2) AS three_plus_rooms_percentage,
       ROUND(COUNT(CASE WHEN balcony > 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS with_balcony_percentage,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ceiling_height)::numeric, 2) AS median_ceiling_height
FROM categories
GROUP BY region, activity
ORDER BY 
    CASE region 
        WHEN 'Saint_petersburg' THEN 1 
        ELSE 2 
        END,
    CASE activity
        WHEN 'active' THEN 1
        WHEN 'up_to_month' THEN 2
        WHEN 'up_to_three_months' THEN 3
        WHEN 'up_to_six_months' THEN 4
        WHEN 'more_than_six_months' THEN 5
        END;
   



-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
filtered_ads AS (
    SELECT a.id,
           a.first_day_exposition,
           a.days_exposition,
           a.last_price,
           f.total_area,
           (a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) AS closing_date,
           a.last_price / NULLIF(f.total_area, 0) AS price_per_sqm,
           TO_CHAR(a.first_day_exposition, 'Month') AS publication_month,
           EXTRACT(MONTH FROM a.first_day_exposition) AS publication_month_num
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f USING (id)
    JOIN real_estate.city AS c USING (city_id)
    JOIN real_estate.type AS t USING (type_id)
    WHERE a.id IN (SELECT id FROM filtered_id)
      AND t.type = 'город'
      AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
      AND a.last_price > 0
),
monthly_publication_stats AS (
    SELECT publication_month,
           publication_month_num,
           COUNT(*) AS publication_count,
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS publication_percentage,
           ROUND(AVG(price_per_sqm)::numeric, 2) AS avg_publication_price_per_sqm,
           ROUND(AVG(total_area)::numeric, 2) AS avg_publication_area,
           RANK() OVER(ORDER BY COUNT(*) DESC) AS publication_rank
    FROM filtered_ads
    GROUP BY publication_month, publication_month_num
),
monthly_closing_stats AS (
    SELECT TO_CHAR(closing_date, 'Month') AS closing_month,
           EXTRACT(MONTH FROM closing_date) AS closing_month_num,
           COUNT(*) AS closing_count,
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS closing_percentage,
           ROUND(AVG(price_per_sqm)::numeric, 2) AS avg_closing_price_per_sqm,
           ROUND(AVG(total_area)::numeric, 2) AS avg_closing_area,
           RANK() OVER(ORDER BY COUNT(*) DESC) AS closing_rank
    FROM filtered_ads
    WHERE closing_date IS NOT NULL
    GROUP BY closing_month, closing_month_num
)
SELECT p.publication_month AS month_name,
       p.publication_count AS publication_count,
       p.publication_percentage AS publication_percentage,
       p.publication_rank AS publication_rank,
       c.closing_count AS closing_count,
       c.closing_percentage AS closing_percentage,
       c.closing_rank AS closing_rank,
       p.avg_publication_price_per_sqm AS avg_publication_price_per_sqm,
       c.avg_closing_price_per_sqm AS avg_closing_price_per_sqm,
       p.avg_publication_area AS avg_publication_area,
       c.avg_closing_area AS avg_closing_area,
       ROUND((c.closing_count::decimal / p.publication_count * 100)::numeric, 2) AS closed_to_published_ratio
FROM monthly_publication_stats AS p
FULL JOIN monthly_closing_stats AS c ON p.publication_month_num = c.closing_month_num
ORDER BY p.publication_month_num;