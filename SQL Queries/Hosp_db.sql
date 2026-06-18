use hosp_database;

desc fact_bookings;

# dim_date

# add new date column
alter table dim_date add column new_date date;

# convert text date
update dim_date 
set new_date = str_to_date(date,'%d-%b-%y');

# remove old column
alter table dim_date drop column date;

# rename month column
alter table dim_date 
change column `mmm yy` Month_Year varchar(20);

# add week column
alter table dim_date add column new_week_no int;

# extract week number
update dim_date 
set new_week_no = right(`week no`,2);

# drop old week column
alter table dim_date drop column `week no`;

# rename columns
alter table dim_date change column new_date Date date;
alter table dim_date change column new_week_no Week_No int;

# Primary key
alter table dim_date
add primary key (Date);


# dim_hotels

# primary key
alter table dim_hotels
add primary key (property_id);

# modify columns
alter table dim_hotels modify property_name varchar(100);
alter table dim_hotels modify category varchar(50);
alter table dim_hotels modify city varchar(50);

# duplicate check
select property_id, count(*)
from dim_hotels
group by property_id
having count(*) > 1;



# dim_rooms

# modify columns
alter table dim_rooms modify room_id varchar(50);
alter table dim_rooms modify room_class varchar(50);

# primary key
alter table dim_rooms
add primary key (room_id);



# fact_aggregated_bookings

# add new date column
alter table fact_aggregated_bookings
add column new_checkin_date date;

# convert date
update fact_aggregated_bookings
set new_checkin_date = str_to_date(check_in_date,'%d-%b-%y');

# drop old column
alter table fact_aggregated_bookings
drop column check_in_date;

# rename column
alter table fact_aggregated_bookings
change new_checkin_date check_in_date date;

# modify datatype
alter table fact_aggregated_bookings
modify room_category varchar(10);

# composite primary key
alter table fact_aggregated_bookings
add primary key (property_id, check_in_date, room_category);

# foreign key hotels
alter table fact_aggregated_bookings
add foreign key (property_id)
references dim_hotels(property_id);

# foreign key rooms
alter table fact_aggregated_bookings
add foreign key (room_category)
references dim_rooms(room_id);

# foreign key date
alter table fact_aggregated_bookings
add foreign key (check_in_date)
references dim_date(Date);

# duplicate check
select property_id, check_in_date, room_category, count(*)
from fact_aggregated_bookings
group by property_id, check_in_date, room_category
having count(*) > 1;



# fact_bookings

alter table fact_bookings
modify check_in_date date;

alter table fact_bookings
modify checkout_date date;

# add booking date column
alter table fact_bookings add column new_booking_date date;

# convert booking date
update fact_bookings
set new_booking_date = str_to_date(booking_date,'%Y-%m-%d');

# drop old column
alter table fact_bookings drop column booking_date;

# rename column
alter table fact_bookings
change new_booking_date booking_date date;

# clean rating values
update fact_bookings
set ratings_given = null
where ratings_given = ''
or ratings_given = 'NA'
or ratings_given = 'Not Rated';

# ratings datatype
alter table fact_bookings
modify ratings_given decimal(2,1);


# convert TRUE/FALSE
update fact_bookings
set is_loyalty_member = 1
where is_loyalty_member = 'TRUE';

update fact_bookings
set is_loyalty_member = 0
where is_loyalty_member = 'FALSE';

# boolean datatype
alter table fact_bookings
modify is_loyalty_member boolean;


# fix column name
alter table fact_bookings
change column `ï»¿booking_id` booking_id text;

# modify datatype
alter table fact_bookings
modify booking_id varchar(20);

# primary key
alter table fact_bookings
add primary key (booking_id);

# foreign key hotels
alter table fact_bookings
add foreign key (property_id)
references dim_hotels(property_id);

# modify room column
alter table fact_bookings
modify room_category varchar(10);

# foreign key rooms
alter table fact_bookings
add foreign key (room_category)
references dim_rooms(room_id);

# foreign key date
alter table fact_bookings
add foreign key (check_in_date)
references dim_date(Date);



