/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Журавлева Анастасия
 * Дата: 16.10.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(payer) AS all_players,
       SUM(payer) AS payer_players,
       ROUND(AVG(payer), 3) AS rate_payers
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
       SUM(u.payer) AS payer_players,
       COUNT(u.payer) AS all_players,
       SUM(u.payer)::float/COUNT(u.payer) AS rate_payers
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u USING (race_id) 
GROUP BY r.race
ORDER BY rate_payers DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
WITH all_stats AS (
    SELECT 'all_transactions' AS stats_type,
            COUNT(amount) AS count_amounts,
            SUM(amount) AS amounts,
            MIN(amount) AS min_amount,
            MAX(amount) AS max_amount,
            AVG(amount)::NUMERIC(10,2) AS avg_amount,
            PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median,
            STDDEV(amount)::NUMERIC(10,2) AS stand_dev
    FROM fantasy.events
    UNION ALL
    SELECT 'paid_transactions_only' AS stats_type,
            COUNT(amount) AS count_amounts,
            SUM(amount) AS amounts,
            MIN(amount) AS min_amount,
            MAX(amount) AS max_amount,
            AVG(amount)::NUMERIC(10,2) AS avg_amount,
            PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median,
            STDDEV(amount)::NUMERIC(10,2) AS stand_dev
    FROM fantasy.events
    WHERE amount > 0
)
SELECT * 
FROM all_stats
ORDER BY stats_type DESC;
-- 2.2: Аномальные нулевые покупки:
SELECT free_events,
       free_events::float/total_events AS rate_free_events
FROM (
    SELECT COUNT(transaction_id) FILTER (WHERE amount = 0) AS free_events,
           COUNT(transaction_id) AS total_events
    FROM fantasy.events
) AS frees;

-- какие предметы приобретали за 0 у.е
SELECT i.game_items AS item_name,
       COUNT(e.transaction_id) AS item_events
FROM fantasy.events AS e
JOIN fantasy.items AS i USING (item_code)
WHERE e.amount = 0
GROUP BY i.game_items
ORDER BY item_events DESC;

-- Игроки с высокой активностью бесплатных покупок
SELECT u.tech_nickname,
       r.race,
       COUNT(e.transaction_id) AS free_count
FROM fantasy.events AS e
JOIN fantasy.users AS u USING (id)
JOIN fantasy.race AS r USING (race_id)
WHERE e.amount = 0
GROUP BY u.tech_nickname, r.race
HAVING COUNT(e.transaction_id) > 4
ORDER BY free_count DESC;

-- 2.3: Популярные эпические предметы:
WITH payers AS (
    SELECT COUNT(*) AS total_sales,
           COUNT(DISTINCT id) AS payer_players
    FROM fantasy.events 
    WHERE amount > 0 
)
SELECT i.game_items AS item_name,
       COUNT(e.transaction_id) AS absolute_sales,
       ROUND(COUNT(e.transaction_id)::numeric/p.total_sales, 3) AS rate_sales,
       ROUND(COUNT(DISTINCT e.id)::numeric/p.payer_players, 3) AS rate_players
FROM fantasy.events AS e
JOIN fantasy.items AS i USING (item_code)
CROSS JOIN payers AS p
WHERE e.amount > 0  
GROUP BY i.game_items, p.total_sales, p.payer_players
ORDER BY rate_sales DESC, absolute_sales DESC;

--Предметы, которые не покупались 
SELECT i.game_items,
       COUNT(e.transaction_id) AS total_purchases
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e USING (item_code)
GROUP BY i.game_items
ORDER BY total_purchases;

-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH registered_players AS (
    SELECT r.race,
           COUNT(u.id) AS all_players
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u USING(race_id)
    GROUP BY r.race
),
purchase_stats AS (
    SELECT r.race,
           COUNT(DISTINCT u.id) AS paying_players_count,
           COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS real_money_payers_count,
           COUNT(e.transaction_id) AS total_transactions,
           SUM(e.amount) AS total_amount_all_players
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u USING(race_id)
    LEFT JOIN fantasy.events AS e USING(id)
    WHERE e.amount > 0
    GROUP BY r.race
)
SELECT rp.race,
       rp.all_players,
       ps.paying_players_count,
       ROUND(ps.paying_players_count::numeric / rp.all_players * 100, 2) AS rate_payer_players,
       ROUND(ps.real_money_payers_count::numeric / ps.paying_players_count * 100, 2) AS real_money_payers_ratio,
       ROUND(ps.total_transactions::numeric / ps.paying_players_count, 2) AS avg_transactions_per_user,
       ROUND(ps.total_amount_all_players::numeric / ps.total_transactions, 2) AS avg_spend_per_purchase,
       ROUND(ps.total_amount_all_players::numeric / ps.paying_players_count, 2) AS avg_total_purchase_value
FROM registered_players AS rp
JOIN purchase_stats AS ps USING(race)
ORDER BY ps.paying_players_count DESC, rp.all_players DESC;