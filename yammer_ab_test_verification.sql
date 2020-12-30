-- A/B Testing a new product feature which has shown an over 50% usage increase from the previous version, is uncommon.
--I am tasked with exploring the data to determine what has happened here and if there could be any other explanations for such an explosion in usage of that feature.
--Hypothesis:
--1. Data tracking on the new beta feature could have duplicates somewhere - for this I would have to check the data logs in comparison to what has empiracally been done.
--2. Biases in the treatment groups could have an effect on the dramatic increase - for this I would have to directly compare the historical habits of the two groups.
--3. The a/b test might have an error. - for this I would have to redo and replicate the test myself using the same data to verify the results.

--Starting with the SQL query done for the A/B experiment initially:
SELECT c.experiment,
       c.experiment_group,
       c.users,
       c.total_treated_users,
       ROUND(c.users/c.total_treated_users,4) AS treatment_percent,
       c.total,
       ROUND(c.average,4)::FLOAT AS average,
       ROUND(c.average - c.control_average,4) AS rate_difference,
       ROUND((c.average - c.control_average)/c.control_average,4) AS rate_lift,
       ROUND(c.stdev,4) AS stdev,
       ROUND((c.average - c.control_average) /
          SQRT((c.variance/c.users) + (c.control_variance/c.control_users))
        ,4) AS t_stat,
       (1 - COALESCE(nd.value,1))*2 AS p_value
  FROM (
SELECT *,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.users ELSE NULL END) OVER () AS control_users,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.average ELSE NULL END) OVER () AS control_average,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.total ELSE NULL END) OVER () AS control_total,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.variance ELSE NULL END) OVER () AS control_variance,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.stdev ELSE NULL END) OVER () AS control_stdev,
       SUM(b.users) OVER () AS total_treated_users
  FROM (
SELECT a.experiment,
       a.experiment_group,
       COUNT(a.user_id) AS users,
       AVG(a.metric) AS average,
       SUM(a.metric) AS total,
       STDDEV(a.metric) AS stdev,
       VARIANCE(a.metric) AS variance
  FROM (
SELECT ex.experiment,
       ex.experiment_group,
       ex.occurred_at AS treatment_start,
       u.user_id,
       u.activated_at,
       COUNT(CASE WHEN e.event_name = 'send_message' THEN e.user_id ELSE NULL END) AS metric
  FROM (SELECT user_id,
               experiment,
               experiment_group,
               occurred_at
          FROM tutorial.yammer_experiments
         WHERE experiment = 'publisher_update'
       ) ex
  JOIN tutorial.yammer_users u
    ON u.user_id = ex.user_id
  JOIN tutorial.yammer_events e
    ON e.user_id = ex.user_id
   AND e.occurred_at >= ex.occurred_at
   AND e.occurred_at < '2014-07-01'
   AND e.event_type = 'engagement'
 GROUP BY 1,2,3,4,5
       ) a
 GROUP BY 1,2
       ) b
       ) c
  LEFT JOIN benn.normal_distribution nd
    ON nd.score = ABS(ROUND((c.average - c.control_average)/SQRT((c.variance/c.users) + (c.control_variance/c.control_users)),3))

 -- Following MODE's recommendation to crossreferenceother metrics I changed the event_name from
 --"send_message" to "login" to see how A/B for logins (which is the metric Yammer typically uses) between 
 -- the two groups relates to the experiment results: 
 SELECT c.experiment,
       c.experiment_group,
       c.users,
       c.total_treated_users,
       ROUND(c.users/c.total_treated_users,4) AS treatment_percent,
       c.total,
       ROUND(c.average,4)::FLOAT AS average,
       ROUND(c.average - c.control_average,4) AS rate_difference,
       ROUND((c.average - c.control_average)/c.control_average,4) AS rate_lift,
       ROUND(c.stdev,4) AS stdev,
       ROUND((c.average - c.control_average) /
          SQRT((c.variance/c.users) + (c.control_variance/c.control_users))
        ,4) AS t_stat,
       (1 - COALESCE(nd.value,1))*2 AS p_value
  FROM (
SELECT *,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.users ELSE NULL END) OVER () AS control_users,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.average ELSE NULL END) OVER () AS control_average,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.total ELSE NULL END) OVER () AS control_total,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.variance ELSE NULL END) OVER () AS control_variance,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.stdev ELSE NULL END) OVER () AS control_stdev,
       SUM(b.users) OVER () AS total_treated_users
  FROM (
SELECT a.experiment,
       a.experiment_group,
       COUNT(a.user_id) AS users,
       AVG(a.metric) AS average,
       SUM(a.metric) AS total,
       STDDEV(a.metric) AS stdev,
       VARIANCE(a.metric) AS variance
  FROM (
SELECT ex.experiment,
       ex.experiment_group,
       ex.occurred_at AS treatment_start,
       u.user_id,
       u.activated_at,
       COUNT(CASE WHEN e.event_name = 'login' THEN e.user_id ELSE NULL END) AS metric
  FROM (SELECT user_id,
               experiment,
               experiment_group,
               occurred_at
          FROM tutorial.yammer_experiments
         WHERE experiment = 'publisher_update'
       ) ex
  JOIN tutorial.yammer_users u
    ON u.user_id = ex.user_id
  JOIN tutorial.yammer_events e
    ON e.user_id = ex.user_id
   AND e.occurred_at >= ex.occurred_at
   AND e.occurred_at < '2014-07-01'
   AND e.event_type = 'engagement'
 GROUP BY 1,2,3,4,5
       ) a
 GROUP BY 1,2
       ) b
       ) c
  LEFT JOIN benn.normal_distribution nd
    ON nd.score = ABS(ROUND((c.average - c.control_average)/SQRT((c.variance/c.users) + (c.control_variance/c.control_users)),3))