# create analysis view
create or replace view vw_hotel_booking_analysis as
select
fb.booking_id,
fb.property_id,
dh.property_name,
dh.category as hotel_category,
dh.city,
fb.check_in_date,
dd.Month_Year as check_in_month,
dd.Week_No as check_in_week,
dd.Day_Type as check_in_day_type,
fb.checkout_date,
fb.no_guests,
fb.room_category,
dr.room_id,
fb.booking_platform,
fb.ratings_given,
fb.booking_status,
fab.successful_bookings,
fab.capacity
from fact_bookings fb
left join dim_hotels dh 
on fb.property_id = dh.property_id
left join dim_date dd 
on fb.check_in_date = dd.Date
left join dim_rooms dr 
on fb.room_category = dr.room_id
left join fact_aggregated_bookings fab
on fb.property_id = fab.property_id
and fb.check_in_date = fab.check_in_date
and fb.room_category = fab.room_category;

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------

# view tables
select * from dim_date;
select * from dim_hotels;
select * from dim_rooms;
select * from fact_aggregated_bookings;
select * from fact_bookings;



-- 1. Total Revenue 
SELECT SUM(revenue_realized) AS total_revenue
FROM fact_bookings;

-- 2. Total Bookings 
SELECT COUNT(booking_id) AS total_bookings
FROM fact_bookings;

-- 3. Occupancy Rate % 
SELECT 
ROUND(SUM(successful_bookings) / SUM(capacity) * 100, 2) AS occupancy_rate_percent
FROM fact_aggregated_bookings;

-- 4. Average Customer Rating 
SELECT 
ROUND(AVG(ratings_given),2) AS average_rating
FROM fact_bookings
WHERE ratings_given IS NOT NULL;

-- 5. RevPAR – Revenue per Available Room
SELECT 
ROUND(SUM(fb.revenue_realized) / SUM(fab.capacity),2) AS revpar
FROM fact_bookings fb
JOIN fact_aggregated_bookings fab
ON fb.property_id = fab.property_id
AND fb.check_in_date = fab.check_in_date;

-- 6. Revenue by City 
SELECT 
dh.city,
SUM(fb.revenue_realized) AS total_revenue
FROM fact_bookings fb
JOIN dim_hotels dh ON fb.property_id = dh.property_id
GROUP BY dh.city
ORDER BY total_revenue DESC;

-- 7. Top 5 Properties by Revenue 
SELECT 
dh.property_name,
SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_hotels dh ON fb.property_id = dh.property_id
GROUP BY dh.property_name
ORDER BY revenue DESC
LIMIT 5;

-- 8. Monthly Revenue Trend 
SELECT 
dd.Month_Year,
SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_date dd ON fb.check_in_date = dd.Date
GROUP BY dd.Month_Year
ORDER BY dd.Month_Year;

-- 9. Booking Status Distribution (checked-out vs cancelled vs no-show)
SELECT 
booking_status,
COUNT(*) AS total_bookings
FROM fact_bookings
GROUP BY booking_status;

-- 10. Cancellation Rate % 
SELECT 
ROUND(
SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) 
/ COUNT(*) * 100,2) AS cancellation_rate_percent
FROM fact_bookings;

-- 11. Revenue by Booking Platform 
SELECT 
booking_platform,
SUM(revenue_realized) AS revenue
FROM fact_bookings
GROUP BY booking_platform
ORDER BY revenue DESC;

-- 12. Revenue by Room Class 
SELECT 
dr.room_class,
SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_rooms dr ON fb.room_category = dr.room_id
GROUP BY dr.room_class
ORDER BY revenue DESC;

-- 13. Cancellation by Room Class 
SELECT 
dr.room_class,
COUNT(*) AS cancellations
FROM fact_bookings fb
JOIN dim_rooms dr ON fb.room_category = dr.room_id
WHERE booking_status = 'Cancelled'
GROUP BY dr.room_class
ORDER BY cancellations DESC;

-- 14. Revenue by Day Type (weekday vs weekend performance)
SELECT 
dd.Day_Type,
SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_date dd ON fb.check_in_date = dd.Date
GROUP BY dd.Day_Type;

-- 15. Revenue by Booking Channel 
SELECT 
booking_channel,
SUM(revenue_realized) AS revenue
FROM fact_bookings
GROUP BY booking_channel
ORDER BY revenue DESC;
