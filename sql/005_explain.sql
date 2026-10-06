-- ============================================================================
-- 005_explain.sql
-- Description: Executes EXPLAIN (ANALYZE, BUFFERS) on heavy read queries H1 and
--              Q5 rating summary against dynamically selected high-volume actors.
--
-- NOTE: SET enable_seqscan = off is deliberately NOT used.
-- ============================================================================

-- ============================================================================
-- 1. IDENTIFY HEAVY-HITTERS VIA PSQL VARIABLES
-- ============================================================================

-- Identify the rider with the highest trip volume
SELECT rider_id AS busiest_rider_id
FROM trip
GROUP BY rider_id
ORDER BY count(*) DESC
LIMIT 1
\gset

-- Identify the driver with the highest number of rated completed trips
SELECT t.driver_id AS busiest_driver_id
FROM trip t
JOIN rating r ON r.trip_id = t.id
GROUP BY t.driver_id
ORDER BY count(r.id) DESC
LIMIT 1
\gset

\echo '----------------------------------------------------------------------'
\echo 'Query Execution Plan 1: H1 Rider Trip History'
\echo 'Expected Index: trip_rider_history_idx on trip (rider_id, created_at DESC, id DESC)'
\echo '----------------------------------------------------------------------'

-- ============================================================================
-- 2. EXPLAIN PLAN FOR H1 (RIDER TRIP HISTORY)
-- ============================================================================
-- Index expected: trip_rider_history_idx
-- Should perform an Index Scan or Bitmap Index Scan using rider_id and created_at/id
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    id,
    status,
    pickup_lat,
    pickup_lng,
    dropoff_lat,
    dropoff_lng,
    estimated_fare_minor,
    fare_minor,
    currency,
    driver_name_snapshot,
    vehicle_plate_snapshot,
    accepted_at,
    started_at,
    completed_at,
    cancelled_at,
    created_at
FROM trip
WHERE rider_id = :'busiest_rider_id'
ORDER BY created_at DESC, id DESC
LIMIT 20;

\echo '----------------------------------------------------------------------'
\echo 'Query Execution Plan 2: Q5 Driver Rating Summary (Average & Count)'
\echo 'Expected Indexes: trip_driver_history_idx on trip(driver_id, ...) '
\echo '                  and rating_one_per_trip on rating(trip_id)'
\echo '----------------------------------------------------------------------'

-- ============================================================================
-- 3. EXPLAIN PLAN FOR Q5 (DRIVER RATING AGGREGATION)
-- ============================================================================
-- Indexes expected: trip_driver_history_idx on trip filtering on driver_id,
--                   joined with rating using rating_one_per_trip or PK on rating(id/trip_id)
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    t.driver_id,
    round(avg(r.score)::numeric, 2) AS average_score,
    count(r.id)                     AS rating_count
FROM trip t
JOIN rating r ON r.trip_id = t.id
WHERE t.driver_id = :'busiest_driver_id'
GROUP BY t.driver_id;
