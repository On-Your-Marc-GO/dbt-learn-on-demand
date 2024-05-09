{{
    config(
        materialized='table'
    )
}}

-- Best Practice for organization
-- 1. Import CTE's
-- 2. Logical CTE's
-- 3. Final CTE
-- 4. select statement

with customers as (

    select * from {{ source('jaffle_shop', 'customers') }}

),

orders as (

    select * from {{ source('jaffle_shop', 'orders') }}

),

payments as (

    select * from {{ source('stripe', 'payment') }}

),

completed_payments as (
    select 
        orderid as order_id, 
        max(created) as payment_finalized_date, 
        sum(amount) / 100.0 as total_amount_paid
    from payments
    where status <> 'fail'
    group by 1
),

paid_orders as (
    select 
        orders.id as order_id,
        orders.user_id as customer_id,
        orders.order_date as order_placed_at,
        orders.status as order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        c.first_name as customer_first_name,
        c.last_name as customer_last_name
    from orders as orders
    left join completed_payments as p on orders.ID = p.order_id
    left join customers as c on orders.user_id = c.id
),

customer_orders as (
    select 
        c.id as customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(orders.id) as number_of_orders
    from customers c 
    left join orders as orders on orders.user_id = c.id 
    group by 1
),

final as (
    select
        p.*,
        -- Sales Transaction Sequence
        row_number() over (order by p.order_id) as transaction_seq,
        -- Customer Sales Sequence
        row_number() over (partition by customer_id order by p.order_id) as customer_sales_seq,
        -- New vs Returning Customer
        case when c.first_order_date = p.order_placed_at
        then 'new'
        else 'return' end as nvsr,
        -- Customer Lifetime Value calc
        sum(total_amount_paid) over (
            partition by p.customer_id
            order by p.order_placed_at
        ) as customer_lifetime_value,
        -- First Day of Sale
        c.first_order_date as fdos
    from paid_orders p
    left join customer_orders as c using (customer_id)
    order by order_id
)

select * from final