--The question I am trying to answer here is whether or not it is worth the production and engineering teams to work on
--search functionality on the website.
--Below I will propose some hypothesis about what could be wrong with the search function,
--and/or how it might be improved based on user interaction:

--Search functions should make it easy for a user to find whatever content they are looking for
--regardless of category or date. It would be obvious if it was working if each search done led 
--the user to their goal. A successful search function n the form of data this would likely look
--like just as many searches as clickthroughs, indicating an efficient search system.  As opposed to
--users having to try several different searches to find their clickthrough. It may also appear as
--the first result in their search as opposed to the 50th if it is efficient. These are the things
--I will be looking at in order to make a suggestion to the engineering and production teams.

--First I will want to see how many user ran searches which led to clickthrough results:

SELECT sub.week AS week,
       sub.searches_autocompleted AS searches_autocompleted,
       sub.searches_run AS searches_run,
       (sub.clicked_first_result + sub.clicked_second_result + sub.clicked_third_result + sub.clicked_fourth_result +
       sub.clicked_fifth_result + sub.clicked_sixth_result + sub.clicked_seventh_result + sub.clicked_eighth_result +
       sub.clicked_ninth_result + sub.clicked_tenth_result) AS total_searches_resolved,
       
       (sub.clicked_first_result + sub.clicked_second_result + sub.clicked_third_result + sub.clicked_fourth_result +
       sub.clicked_fifth_result + sub.clicked_sixth_result + sub.clicked_seventh_result + sub.clicked_eighth_result +
       sub.clicked_ninth_result + sub.clicked_tenth_result) * 100 / sub.searches_run AS percent_resolved
FROM(
  SELECT DATE_TRUNC('week', e.occurred_at) AS week,
       COUNT(CASE WHEN e.event_name = 'search_run' then e.user_id ELSE NULL END) AS searches_run,
       COUNT(CASE WHEN e.event_name = 'search_autocomplete' then e.user_id ELSE NULL END) AS searches_autocompleted,
       COUNT(CASE WHEN e.event_name = 'search_click_result_1' then e.user_id ELSE NULL END) AS clicked_first_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_2' then e.user_id ELSE NULL END) AS clicked_second_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_3' then e.user_id ELSE NULL END) AS clicked_third_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_4' then e.user_id ELSE NULL END) AS clicked_fourth_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_5' then e.user_id ELSE NULL END) AS clicked_fifth_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_6' then e.user_id ELSE NULL END) AS clicked_sixth_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_7' then e.user_id ELSE NULL END) AS clicked_seventh_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_8' then e.user_id ELSE NULL END) AS clicked_eighth_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_9' then e.user_id ELSE NULL END) AS clicked_ninth_result,
       COUNT(CASE WHEN e.event_name = 'search_click_result_10' then e.user_id ELSE NULL END) AS clicked_tenth_result
  FROM tutorial.yammer_events e
  GROUP BY 1
  ) sub

--The subquery from the script above provides data on numbers of users who have clicked on a result based on their
--position in the results page, after their search. Compared is also how many have autocompleted searches,
--which seem  to outnumber even regular searches. A good indication of funcionality for the predictive search.
--There does appear to be an overall decrease in search clickthroughs over time, but that trend seems to match the shape
--of the engagementdip explored in the last set of queries.

--If it was up to me I might have stopped there and said the search function is fine.
--But of course thingas are more complex than that and following the MODE answer guide for this problem I found
--a more complicated script than I thought, searching for trends with much more stringent parameters.
--The rest of this exploration will be following their guide.
--I took apart the script into the subqueries so I can better understand it, can paste it whole at the end.
--Defining a session is important so we say its a string of events without more than a 10min gap logged.
--so next we will query the data to mirror that definition of a session.
--This query selects user id, and engagements logged, with a couple extra columns for the distance between
--both the last and next engagements logged, using window functions:

SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at

-- The above query brilliantly sets bounds for each engagement. Next query will use the above in a 
--subquery in order to define a session using the 10minute interval rule:

SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL

  --Adding the above to another subquery allows us to see in a more organized fashion each
  --distinct session as well as their respective start and end times:

SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2

--Joining with the events data table and tacking on the matching session numbers as well as start times:

SELECT e.*,
       session.session,
       session.session_start 
FROM tutorial.yammer_events e
LEFT JOIN(
SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2
  ) session
ON e.user_id = session.user_id 
AND e.occurred_at >= session.session_start 
AND e.occurred_at <= session_end
WHERE e.event_type = 'engagement'

--Now we are looking at the numbers of searches run, autocompleted, and results clicked on by the user sessions:

SELECT x.session_start,
       x.session,
       x.user_id,
       COUNT(CASE WHEN x.event_name = 'search_autocomplete' then x.user_id ELSE NULL END) AS autocompleted,
       COUNT(CASE WHEN x.event_name = 'search_run' then x.user_id ELSE NULL END) AS runs,
       COUNT(CASE WHEN x.event_name LIKE 'search_click_%' then user_id ELSE NULL END) AS clicks
FROM(
SELECT e.*,
       session.session,
       session.session_start 
FROM tutorial.yammer_events e
LEFT JOIN(
SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2
  ) session
ON e.user_id = session.user_id 
AND e.occurred_at >= session.session_start 
AND e.occurred_at <= session_end
WHERE e.event_type = 'engagement'
) x 
GROUP BY 1, 2, 3

--To put it all together is to query the above to check on how many sessions had autocompleted searches
--and run searches altogether answering the questions of if people even use the search function;

SELECT DATE_TRUNC('week', z.session_start) AS week,
       COUNT(*) AS sessions,
       COUNT(CASE WHEN z.autocompletes > 0 then z.session ELSE NULL END) AS with_autocompletes,
       COUNT(CASE WHEN z.runs > 0 then z.session ELSE NULL END) AS with_runs
FROM (
SELECT x.session_start,
       x.session,
       x.user_id,
       COUNT(CASE WHEN x.event_name = 'search_autocomplete' then x.user_id ELSE NULL END) AS autocompletes,
       COUNT(CASE WHEN x.event_name = 'search_run' then x.user_id ELSE NULL END) AS runs,
       COUNT(CASE WHEN x.event_name LIKE 'search_click_%' then user_id ELSE NULL END) AS clicks
FROM(
SELECT e.*,
       session.session,
       session.session_start 
FROM tutorial.yammer_events e
LEFT JOIN(
SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2
  ) session
ON e.user_id = session.user_id 
AND e.occurred_at >= session.session_start 
AND e.occurred_at <= session_end
WHERE e.event_type = 'engagement'
) x 
GROUP BY 1, 2, 3
) z
GROUP BY 1
ORDER BY 1

-- I added in a line that gives the percent of searches per session both with and without autocomplete.
--which indicate about 1/3 of users on average use the search function at all:

SELECT a.week,
       a.sessions,
       a.with_autocompletes,
       a.with_runs,
       ((a.with_autocompletes + a.with_runs) * 100 / a.sessions) AS "% searches per session"
FROM(
SELECT DATE_TRUNC('week', z.session_start) AS week,
       COUNT(*) AS sessions,
       COUNT(CASE WHEN z.autocompletes > 0 then z.session ELSE NULL END) AS with_autocompletes,
       COUNT(CASE WHEN z.runs > 0 then z.session ELSE NULL END) AS with_runs
FROM (
SELECT x.session_start,
       x.session,
       x.user_id,
       COUNT(CASE WHEN x.event_name = 'search_autocomplete' then x.user_id ELSE NULL END) AS autocompletes,
       COUNT(CASE WHEN x.event_name = 'search_run' then x.user_id ELSE NULL END) AS runs,
       COUNT(CASE WHEN x.event_name LIKE 'search_click_%' then user_id ELSE NULL END) AS clicks
FROM(
SELECT e.*,
       session.session,
       session.session_start 
FROM tutorial.yammer_events e
LEFT JOIN(
SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2
  ) session
ON e.user_id = session.user_id 
AND e.occurred_at >= session.session_start 
AND e.occurred_at <= session_end
WHERE e.event_type = 'engagement'
) x 
GROUP BY 1, 2, 3
) z
GROUP BY 1
ORDER BY 1
) a