--Running this produces values thatshow the test groups logins also up compared to the control group logins.
--Just to make sure that the counts of days logged in are consistent as opposed to several logins in one sitting
--(which may indicate a problem) I ran a query to chart daily login rates with the AB parameters:

SELECT c.experiment,
       c.experiment_group,
       c.users,
       c.total_treated_users,
       ROUND(c.users/c.total_treated_users,4) AS treatment_percent,
       c.total,
       ROUND(c.average,4)::FLOAT AS average,
       ROUND(c.average - c.control_average,4) AS rate_difference,
       ROUND((c.average - c.control_average)/c.control_average,4) AS rate_lift,
       ROUND(c.stdev,4) AS stdev,
       ROUND((c.average - c.control_average) /
          SQRT((c.variance/c.users) + (c.control_variance/c.control_users))
        ,4) AS t_stat,
       (1 - COALESCE(nd.value,1))*2 AS p_value
  FROM (
SELECT *,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.users ELSE NULL END) OVER () AS control_users,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.average ELSE NULL END) OVER () AS control_average,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.total ELSE NULL END) OVER () AS control_total,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.variance ELSE NULL END) OVER () AS control_variance,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.stdev ELSE NULL END) OVER () AS control_stdev,
       SUM(b.users) OVER () AS total_treated_users
  FROM (
SELECT a.experiment,
       a.experiment_group,
       COUNT(a.user_id) AS users,
       AVG(a.metric) AS average,
       SUM(a.metric) AS total,
       STDDEV(a.metric) AS stdev,
       VARIANCE(a.metric) AS variance
  FROM (
SELECT ex.experiment,
       ex.experiment_group,
       ex.occurred_at AS treatment_start,
       u.user_id,
       u.activated_at,
       COUNT(DISTINCT DATE_TRUNC('day', e.occurred_at)) AS metric
  FROM (SELECT user_id,
               experiment,
               experiment_group,
               occurred_at
          FROM tutorial.yammer_experiments
         WHERE experiment = 'publisher_update'
       ) ex
  JOIN tutorial.yammer_users u
    ON u.user_id = ex.user_id
  JOIN tutorial.yammer_events e
    ON e.user_id = ex.user_id
   AND e.occurred_at >= ex.occurred_at
   AND e.occurred_at < '2014-07-01'
   AND e.event_type = 'engagement'
 GROUP BY 1,2,3,4,5
       ) a
 GROUP BY 1,2
       ) b
       ) c
  LEFT JOIN benn.normal_distribution nd
    ON nd.score = ABS(ROUND((c.average - c.control_average)/SQRT((c.variance/c.users) + (c.control_variance/c.control_users)),3))

    --All that looks good as far as the ethics on AB testing is concerned. Now let's look at the possibility that the groups assigned to their different treatments
    --were biased somehow, starting with how users were assigned to the testing groups:

    SELECT DATE_TRUNC('month', u.activated_at) AS month_activated,
       COUNT(CASE WHEN e.experiment_group = 'control_group' THEN u.user_id ELSE NULL END) AS control_users,
       COUNT(CASE WHEN e.experiment_group = 'test_group' THEN u.user_id ELSE NULL END) AS test_users
FROM tutorial.yammer_experiments e 
JOIN tutorial.yammer_users u 
  ON u.user_id = e.user_id 
GROUP BY 1
ORDER BY 1

--this produces a chart that shows new users disproportiontely assigned to the control group thus possibly skewing the AB test results.
--Below is a query repeating the AB tests but excluding newer users:

SELECT c.experiment,
       c.experiment_group,
       c.users,
       c.total_treated_users,
       Round(c.users/c.total_treated_users, 4) AS treatment_percent,
       c.total,
       ROUND(c.average, 4)::FLOAT AS average,
       ROUND(c.average - c.control_average, 4) AS rate_diff,
       ROUND((c.average - c.control_average)/c.control_average, 4) AS rate_lift,
       ROUND(c.stdev, 4) AS stdev,
       ROUND((c.average - c.control_average)/ SQRT((c.variance/c.users) + (c.control_variance/c.control_users)), 4) AS t_stat,
       (1 - COALESCE(nd.value, 1)) * 2 AS p_value
