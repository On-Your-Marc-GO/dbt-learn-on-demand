with

source as (

    select * from {{ source('stripe', 'payment') }}

),

staged as (

    select 

        id as payment_id,
        orderid as order_id,
        paymentmethod as payment_method,
        status,

        -- Amount is stored in cents, convert to dollars
        amount / 100 as amount,
        created as created_at
    
    from source
)

select * from staged