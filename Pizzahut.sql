create database pizzahut;

use pizzahut;

create table pizzas(
pizza_id varchar(20) primary key,
pizza_type_id varchar(20),
size varchar(2),
price decimal(4, 2)
);


alter table pizzas modify column size varchar(10);

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\pizza_sales\\pizzas.csv' into table pizzas
fields terminated by ','
enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

create table order_details(
order_details_id int not null primary key,
order_id int not null,
pizza_id text not null,
quantity int not null
);

drop table order_details;

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\pizza_sales\\order_details.csv' into table order_details
fields terminated by ','
enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

-- Retrieve the total number of orders placed.

select count(order_id) AS total_orders from orders;

-- Calculate the total revenue generated from pizza sales.

SELECT 
    ROUND(SUM(order_details.quantity * pizzas.price),
            2) AS total_sales
FROM
    order_details
        JOIN
    pizzas ON pizzas.pizza_id = order_details.pizza_id
;

-- Identify the highest-priced pizza.

select pizza_types.name, pizzas.price
from pizza_types join pizzas
on pizza_types.pizza_type_id = pizzas.pizza_type_id
order by pizzas.price
desc limit 1;

-- total of orders by numbers of pizzas per order.

select quantity, count(order_details_id)
from order_details group by quantity;

-- Identify the most common pizza size ordered.

SELECT 
    pizzas.size,
    COUNT(order_details.order_details_id) AS order_count
FROM
    pizzas
        JOIN
    order_details ON pizzas.pizza_id = order_details.pizza_id
GROUP BY pizzas.size
ORDER BY order_count DESC
LIMIT 1;


-- List the top 5 most ordered pizza types along with their quantities.

SELECT 
    pizza_types.name, SUM(order_details.quantity) AS quantity
FROM
    pizza_types
        JOIN
    pizzas ON pizza_types.pizza_type_id = pizzas.pizza_type_id
        JOIN
    order_details ON order_details.pizza_id = pizzas.pizza_id
GROUP BY pizza_types.name
ORDER BY quantity DESC
LIMIT 5;

-- Join the necessary tables to find the total quantity of each pizza category ordered.

SELECT 
    pizza_types.category,
    SUM(order_details.quantity) AS quantity
FROM
    pizza_types
        JOIN
    pizzas ON pizza_types.pizza_type_id = pizzas.pizza_type_id
        JOIN
    order_details ON order_details.pizza_id = pizzas.pizza_id
GROUP BY pizza_types.category
ORDER BY quantity DESC;

-- Determine the distribution of orders by hour of the day.

SELECT 
    HOUR(`time`) AS hour, COUNT(order_id) AS order_count
FROM
    orders
GROUP BY HOUR(`time`)
ORDER BY order_count DESC;

-- Join relevant tables to find the category-wise distribution of pizzas.

SELECT 
    category, COUNT(name)
FROM
    pizza_types
GROUP BY category;


-- Group the orders by date and calculate the average number of pizzas ordered per day.


SELECT 
    ROUND(AVG(quantity), 0) AS AVG_PIZZA_ORDERED_PER_DAY
FROM
    (SELECT 
        orders.date, SUM(order_details.quantity) AS quantity
    FROM
        orders
    JOIN order_details ON orders.order_id = order_details.order_id
    GROUP BY orders.date) AS order_quantity;


-- Determine the top 3 most ordered pizza types based on revenue

select pizza_types.name,
sum(order_details.quantity * pizzas.price) as revenue
from pizza_types join pizzas
on pizzas.pizza_type_id = pizza_types.pizza_type_id
join order_details
on order_details.pizza_id = pizzas.pizza_id
group by pizza_types.name order by revenue desc limit 3;


-- Calculate the percentage contribution of each pizza type to total revenue.

SELECT 
    pizza_types.category,
    round(SUM(order_details.quantity * pizzas.price) / (SELECT 
            ROUND(SUM(order_details.quantity * pizzas.price),
                        2) AS total_sales
        FROM
            order_details
                JOIN
            pizzas ON pizzas.pizza_id = order_details.pizza_id) * 100, 2) AS revenue
FROM
    pizza_types
        JOIN
    pizzas ON pizza_types.pizza_type_id = pizzas.pizza_type_id
        JOIN
    order_details ON order_details.pizza_id = pizzas.pizza_id
GROUP BY pizza_types.category
ORDER BY revenue DESC;

-- Analyze the cumulative revenue generated over time.

select `date`, revenue,
sum(revenue) over (order by `date`) as cum_revenue
from
(select orders.date,
sum(order_details.quantity * pizzas.price) as revenue
from order_details join pizzas
on order_details.pizza_id = pizzas.pizza_id
join orders
on orders.order_id = order_details.order_id
group by orders.date) as sales;

-- Determine the top 3 most ordered pizza types based on revenue for each pizza category.

select name, revenue from
(select category, name, revenue,
rank() over(partition by category order by revenue desc) as rn
from 
(select pizza_types.category, pizza_types.name,
sum((order_details.quantity) * pizzas.price) as revenue
from pizza_types join pizzas
on pizza_types.pizza_type_id = pizzas.pizza_type_id
join order_details
on order_details.pizza_id = pizzas.pizza_id
group by pizza_types.category, pizza_types.name) as a) as b
where rn <=3;


-- Calculate revenue grow or contract month-over-month

WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(orders.date, '%Y-%m') AS sales_month,
        ROUND(SUM(order_details.quantity * pizzas.price), 2) AS current_month_revenue
    FROM order_details 
    JOIN pizzas 
        ON order_details.pizza_id = pizzas.pizza_id
    JOIN orders 
        ON orders.order_id = order_details.order_id
    GROUP BY DATE_FORMAT(orders.date, '%Y-%m')
),
revenue_comparison AS (
    SELECT 
        sales_month,
        current_month_revenue,
        LAG(current_month_revenue) OVER (ORDER BY sales_month) AS previous_month_revenue
    FROM monthly_revenue
)
SELECT 
    sales_month,
    current_month_revenue,
    previous_month_revenue,
    ROUND(
        ((current_month_revenue - previous_month_revenue) / previous_month_revenue) * 100, 
        2
    ) AS percentage_change
FROM revenue_comparison;


