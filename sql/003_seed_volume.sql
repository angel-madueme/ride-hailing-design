-- ============================================================================
-- 003_seed_volume.sql
-- Description: Bulk data seed for PostgreSQL 18 query planner and EXPLAIN plans.
--              Generates ~2,000 riders, 300 drivers, 400 vehicles, and 60,000 trips
--              with realistic power-law skew for query indexing demonstrations.
--
-- NOTE: User triggers (set_updated_at and status transition guards) are disabled
--       ONLY during this bulk transaction to allow direct set-based generation,
--       and are immediately re-enabled before COMMIT. Constraints and foreign
--       keys remain active throughout the load.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Disable user triggers for high-throughput batch loading
ALTER TABLE rider   DISABLE TRIGGER USER;
ALTER TABLE driver  DISABLE TRIGGER USER;
ALTER TABLE vehicle DISABLE TRIGGER USER;
ALTER TABLE trip    DISABLE TRIGGER USER;
ALTER TABLE payment DISABLE TRIGGER USER;
ALTER TABLE rating  DISABLE TRIGGER USER;

-- ============================================================================
-- 1. BULK RIDERS (~2,000 rows)
-- ============================================================================
INSERT INTO rider (
    id,
    full_name,
    phone,
    email,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                                   -- id
    ('Rider ' || i)::text,                                               -- full_name
    ('+23480' || lpad(i::text, 8, '0'))::text,                           -- phone
    ('rider_' || i || '@volumemail.com')::text,                          -- email
    ('2026-06-01 00:00:00+00'::timestamptz + (i * interval '1 minute')), -- created_at
    ('2026-06-01 00:00:00+00'::timestamptz + (i * interval '1 minute'))  -- updated_at
FROM generate_series(1, 2000) AS i;

-- Temporary indexed lookup table for riders
CREATE TEMP TABLE tmp_riders ON COMMIT DROP AS
SELECT id, row_number() OVER (ORDER BY created_at) AS rnum
FROM rider;
CREATE INDEX ON tmp_riders (rnum);

-- ============================================================================
-- 2. BULK DRIVERS (300 rows)
-- ============================================================================
INSERT INTO driver (
    id,
    full_name,
    phone,
    email,
    licence_number,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                                    -- id
    ('Driver ' || i)::text,                                               -- full_name
    ('+23481' || lpad(i::text, 8, '0'))::text,                            -- phone
    ('driver_' || i || '@volumedriver.com')::text,                        -- email
    ('LIC-VOL-' || lpad(i::text, 6, '0'))::text,                          -- licence_number
    ('2026-05-01 00:00:00+00'::timestamptz + (i * interval '2 minutes')), -- created_at
    ('2026-05-01 00:00:00+00'::timestamptz + (i * interval '2 minutes'))  -- updated_at
FROM generate_series(1, 300) AS i;

CREATE TEMP TABLE tmp_drivers ON COMMIT DROP AS
SELECT id, full_name, row_number() OVER (ORDER BY created_at) AS rnum
FROM driver;
CREATE INDEX ON tmp_drivers (rnum);

-- ============================================================================
-- 3. BULK VEHICLES (400 rows)
-- ============================================================================
INSERT INTO vehicle (
    id,
    driver_id,
    plate_number,
    make,
    model,
    colour,
    year,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                                    -- id
    d.id,                                                                 -- driver_id
    ('LAG-' || lpad(i::text, 5, '0') || 'ZZ')::text,                      -- plate_number
    ((ARRAY['Toyota', 'Honda', 'Hyundai', 'Kia', 'Nissan'])[1 + (i % 5)])::text, -- make
    ((ARRAY['Corolla', 'Civic', 'Elantra', 'Rio', 'Sentra'])[1 + (i % 5)])::text, -- model
    ((ARRAY['Silver', 'Black', 'White', 'Blue', 'Grey'])[1 + (i % 5)])::text,    -- colour
    (2015 + (i % 9))::smallint,                                           -- year
    ('2026-05-15 00:00:00+00'::timestamptz + (i * interval '3 minutes')), -- created_at
    ('2026-05-15 00:00:00+00'::timestamptz + (i * interval '3 minutes'))  -- updated_at
FROM generate_series(1, 400) AS i
JOIN tmp_drivers d ON d.rnum = 1 + ((i - 1) % 300);

CREATE TEMP TABLE tmp_vehicles ON COMMIT DROP AS
SELECT v.id, v.driver_id, d.full_name AS driver_name, v.plate_number, row_number() OVER (ORDER BY v.created_at) AS rnum
FROM vehicle v
JOIN driver d ON d.id = v.driver_id;
CREATE INDEX ON tmp_vehicles (rnum);

-- ============================================================================
-- 4. BULK TRIPS (60,000 rows with skewed distribution)
-- ============================================================================

-- 57,000 Completed Trips
INSERT INTO trip (
    id,
    rider_id,
    driver_id,
    vehicle_id,
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
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                        -- id
    r.id,                                                     -- rider_id
    v.driver_id,                                              -- driver_id
    v.id,                                                     -- vehicle_id
    'completed'::trip_status,                                 -- status
    (6.400000 + ((i % 500) * 0.000200))::numeric(9, 6),       -- pickup_lat
    (3.300000 + (((i * 3) % 500) * 0.000200))::numeric(9, 6), -- pickup_lng
    (6.500000 + (((i * 7) % 500) * 0.000200))::numeric(9, 6), -- dropoff_lat
    (3.400000 + (((i * 11) % 500) * 0.000200))::numeric(9, 6),-- dropoff_lng
    (200000 + ((i % 800) * 1000))::bigint,                    -- estimated_fare_minor
    (200000 + ((i % 800) * 1000))::bigint,                    -- fare_minor
    'NGN'::char(3),                                           -- currency
    v.driver_name::text,                                      -- driver_name_snapshot
    v.plate_number::text,                                     -- vehicle_plate_snapshot
    (t_req + interval '2 minutes')::timestamptz,              -- accepted_at
    (t_req + interval '10 minutes')::timestamptz,             -- started_at
    (t_req + interval '45 minutes')::timestamptz,             -- completed_at
    t_req::timestamptz,                                       -- created_at
    (t_req + interval '45 minutes')::timestamptz              -- updated_at
FROM generate_series(1, 57000) AS i
CROSS JOIN LATERAL (
    SELECT '2026-07-01 00:00:00+00'::timestamptz + (i * interval '75 seconds') AS t_req,
           1 + floor(power(((i * 17) % 1000) / 1000.0, 3.0) * (SELECT count(*) - 1 FROM tmp_riders))::int AS rider_idx,
           1 + floor(power(((i * 23) % 1000) / 1000.0, 2.5) * (SELECT count(*) - 1 FROM tmp_vehicles))::int AS vehicle_idx
) lat
JOIN tmp_riders r ON r.rnum = lat.rider_idx
JOIN tmp_vehicles v ON v.rnum = lat.vehicle_idx;

-- 2,000 Cancelled Trips (before acceptance)
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
    cancelled_by,
    cancelled_at,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                        -- id
    r.id,                                                     -- rider_id
    'cancelled'::trip_status,                                 -- status
    (6.410000 + ((i % 400) * 0.000200))::numeric(9, 6),       -- pickup_lat
    (3.310000 + (((i * 5) % 400) * 0.000200))::numeric(9, 6), -- pickup_lng
    (6.510000 + (((i * 9) % 400) * 0.000200))::numeric(9, 6), -- dropoff_lat
    (3.410000 + (((i * 13) % 400) * 0.000200))::numeric(9, 6),-- dropoff_lng
    (250000 + ((i % 500) * 1000))::bigint,                    -- estimated_fare_minor
    'NGN'::char(3),                                           -- currency
    'rider'::cancelled_by,                                    -- cancelled_by
    (t_req + interval '4 minutes')::timestamptz,              -- cancelled_at
    t_req::timestamptz,                                       -- created_at
    (t_req + interval '4 minutes')::timestamptz               -- updated_at
FROM generate_series(1, 2000) AS i
CROSS JOIN LATERAL (
    SELECT '2026-08-01 00:00:00+00'::timestamptz + (i * interval '30 minutes') AS t_req,
           1 + ((i * 31) % (SELECT count(*) FROM tmp_riders))::int AS rider_idx
) lat
JOIN tmp_riders r ON r.rnum = lat.rider_idx;

-- 1,000 Cancelled Trips (after acceptance)
INSERT INTO trip (
    id,
    rider_id,
    driver_id,
    vehicle_id,
    status,
    pickup_lat,
    pickup_lng,
    dropoff_lat,
    dropoff_lng,
    estimated_fare_minor,
    currency,
    driver_name_snapshot,
    vehicle_plate_snapshot,
    accepted_at,
    cancelled_by,
    cancelled_at,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                                            -- id
    r.id,                                                                         -- rider_id
    v.driver_id,                                                                  -- driver_id
    v.id,                                                                         -- vehicle_id
    'cancelled'::trip_status,                                                     -- status
    (6.420000 + ((i % 400) * 0.000200))::numeric(9, 6),                           -- pickup_lat
    (3.320000 + (((i * 7) % 400) * 0.000200))::numeric(9, 6),                     -- pickup_lng
    (6.520000 + (((i * 11) % 400) * 0.000200))::numeric(9, 6),                    -- dropoff_lat
    (3.420000 + (((i * 17) % 400) * 0.000200))::numeric(9, 6),                    -- dropoff_lng
    (280000 + ((i % 400) * 1000))::bigint,                                        -- estimated_fare_minor
    'NGN'::char(3),                                                               -- currency
    v.driver_name::text,                                                          -- driver_name_snapshot
    v.plate_number::text,                                                         -- vehicle_plate_snapshot
    (t_req + interval '3 minutes')::timestamptz,                                  -- accepted_at
    ((ARRAY['driver'::cancelled_by, 'rider'::cancelled_by])[1 + (i % 2)])::cancelled_by, -- cancelled_by
    (t_req + interval '8 minutes')::timestamptz,                                  -- cancelled_at
    t_req::timestamptz,                                                           -- created_at
    (t_req + interval '8 minutes')::timestamptz                                   -- updated_at
FROM generate_series(1, 1000) AS i
CROSS JOIN LATERAL (
    SELECT '2026-08-15 00:00:00+00'::timestamptz + (i * interval '45 minutes') AS t_req,
           1 + ((i * 41) % (SELECT count(*) FROM tmp_riders))::int AS rider_idx,
           1 + ((i * 43) % (SELECT count(*) FROM tmp_vehicles))::int AS vehicle_idx
) lat
JOIN tmp_riders r ON r.rnum = lat.rider_idx
JOIN tmp_vehicles v ON v.rnum = lat.vehicle_idx;

-- ============================================================================
-- 5. BULK PAYMENTS (for all newly completed trips)
-- ============================================================================
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
    gen_random_uuid(),                                                        -- id
    t.id,                                                                     -- trip_id
    t.fare_minor,                                                             -- amount_minor
    t.currency,                                                               -- currency
    'succeeded'::payment_status,                                              -- status
    'paystack'::text,                                                         -- provider
    ('pstk_vol_' || lpad(row_number() OVER ()::text, 9, '0'))::text,          -- provider_reference
    ('idem_vol_' || lpad(row_number() OVER ()::text, 9, '0'))::text,          -- idempotency_key
    (t.completed_at + interval '1 minute')::timestamptz,                      -- created_at
    (t.completed_at + interval '1 minute')::timestamptz                       -- updated_at
FROM trip t
WHERE t.status = 'completed'
  AND t.id NOT IN (
      '40000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000002',
      '40000000-0000-0000-0000-000000000004',
      '40000000-0000-0000-0000-000000000006',
      '40000000-0000-0000-0000-000000000007',
      '40000000-0000-0000-0000-000000000008',
      '40000000-0000-0000-0000-000000000012'
  );

-- ============================================================================
-- 6. BULK RATINGS (~60% of completed trips)
-- ============================================================================
INSERT INTO rating (
    id,
    trip_id,
    trip_status,
    score,
    comment,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                                        -- id
    t.id,                                                                     -- trip_id
    'completed'::trip_status,                                                 -- trip_status
    (1 + (abs(hashtext(t.id::text)) % 5))::smallint,                          -- score
    'Bulk trip feedback rating score'::text,                                  -- comment
    (t.completed_at + interval '10 minutes')::timestamptz,                     -- created_at
    (t.completed_at + interval '10 minutes')::timestamptz                      -- updated_at
FROM trip t
WHERE t.status = 'completed'
  AND (abs(hashtext(t.id::text)) % 10) < 6
  AND t.id NOT IN (
      '40000000-0000-0000-0000-000000000004',
      '40000000-0000-0000-0000-000000000006',
      '40000000-0000-0000-0000-000000000008'
  );

-- Re-enable user triggers
ALTER TABLE rider   ENABLE TRIGGER USER;
ALTER TABLE driver  ENABLE TRIGGER USER;
ALTER TABLE vehicle ENABLE TRIGGER USER;
ALTER TABLE trip    ENABLE TRIGGER USER;
ALTER TABLE payment ENABLE TRIGGER USER;
ALTER TABLE rating  ENABLE TRIGGER USER;

-- ============================================================================
-- 7. VOLUME SANITY CHECK ASSERTIONS
-- ============================================================================
DO $$
DECLARE
    v_riders    bigint;
    v_drivers   bigint;
    v_vehicles  bigint;
    v_trips     bigint;
    v_unpaid    bigint;
BEGIN
    SELECT count(*) INTO v_riders FROM rider;
    SELECT count(*) INTO v_drivers FROM driver;
    SELECT count(*) INTO v_vehicles FROM vehicle;
    SELECT count(*) INTO v_trips FROM trip;

    IF v_riders < 2000 THEN
        RAISE EXCEPTION 'Volume check failed: expected at least 2000 riders, found %', v_riders;
    END IF;

    IF v_drivers < 300 THEN
        RAISE EXCEPTION 'Volume check failed: expected at least 300 drivers, found %', v_drivers;
    END IF;

    IF v_vehicles < 400 THEN
        RAISE EXCEPTION 'Volume check failed: expected at least 400 vehicles, found %', v_vehicles;
    END IF;

    IF v_trips < 58000 THEN
        RAISE EXCEPTION 'Volume check failed: expected at least 58000 trips, found %', v_trips;
    END IF;

    -- Verify no completed bulk trip is missing a payment (excluding 002 seed fixtures)
    SELECT count(*) INTO v_unpaid
    FROM trip t
    LEFT JOIN payment p ON p.trip_id = t.id
    WHERE t.status = 'completed'
      AND p.id IS NULL
      AND t.id NOT IN (
          '40000000-0000-0000-0000-000000000001',
          '40000000-0000-0000-0000-000000000002',
          '40000000-0000-0000-0000-000000000003',
          '40000000-0000-0000-0000-000000000004',
          '40000000-0000-0000-0000-000000000005',
          '40000000-0000-0000-0000-000000000006',
          '40000000-0000-0000-0000-000000000007',
          '40000000-0000-0000-0000-000000000008',
          '40000000-0000-0000-0000-000000000009',
          '40000000-0000-0000-0000-000000000010',
          '40000000-0000-0000-0000-000000000011',
          '40000000-0000-0000-0000-000000000012'
      );

    IF v_unpaid > 0 THEN
        RAISE EXCEPTION 'Volume check failed: found % completed bulk trips without payments', v_unpaid;
    END IF;
END;
$$;

COMMIT;

-- Analyze all tables to refresh query planner statistics
ANALYZE rider;
ANALYZE driver;
ANALYZE vehicle;
ANALYZE trip;
ANALYZE payment;
ANALYZE rating;
ANALYZE trip_status_transition;
ANALYZE payment_status_transition;
