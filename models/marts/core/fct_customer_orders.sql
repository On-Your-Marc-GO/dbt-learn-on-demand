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

    select * from {{ ref('stg_jaffle_shop__customers') }}

),

paid_orders as (

    select * from {{ ref('int_orders') }}

),


final as (
    select
        paid_orders.order_id,
        paid_orders.customer_id,
        paid_orders.order_placed_at,
        paid_orders.order_status,
        paid_orders.total_amount_paid,
        paid_orders.payment_finalized_date,
        customers.customer_first_name,
        customers.customer_last_name,

        -- Sales Transaction Sequence
        row_number() over (
            order by paid_orders.order_placed_at, paid_orders.order_id
            ) as transaction_seq,

        -- Customer Sales Sequence
        row_number() over (
            partition by paid_orders.customer_id 
            order by paid_orders.order_placed_at, paid_orders.order_id
            ) as customer_sales_seq,

        -- New vs Returning Customer
        case 
            when (
            rank() over (
                partition by paid_orders.customer_id
                order by paid_orders.order_placed_at, paid_orders.order_id
                ) = 1
            ) then 'new'
        else 'return' end as nvsr,

        -- Customer Lifetime Value calc
        sum(paid_orders.total_amount_paid) over (
            partition by paid_orders.customer_id
            order by paid_orders.order_placed_at, paid_orders.order_id
        ) as customer_lifetime_value,


        -- First Day of Sale
        first_value(paid_orders.order_placed_at) over (
            partition by paid_orders.customer_id
            order by paid_orders.order_placed_at, paid_orders.order_id
        ) as fdos
    from paid_orders
    left join customers on paid_orders.customer_id = customers.customer_id
)

select * from final