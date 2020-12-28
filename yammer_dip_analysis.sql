SELECT DATE_TRUNC('week', e.occurred_at),
       COUNT(DISTINCT e.user_id) AS weekly_active_users
  FROM tutorial.yammer_events e
 WHERE e.event_type = 'engagement'
   AND e.event_name = 'login'
 GROUP BY 1
 ORDER BY 1

 --Produces a chart which takes a dip in engagement towards the tail end.
 --I have to figure out why it takes that dip.
 --List of possible causes include:
 --		engagement type definition or tracking error, logins sustained instead of repeated,
 --  	broken product, holiday, traffic anomoly from bots, marketing event

 --First I will check the growth of the product:

 Select date_trunc( 'day', occurred_at),
       CASE WHEN event_type = 'signup_flow' then event_type ELSE NULL END AS event_type,
       COUNT(distinct user_id) as users
FROM tutorial.yammer_events
WHERE occurred_at > '2014-07-28'
AND event_type = 'signup_flow'
GROUP BY 1, 2
ORDER BY 3 DESC, 1

-- There doesn't appear to be any decrease or obvious downward trend in the growth,
--so that is likely not the culprit

--Next I will check the activity from users who are not new users
-- from less than 1 week to 10+ weeks old, in 10 classes:

SELECT date_trunc('week', z.occurred_at) AS "week",
       AVG(z.age_at_event) AS "Average Age During Week",
       COUNT(distinct CASE WHEN z.user_age > 70 then z.user_id ELSE NULL END) AS "10+ Weeks",
       COUNT(distinct CASE WHEN z.user_age < 70 AND z.user_age >= 63 then z.user_id ELSE NULL END) AS "9 weeks",
       COUNT(distinct CASE WHEN z.user_age < 63 AND z.user_age >= 56 then z.user_id ELSE NULL END) AS "8 weeks",
       COUNT(distinct CASE WHEN z.user_age < 56 AND z.user_age >= 49 then z.user_id ELSE NULL END) AS "7 weeks",
       COUNT(distinct CASE WHEN z.user_age < 49 AND z.user_age >= 42 then z.user_id ELSE NULL END) AS "6 weeks",
       COUNT(distinct CASE WHEN z.user_age < 42 AND z.user_age >= 35 then z.user_id ELSE NULL END) AS "5 weeks",
       COUNT(distinct CASE WHEN z.user_age < 35 AND z.user_age >= 28 then z.user_id ELSE NULL END) AS "4 weeks",
       COUNT(distinct CASE WHEN z.user_age < 28 AND z.user_age >= 21 then z.user_id ELSE NULL END) AS "3 weeks",
       COUNT(distinct CASE WHEN z.user_age < 21 AND z.user_age >= 14 then z.user_id ELSE NULL END) AS "2 weeks",
       COUNT(distinct CASE WHEN z.user_age < 14 AND z.user_age >= 7 then z.user_id ELSE NULL END) AS "1 weeks",
       COUNT(distinct CASE WHEN z.user_age < 7 then z.user_id ELSE NULL END) AS "Less Then 1 week"
FROM (
SELECT e.occurred_at,
       u.user_id,
       date_trunc('week', u.activated_at) AS activation_week,
       extract('day' FROM e.occurred_at - u.activated_at) AS age_at_event,
       extract('day' FROM '2014-09-01'::timestamp - u.activated_at) AS user_age
FROM tutorial.yammer_users u 
JOIN tutorial.yammer_events e 
ON e.user_id = u.user_id 
AND e.event_type = 'engagement'
AND e.event_name = 'login'
AND e.occurred_at >= '2014-05-01'
AND e.occurred_at < '2014-09-01'
WHERE u.activated_at is NOT NULL
) z
GROUP BY 1
ORDER BY 1

-- This produces a result that appears to have a downward trend in users who have been registered
--for more than 10 weeks, eliminating marketing events, and bot activity.
--Next I will look at specific devices to see if the product is malfunctioning on
--any specific interfaces:

SELECT date_trunc('week', occurred_at) AS week,
       COUNT(distinct user_id) AS active_users,
       COUNT(distinct CASE WHEN device in ('dell inspiron desktop', 'macbook pro', 'asus chromebook',
       'macbook air', 'lenovo thinkpad', 'mac mini', 'acer aspire desktop', 'acer aspire notebook',
       'dell inspirion notebook', 'hp pavilion desktop') then user_id ELSE NULL END) AS computer,
       COUNT( distinct CASE WHEN device NOT in ('dell inspiron desktop', 'macbook pro', 'asus chromebook',
       'macbook air', 'lenovo thinkpad', 'mac mini', 'acer aspire desktop', 'acer aspire notebook',
       'dell inspirion notebook', 'hp pavilion desktop') then user_id ELSE NULL END) AS mobile