--Mode has conducted a different script for the same thing, leaving the percent as a float:

SELECT DATE_TRUNC('week', z.session_start) AS week,
       COUNT(*) AS sessions,
       COUNT(CASE WHEN z.autocompletes > 0 then z.session ELSE NULL END)/COUNT(*)::FLOAT AS with_autocompletes,
       COUNT(CASE WHEN z.runs > 0 then z.session ELSE NULL END)/COUNT(*)::FLOAT AS with_runs
FROM (
SELECT x.session_start,
       x.session,
       x.user_id,
       COUNT(CASE WHEN x.event_name = 'search_autocomplete' then x.user_id ELSE NULL END) AS autocompletes,
       COUNT(CASE WHEN x.event_name = 'search_run' then x.user_id ELSE NULL END) AS runs,
       COUNT(CASE WHEN x.event_name LIKE 'search_click_%' then user_id ELSE NULL END) AS clicks
FROM(
SELECT e.*,
       session.session,
       session.session_start 
FROM tutorial.yammer_events e
LEFT JOIN(
SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2
  ) session
ON e.user_id = session.user_id 
AND e.occurred_at >= session.session_start 
AND e.occurred_at <= session_end
WHERE e.event_type = 'engagement'
) x 
GROUP BY 1, 2, 3
) z
GROUP BY 1
ORDER BY 1

--Furthermore the amount of results clicked are grossly disproportioned to the amount of searchwes run
--Indicating that yes, the full search function needs some work:

SELECT clicks,
       COUNT(*) AS sessions
FROM(
SELECT x.session_start,
       x.session,
       x.user_id,
       COUNT(CASE WHEN x.event_name = 'search_autocomplete' THEN x.user_id ELSE NULL END) AS autocompletes,
       COUNT(CASE WHEN x.event_name = 'search_run' THEN x.user_id ELSE NULL END) AS runs,
       COUNT(CASE WHEN x.event_name LIKE 'search_click_%' THEN x.user_id ELSE NULL END) AS clicks
FROM(
SELECT e.*,
       session.session,
       session.session_start 
FROM tutorial.yammer_events e
LEFT JOIN(
SELECT user_id,
       session,
       MIN(occurred_at) AS session_start,
       MAX(occurred_at) AS session_end
FROM(
SELECT bounds.*,
       CASE WHEN last_event >= interval '10 minute' then id 
            WHEN last_event is NULL then id 
            ELSE LAG(id, 1) OVER(partition BY user_id ORDER BY occurred_at) END AS session
FROM(
SELECT user_id,
       event_type,
       event_name,
       occurred_at,
       occurred_at - LAG(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) AS last_event,
       LEAD(occurred_at, 1) OVER (partition BY user_id ORDER BY occurred_at) - occurred_at AS next_event,
       ROW_NUMBER() OVER () AS id
FROM tutorial.yammer_events e 
WHERE e.event_type = 'engagement'
ORDER BY user_id, occurred_at
    ) bounds
WHERE last_event >= interval '10 minute'
  OR next_event >= interval '10 minute'
  OR last_event is NULL 
  OR next_event is NULL
    ) final
GROUP BY 1, 2
  ) session
ON e.user_id = session.user_id 
AND e.occurred_at >= session.session_start 
AND e.occurred_at <= session_end
WHERE e.event_type = 'engagement'
) x
GROUP BY 1, 2, 3
) y 
WHERE runs > 0
GROUP BY 1
ORDER BY 1

--The following query also shows that when search results are clicked they are relatively uniform, 
--indicating that the search isn't typically efficient at providing the right results first:

SELECT TRIM('search_click_result_' FROM event_name)::INT AS search_result,
       COUNT(*) AS clicks
FROM tutorial.yammer_events
WHERE event_name LIKE 'search_click_%'
GROUP BY 1
ORDER BY 1
LIMIT 100

--In conclusion the autocompelted search function is working better than the full search function,
--and the full search function needs some attention in providing efficient results to the users based on 
--the combined information above. Thank you data for the insights and thank you Mode for the Guidance and access to the SQL server.