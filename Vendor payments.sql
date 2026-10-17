create database Vendor_payments;
use vendor_payments;
create table invoice_ap(
invoice_id VARCHAR(20),
    vendor VARCHAR(100),
    invoice_date DATE,
    due_date DATE,
    payment_date DATE,
    amount_inr DECIMAL(12,2),
    payment_terms VARCHAR(30),
    days_late INT,
    discount_pct_offered DECIMAL(4,3),
    discount_captured BOOLEAN,
    discount_missed_value_inr DECIMAL(12,2)
);

select * from invoice_ap
limit 10 ;

alter table invoice_ap modify discount_captured varchar(6);
SET SQL_SAFE_UPDATES = 0;
Update invoice_ap set discount_captured = if(discount_captured = '1','TRUE','FALSE');
SET SQL_SAFE_UPDATES = 1;

select  distinct vendor from invoice_ap;
-- AVG late payment for vendors--
select vendor,avg(days_late)
from invoice_ap
group by vendor;

-- 1.--
select vendor,date_format(due_date,'%Y-%m')as monthwise,avg(days_late)as Avg_late 
from invoice_ap group by vendor,monthwise
order by monthwise;
-- 2. --
select month(due_date),round(avg(days_late),1)as avg_late,
count(*) as total_invoice
from invoice_ap
group by month(due_date)order by month(due_date) ;
-- 3. --
select min(due_date), max(due_date),
min(payment_date), max(payment_date)
from invoice_ap; 
-- 4--
SELECT 
    SUM(due_date IS NULL) AS null_due,
    SUM(payment_date IS NULL) AS null_payment,
    SUM(amount_inr IS NULL) AS null_amount
FROM invoice_ap;

-- 5. Among invoices that were both late AND missed a discount, which vendors cost us the most combined?--
select vendor,sum(discount_missed_value_inr)as total_disc_amt_lost,
SUM(case when days_late > 0  then discount_missed_value_inr else 0 END) as lost_when_late,
    SUM(case when days_late <= 0 then discount_missed_value_inr else 0 END) as lost_when_not_late
from invoice_ap
where discount_pct_offered > 0 and discount_captured ='FALSE'
group by vendor order by  total_disc_amt_lost desc;

-- 6. which vendors are we losing the most discount money to, and how often does it happen?
SELECT 
    vendor,
    SUM(discount_missed_value_inr) AS total_disc_amt_lost,
    COUNT(*) AS num_invoices_missed_discount,
    AVG(days_late) AS avg_days_late_overall
FROM invoice_ap
WHERE discount_captured = 'false'and discount_pct_offered > 0
GROUP BY vendor
ORDER BY total_disc_amt_lost DESC;

-- 7. Which vendors should Finance flag as "high risk" using a combined threshold of both
-- cost and chronic behavior  — rather than either signal alone?--
with vendor_summary as(
select vendor,count(*) as total_invoice, sum(discount_missed_value_inr) as total_disc_lost,
round(avg(days_late,1)) as avg_late_days
from invoice_ap
group by vendor)
select * ,
case when total_disc_lost >25000 and avg_late_days> 5 then'HIGH RISK' else 'LOW RISK' end  as Risk_level
from vendor_summary
order by avg_late_days desc ;

-- 8. How does each vendor's payment delay fluctuate month to month --

select vendor,date_format(due_date,'%Y-%m')as due_month,avg(days_late) as avg_late,COUNT(*) AS num_invoices
from invoice_ap
group by vendor,date_format(due_date,'%Y-%m')
order by vendor,date_format(due_date,'%Y-%m') ASc;


-- 9. For each vendor, is current month's delay better or worse than last month's — 
-- i.e., is the relationship improving or deteriorating over time?
with monthly_summary as (select vendor,
           date_format(due_date,'%Y-%m') as due_month,
           avg(days_late) as avg_late,
           count(*) as num_invoices
    from invoice_ap
    group by vendor, date_format(due_date,'%Y-%m')),
with_prev as (
    select *,
           lag(avg_late) over (partition by vendor order by due_month asc) as prev_month_avg_late
    from monthly_summary)
select vendor,due_month,num_invoices,
       round(avg_late,1) as avg_late,
       round(prev_month_avg_late,1) as prev_month_avg_late,
       round(avg_late - prev_month_avg_late,1) as change_days,
       case
           when prev_month_avg_late is null then 'First month'
           when avg_late > prev_month_avg_late then 'Worse'
           when avg_late < prev_month_avg_late then 'Better'
           else 'Same'
       end as trend
from with_prev
order by vendor, due_month;

-- 10 . What proportion of all invoices company-wide are paid late vs. early vs. 
-- on-time — is late payment the exception or the norm? —

select case when days_late > 0 then 'Late'
when days_late < 0 then 'Early'
else 'On Time' end as Payment_status,
count(*)as invoice_count,
round(count(*)*100.0 / sum(count(*))over(),2) as Perc_total
from invoice_ap
group by payment_status
order by invoice_count desc; 

-- 11. Drilling into the worst month specifically — 
-- which vendors were responsible for January's spike, so we know exactly who to talk to first?
select date_format(invoice_date,'%Y-%m') as month,
SUM(discount_missed_value_inr)as missed_amt
from invoice_ap
group by month
order by missed_amt desc;

-- 12. --
SELECT 
    vendor,
    SUM(discount_missed_value_inr) AS missed_amt,
    COUNT(*) AS num_invoices
FROM invoice_ap
WHERE DATE_FORMAT(invoice_date, '%Y-%m') = '2024-01'
GROUP BY vendor
ORDER BY missed_amt DESC;
-- why 2024-01 cause in query 11 we found that jan 2024 is the worst month losing major amt --

--  13. "When vendors miss the early-payment discount,
-- is it because our payment terms are unrealistic, or because specific vendors are slow/badly managed?--

SELECT 
    payment_terms,
    vendor,
    COUNT(*) AS total_invoices,
    SUM(CASE WHEN discount_captured = 'FALSE' THEN 1 ELSE 0 END) AS missed_count,
    ROUND(
        SUM(CASE WHEN discount_captured = 'FALSE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        1
    ) AS missed_pct
FROM invoice_ap
WHERE discount_pct_offered > 0
GROUP BY payment_terms, vendor
ORDER BY payment_terms, missed_pct DESC;

-- 14. Which vendor was the "worst offender" (highest avg days late) in each quarter,
-- and how did their rank shift quarter to quarter?--
with quarterly_summary as(
select vendor, CONCAT(YEAR(due_date), '-Q', QUARTER(due_date))as Quarter_due,
avg(days_late)as avg_late
from invoice_ap
group by vendor , Quarter_due)
select  vendor,
    quarter_due,
    avg_late,
rank()over (partition by  quarter_due order by avg_late desc ) as lateness_rank
from quarterly_summary
ORDER BY quarter_due, lateness_rank;

-- 15. Out of all the discount money we lost, which vendors account for most of it, and how many vendors do we need to fix to recover most of it?”
-- ex:“Two vendors account for 70% of the money lost to missed discounts, so start with them.”
WITH v AS (
    SELECT vendor, SUM(discount_missed_value_inr) AS lost
    FROM invoice_ap
    WHERE discount_captured = 'FALSE' AND discount_pct_offered > 0
    GROUP BY vendor
)
SELECT vendor,
       ROUND(lost, 2) AS lost_inr,
       ROUND(lost * 100 / SUM(lost) OVER (), 1) AS pct_of_total,
       ROUND(SUM(lost) OVER (ORDER BY lost DESC) * 100 / SUM(lost) OVER (), 1) AS cumulative_pct
FROM v
ORDER BY lost DESC;