FROM tutorial.yammer_events
WHERE event_type = 'engagement'
AND event_name = 'login'
GROUP BY 1
ORDER BY 1

-- The mobile line appears to take the same shape as the dip we see in overall engagement
-- maybe something has gone wrong with the mobile app interface. At this point I would
--start asking around the team working mainly with the mobile app if there have been any
--changes made around the time of the dip.
--Otherwise I might start looking for other problems.
--I will now check to see if there is a problem with the links sent out in weekly emails:

SELECT date_trunc('week', occurred_at) AS week,
      COUNT(CASE WHEN action = 'sent_reengagement_email' then user_id ELSE NULL END) AS "Sent Reengagement Email",
      COUNT(CASE WHEN action = 'email_clickthrough' then user_id ELSE NULL END) AS "Email Clickthrough",
      COUNT(CASE WHEN action = 'email_open' then user_id ELSE NULL END) AS "Email Opened",
      COUNT(CASE WHEN action = 'sent_weekly_digest' then user_id ELSE NULL END) AS "Send Weekly Digest"
FROM tutorial.yammer_emails
GROUP BY 1 
ORDER BY 1

--Here I find a trend where the email clickthroughs has a similar shape to the decreasing
--trend in engagement. Perhaps there is a problem with that in the mobile interface.
-- Below is a closer look at email open rates vs clickthrough rates:

SELECT week,
       weekly_opens/CASE WHEN weekly_emails = 0 THEN 1 ELSE weekly_emails END::FLOAT AS weekly_open_rate,
       weekly_ctr/CASE WHEN weekly_opens = 0 THEN 1 ELSE weekly_opens END::FLOAT AS weekly_ctr,
       retain_opens/CASE WHEN retain_emails = 0 THEN 1 ELSE retain_emails END::FLOAT AS retain_open_rate,
       retain_ctr/CASE WHEN retain_opens = 0 THEN 1 ELSE retain_opens END::FLOAT AS retain_ctr
  FROM (
SELECT DATE_TRUNC('week',e1.occurred_at) AS week,
       COUNT(CASE WHEN e1.action = 'sent_weekly_digest' THEN e1.user_id ELSE NULL END) AS weekly_emails,
       COUNT(CASE WHEN e1.action = 'sent_weekly_digest' THEN e2.user_id ELSE NULL END) AS weekly_opens,
       COUNT(CASE WHEN e1.action = 'sent_weekly_digest' THEN e3.user_id ELSE NULL END) AS weekly_ctr,
       COUNT(CASE WHEN e1.action = 'sent_reengagement_email' THEN e1.user_id ELSE NULL END) AS retain_emails,
       COUNT(CASE WHEN e1.action = 'sent_reengagement_email' THEN e2.user_id ELSE NULL END) AS retain_opens,
       COUNT(CASE WHEN e1.action = 'sent_reengagement_email' THEN e3.user_id ELSE NULL END) AS retain_ctr
  FROM tutorial.yammer_emails e1
  LEFT JOIN tutorial.yammer_emails e2
    ON e2.occurred_at >= e1.occurred_at
   AND e2.occurred_at < e1.occurred_at + INTERVAL '5 MINUTE'
   AND e2.user_id = e1.user_id
   AND e2.action = 'email_open'
  LEFT JOIN tutorial.yammer_emails e3
    ON e3.occurred_at >= e2.occurred_at
   AND e3.occurred_at < e2.occurred_at + INTERVAL '5 MINUTE'
   AND e3.user_id = e2.user_id
   AND e3.action = 'email_clickthrough'
 WHERE e1.occurred_at >= '2014-06-01'
   AND e1.occurred_at < '2014-09-01'
   AND e1.action IN ('sent_weekly_digest','sent_reengagement_email')
 GROUP BY 1
       ) a
 ORDER BY 1

 --this clearly shows that there is a clear problem with the clickthrough rates in relation to the emails being opened
 --combined with the potential issue in the mobile interface we may have found the problem area and can therefore focus a solution.
 