FROM(
SELECT *,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.users ELSE NULL END) OVER() AS control_users,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.average ELSE NULL END) OVER() AS control_average,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.total ELSE NULL END) OVER() AS control_total,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.variance ELSE NULL END) OVER() AS control_variance,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.stdev ELSE NULL END) OVER() AS control_stdev,
       SUM(b.users) OVER() AS total_treated_users
FROM(
SELECT a.experiment,
       a.experiment_group,
       COUNT(a.user_id) AS users,
       AVG(a.metric) AS average,
       SUM(a.metric) AS total,
       STDDEV(a.metric) AS stdev,
       VARIANCE(a.metric) AS variance
FROM(
SELECT ex.experiment,
       ex.experiment_group,
       ex.occurred_at AS treatment_start,
       u.user_id,
       u.activated_at,
       COUNT(CASE WHEN e.event_name = 'send_message' then e.user_id ELSE NULL END) AS metric
FROM (
SELECT user_id,
       experiment,
       experiment_group,
       occurred_at
FROM tutorial.yammer_experiments
WHERE experiment = 'publisher_update'
    ) ex
JOIN tutorial.yammer_users u 
  ON u.user_id = ex.user_id
  AND u.activated_at < '2014-06-01'
JOIN tutorial.yammer_events e 
  ON e.user_id = ex.user_id 
  AND e.occurred_at >= ex.occurred_at 
  AND e.occurred_at < '2014-07-01'
  AND e.event_type = 'engagement'
GROUP BY 1, 2, 3, 4, 5
    ) a 
GROUP BY 1, 2
    ) b
    ) c
LEFT JOIN benn.normal_distribution nd 
ON nd.score = ABS(ROUND((c.average - c.control_average)/SQRT((c.variance/c.users) + (c.control_variance/c.control_users)), 3))

--This produces a result that looks a bit more reasonable but from here will look at the difference between devicese used:

SELECT c.experiment,
       c.experiment_group,
       c.users,
       c.total_treated_users,
       Round(c.users/c.total_treated_users, 4) AS treatment_percent,
       c.total,
       ROUND(c.average, 4)::FLOAT AS average,
       ROUND(c.average - c.control_average, 4) AS rate_diff,
       ROUND((c.average - c.control_average)/c.control_average, 4) AS rate_lift,
       ROUND(c.stdev, 4) AS stdev,
       ROUND((c.average - c.control_average)/ SQRT((c.variance/c.users) + (c.control_variance/c.control_users)), 4) AS t_stat,
       (1 - COALESCE(nd.value, 1)) * 2 AS p_value
FROM(
SELECT *,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.users ELSE NULL END) OVER() AS control_users,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.average ELSE NULL END) OVER() AS control_average,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.total ELSE NULL END) OVER() AS control_total,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.variance ELSE NULL END) OVER() AS control_variance,
       MAX(CASE WHEN b.experiment_group = 'control_group' THEN b.stdev ELSE NULL END) OVER() AS control_stdev,
       SUM(b.users) OVER() AS total_treated_users
FROM(
SELECT a.experiment,
       a.experiment_group,
       COUNT(a.user_id) AS users,
       AVG(a.metric) AS average,
       SUM(a.metric) AS total,
       STDDEV(a.metric) AS stdev,
       VARIANCE(a.metric) AS variance
FROM(
SELECT ex.experiment,
       ex.experiment_group,
       ex.occurred_at AS treatment_start,
       u.user_id,
       u.activated_at,
       COUNT(CASE WHEN e.event_name = 'send_message' then e.user_id ELSE NULL END) AS metric
FROM (
SELECT user_id,
       experiment,
       experiment_group,
       occurred_at
FROM tutorial.yammer_experiments
WHERE experiment = 'publisher_update'
    ) ex
JOIN tutorial.yammer_users u 
  ON u.user_id = ex.user_id
  AND u.activated_at < '2014-06-01'
JOIN tutorial.yammer_events e 
  ON e.user_id = ex.user_id 
  AND e.occurred_at >= ex.occurred_at 
  AND e.occurred_at < '2014-07-01'
  AND e.event_type = 'engagement'
GROUP BY 1, 2, 3, 4, 5
    ) a 
GROUP BY 1, 2
    ) b
    ) c
LEFT JOIN benn.normal_distribution nd 
ON nd.score = ABS(ROUND((c.average - c.control_average)/SQRT((c.variance/c.users) + (c.control_variance/c.control_users)), 3))

-- There are many other parameters to look at but overall the results of the A/B test appears to endure.