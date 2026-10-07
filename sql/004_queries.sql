-- ============================================================================
-- 004_queries.sql
-- Description: Core queries serving the five primary application actions (A1-A5)
--              and history listing (H1), using deterministic fixture IDs from 002.
--              Each query is commented with its associated action and index.
-- ============================================================================
-- Running this file leaves the data unchanged.

BEGIN;

-- ============================================================================
-- Q1 (Action A1: Request a trip)
-- ============================================================================

-- Step 1: Check if the calling rider already has an active trip
-- Index used: trip_one_active_per_rider on trip (rider_id) WHERE status IN ('requested', 'accepted', 'in_progress')
SELECT
    id,
    status,
    pickup_lat,
    pickup_lng,
    dropoff_lat,
    dropoff_lng,
    estimated_fare_minor,
    currency,
    created_at
FROM trip
WHERE rider_id = '10000000-0000-0000-0000-000000000003'
  AND status IN ('requested', 'accepted', 'in_progress');

-- Step 2: Insert the newly requested trip
INSERT INTO trip (
    id,
    rider_id,
    status,
    pickup_lat,
    pickup_lng,
    dropoff_lat,
    dropoff_lng,
    estimated_fare_minor,
    currency,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    '10000000-0000-0000-0000-000000000003',
    'requested',
    6.447400,
    3.390300,
    6.524400,
    3.379200,
    420000,
    'NGN',
    now(),
    now()
);

-- ============================================================================
-- Q2 (Action A2: Accept a trip)
-- ============================================================================

-- Step 1: List open requests for drivers, oldest first, with cursor pagination
-- Index used: trip_open_requests_idx on trip (created_at, id) WHERE status = 'requested'
SELECT
    id,
    pickup_lat,
    pickup_lng,
    dropoff_lat,
    dropoff_lng,
    estimated_fare_minor,
    currency,
    created_at
FROM trip
WHERE status = 'requested'
  AND (created_at, id) > ('2026-10-06 00:00:00+00'::timestamptz, '00000000-0000-0000-0000-000000000000'::uuid)
ORDER BY created_at ASC, id ASC
LIMIT 20;

-- Step 2: Conditional update to accept trip T3 by driver D2 with vehicle V2
-- Index used: trip_pkey (Primary key on id)
UPDATE trip
SET status = 'accepted',
    driver_id = '20000000-0000-0000-0000-000000000002',
    vehicle_id = '30000000-0000-0000-0000-000000000002',
    driver_name_snapshot = (SELECT full_name FROM driver WHERE id = '20000000-0000-0000-0000-000000000002'),
    vehicle_plate_snapshot = (SELECT plate_number FROM vehicle WHERE id = '30000000-0000-0000-0000-000000000002'),
    accepted_at = now()
WHERE id = '40000000-0000-0000-0000-000000000003'
  AND status = 'requested';

-- ============================================================================
-- Q3 (Action A3: Complete a trip)
-- ============================================================================

-- Complete in-progress trip T1, fixing final fare to estimated fare
-- Index used: trip_pkey (Primary key on id)
UPDATE trip
SET status = 'completed',
    fare_minor = estimated_fare_minor,
    completed_at = now()
WHERE id = '40000000-0000-0000-0000-000000000001'
  AND status = 'in_progress';

-- ============================================================================
-- Q4 (Action A4: Pay for a trip)
-- ============================================================================

-- Step 1: Insert payment attempt using the trip's verified fare and currency
-- Constraints / Indexes used: payment_matches_trip_fare_fk, payment_idempotency_key_key
INSERT INTO payment (
    id,
    trip_id,
    amount_minor,
    currency,
    status,
    provider,
    provider_reference,
    idempotency_key,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    t.id,
    t.fare_minor,
    t.currency,
    'pending',
    'paystack',
    NULL,
    'idem-key-prod-t2-999',
    now(),
    now()
FROM trip t
WHERE t.id = '40000000-0000-0000-0000-000000000002';

-- Step 2: Lookup payment by idempotency key
-- Index used: payment_idempotency_key_key on payment (idempotency_key)
SELECT
    id,
    trip_id,
    amount_minor,
    currency,
    status,
    provider,
    provider_reference,
    idempotency_key,
    created_at
FROM payment
WHERE idempotency_key = 'idem-key-prod-t2-999';

-- ============================================================================
-- Q5 (Action A5: Rate the driver and compute driver rating summary)
-- ============================================================================

-- Step 1: Insert rating for completed trip T2
-- Constraints / Indexes used: rating_one_per_trip, rating_trip_is_completed_fk
INSERT INTO rating (
    id,
    trip_id,
    trip_status,
    score,
    comment,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    '40000000-0000-0000-0000-000000000002',
    'completed',
    5,
    'Smooth driving and on time arrival.',
    now(),
    now()
);

-- Step 2: Read driver rating summary (average score and total count)
-- Indexes used: trip_driver_history_idx on trip (driver_id, created_at DESC, id DESC)
--               and rating_one_per_trip on rating (trip_id)
SELECT
    t.driver_id,
    round(avg(r.score)::numeric, 2) AS average_score,
    count(r.id)                     AS rating_count
FROM trip t
JOIN rating r ON r.trip_id = t.id
WHERE t.driver_id = '20000000-0000-0000-0000-000000000002'
GROUP BY t.driver_id;

-- ============================================================================
-- H1: Rider trip history
-- ============================================================================

-- Paged query: newest first, 20 rows, stable cursor on (created_at, id)
-- Index used: trip_rider_history_idx on trip (rider_id, created_at DESC, id DESC)
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
WHERE rider_id = '10000000-0000-0000-0000-000000000001'
  AND (created_at, id) < ('2026-10-06 12:30:00+00'::timestamptz, '40000000-0000-0000-0000-000000000001'::uuid)
ORDER BY created_at DESC, id DESC
LIMIT 20;

ROLLBACK;
