-- ============================================================================
-- 006_invalid_inserts.sql
-- Description: Demonstrates model enforcement against invalid state transitions
--              and constraint violations.
--
-- NOTE: ON_ERROR_STOP is intentionally NOT enabled so all tests execute.
--       Each invalid attempt is followed by a valid counterpart rolled back
--       inside BEGIN ... ROLLBACK blocks to verify positive enforcement.
-- ============================================================================

\unset ON_ERROR_STOP

\echo '======================================================================'
\echo 'TEST 1 (Required): Insert second active trip for rider R1'
\echo 'Context: Rider R1 already has trip T1 in_progress.'
\echo 'Expected Rejection: trip_one_active_per_rider'
\echo '======================================================================'

-- 1. Invalid: Rider R1 requests a new trip while T1 is in_progress
INSERT INTO trip (
    id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
    estimated_fare_minor, currency, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '10000000-0000-0000-0000-000000000001',
    'requested',
    6.447400, 3.390300, 6.524400, 3.379200, 350000, 'NGN', now(), now()
);

-- Valid counterpart: Rider R3 (who has no active trip) requests a trip
BEGIN;
INSERT INTO trip (
    id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
    estimated_fare_minor, currency, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '10000000-0000-0000-0000-000000000003',
    'requested',
    6.447400, 3.390300, 6.524400, 3.379200, 350000, 'NGN', now(), now()
);
ROLLBACK;


\echo '======================================================================'
\echo 'TEST 2 (Required): Insert rating for non-completed trip T3'
\echo 'Context: Trip T3 is currently in requested state.'
\echo 'Expected Rejection: rating_trip_is_completed_fk'
\echo '======================================================================'

-- 2. Invalid: Rating a requested trip (T3)
INSERT INTO rating (
    id, trip_id, trip_status, score, comment, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '40000000-0000-0000-0000-000000000003',
    'completed',
    5,
    'Great ride!',
    now(),
    now()
);

-- Valid counterpart: Rating completed trip T2
BEGIN;
INSERT INTO rating (
    id, trip_id, trip_status, score, comment, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '40000000-0000-0000-0000-000000000002',
    'completed',
    5,
    'Great ride!',
    now(),
    now()
);
ROLLBACK;


\echo '======================================================================'
\echo 'TEST 3 (Required): Insert payment with mismatched amount for T2'
\echo 'Context: Trip T2 fare is 350000 NGN. Payment specifies 100 NGN.'
\echo 'Expected Rejection: payment_matches_trip_fare_fk'
\echo '======================================================================'

-- 3. Invalid: Payment amount (100) does not match trip fare (350000)
INSERT INTO payment (
    id, trip_id, amount_minor, currency, status, provider,
    provider_reference, idempotency_key, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '40000000-0000-0000-0000-000000000002',
    100,
    'NGN',
    'pending',
    'paystack',
    NULL,
    'idem-invalid-amt-001',
    now(),
    now()
);

-- Valid counterpart: Payment amount matches trip fare exactly
BEGIN;
INSERT INTO payment (
    id, trip_id, amount_minor, currency, status, provider,
    provider_reference, idempotency_key, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '40000000-0000-0000-0000-000000000002',
    350000,
    'NGN',
    'pending',
    'paystack',
    NULL,
    'idem-valid-amt-001',
    now(),
    now()
);
ROLLBACK;


\echo '======================================================================'
\echo 'TEST 4 (Bonus): Cancel an in-progress trip T1 directly'
\echo 'Context: In-progress trips cannot be cancelled (must complete at dropoff).'
\echo 'Expected Rejection: trip_status_transition_trg'
\echo '======================================================================'

-- 4. Invalid: in_progress to cancelled
UPDATE trip
SET status = 'cancelled',
    cancelled_by = 'rider',
    cancelled_at = now()
WHERE id = '40000000-0000-0000-0000-000000000001';

-- Valid counterpart: in_progress moves forward to completed
BEGIN;
UPDATE trip
SET status = 'completed',
    fare_minor = estimated_fare_minor,
    completed_at = now()
WHERE id = '40000000-0000-0000-0000-000000000001';
ROLLBACK;


\echo '======================================================================'
\echo 'TEST 5 (Bonus): Assign vehicle belonging to another driver'
\echo 'Context: Trip T5 is assigned to driver D4. Assign vehicle V1 (owned by D1).'
\echo 'Expected Rejection: trip_vehicle_belongs_to_driver_fk'
\echo '======================================================================'

-- 5. Invalid: Vehicle V1 belongs to Driver D1, but T5 driver is Driver D4
UPDATE trip
SET vehicle_id = '30000000-0000-0000-0000-000000000001'
WHERE id = '40000000-0000-0000-0000-000000000005';

-- Valid counterpart: Vehicle V4 belongs to Driver D4
BEGIN;
UPDATE trip
SET vehicle_id = '30000000-0000-0000-0000-000000000004'
WHERE id = '40000000-0000-0000-0000-000000000005';
ROLLBACK;
