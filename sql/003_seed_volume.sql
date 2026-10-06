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
INSERT INTO rider (id, full_name, phone, email, created_at, updated_at)
SELECT
    gen_random_uuid(),
    'Rider ' || i,
    '+23480' || lpad(i::text, 8, '0'),
    'rider_' || i || '@volumemail.com',
    '2026-06-01 00:00:00+00'::timestamptz + (i * interval '1 minute'),
    '2026-06-01 00:00:00+00'::timestamptz + (i * interval '1 minute')
FROM generate_series(1, 2000) AS i;

-- Temporary indexed lookup table for riders
CREATE TEMP TABLE tmp_riders ON COMMIT DROP AS
SELECT id, row_number() OVER (ORDER BY created_at) AS rnum
FROM rider;
CREATE INDEX ON tmp_riders (rnum);

-- ============================================================================
-- 2. BULK DRIVERS (300 rows)
-- ============================================================================
INSERT INTO driver (id, full_name, phone, email, licence_number, created_at, updated_at)
SELECT
    gen_random_uuid(),
    'Driver ' || i,
    '+23481' || lpad(i::text, 8, '0'),
    'driver_' || i || '@volumedriver.com',
    'LIC-VOL-' || lpad(i::text, 6, '0'),
    '2026-05-01 00:00:00+00'::timestamptz + (i * interval '2 minutes'),
    '2026-05-01 00:00:00+00'::timestamptz + (i * interval '2 minutes')
FROM generate_series(1, 300) AS i;

CREATE TEMP TABLE tmp_drivers ON COMMIT DROP AS
SELECT id, full_name, row_number() OVER (ORDER BY created_at) AS rnum
FROM driver;
CREATE INDEX ON tmp_drivers (rnum);

-- ============================================================================
-- 3. BULK VEHICLES (400 rows)
-- ============================================================================
INSERT INTO vehicle (id, driver_id, plate_number, make, model, colour, year, created_at, updated_at)
SELECT
    gen_random_uuid(),
    d.id,
    'LAG-' || lpad(i::text, 5, '0') || 'ZZ',
    (ARRAY['Toyota', 'Honda', 'Hyundai', 'Kia', 'Nissan'])[1 + (i % 5)],
    (ARRAY['Corolla', 'Civic', 'Elantra', 'Rio', 'Sentra'])[1 + (i % 5)],
    (ARRAY['Silver', 'Black', 'White', 'Blue', 'Grey'])[1 + (i % 5)],
    (2015 + (i % 9))::smallint,
    '2026-05-15 00:00:00+00'::timestamptz + (i * interval '3 minutes'),
    '2026-05-15 00:00:00+00'::timestamptz + (i * interval '3 minutes')
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
    id, rider_id, driver_id, vehicle_id, status,
    pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
    estimated_fare_minor, fare_minor, currency,
    driver_name_snapshot, vehicle_plate_snapshot,
    accepted_at, started_at, completed_at,
    created_at, updated_at
)
SELECT
    gen_random_uuid(),
    r.id,
    v.driver_id,
    v.id,
    'completed'::trip_status,
    6.400000 + ((i % 500) * 0.000200),
    3.300000 + (((i * 3) % 500) * 0.000200),
    6.500000 + (((i * 7) % 500) * 0.000200),
    3.400000 + (((i * 11) % 500) * 0.000200),
    200000 + ((i % 800) * 1000),
    200000 + ((i % 800) * 1000),
    'NGN',
    v.driver_name,
    v.plate_number,
    t_req + interval '2 minutes',
    t_req + interval '10 minutes',
    t_req + interval '45 minutes',
    t_req,
    t_req + interval '45 minutes'
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
    id, rider_id, status,
    pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
    estimated_fare_minor, currency,
    cancelled_by, cancelled_at,
    created_at, updated_at
)
SELECT
    gen_random_uuid(),
    r.id,
    'cancelled'::trip_status,
    6.410000 + ((i % 400) * 0.000200),
    3.310000 + (((i * 5) % 400) * 0.000200),
    6.510000 + (((i * 9) % 400) * 0.000200),
    3.410000 + (((i * 13) % 400) * 0.000200),
    250000 + ((i % 500) * 1000),
    'NGN',
    'rider'::cancelled_by,
    t_req + interval '4 minutes',
    t_req,
    t_req + interval '4 minutes'
FROM generate_series(1, 2000) AS i
CROSS JOIN LATERAL (
    SELECT '2026-08-01 00:00:00+00'::timestamptz + (i * interval '30 minutes') AS t_req,
           1 + ((i * 31) % (SELECT count(*) FROM tmp_riders))::int AS rider_idx
) lat
JOIN tmp_riders r ON r.rnum = lat.rider_idx;

-- 1,000 Cancelled Trips (after acceptance)
INSERT INTO trip (
    id, rider_id, driver_id, vehicle_id, status,
    pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
    estimated_fare_minor, currency,
    driver_name_snapshot, vehicle_plate_snapshot,
    accepted_at, cancelled_by, cancelled_at,
    created_at, updated_at
)
SELECT
    gen_random_uuid(),
    r.id,
    v.driver_id,
    v.id,
    'cancelled'::trip_status,
    6.420000 + ((i % 400) * 0.000200),
    3.320000 + (((i * 7) % 400) * 0.000200),
    6.520000 + (((i * 11) % 400) * 0.000200),
    3.420000 + (((i * 17) % 400) * 0.000200),
    280000 + ((i % 400) * 1000),
    'NGN',
    (ARRAY['driver'::cancelled_by, 'rider'::cancelled_by])[1 + (i % 2)],
    v.driver_name,
    v.plate_number,
    t_req + interval '3 minutes',
    t_req + interval '8 minutes',
    t_req,
    t_req + interval '8 minutes'
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
    id, trip_id, amount_minor, currency, status,
    provider, provider_reference, idempotency_key,
    created_at, updated_at
)
SELECT
    gen_random_uuid(),
    t.id,
    t.fare_minor,
    t.currency,
    'succeeded'::payment_status,
    'paystack',
    'pstk_vol_' || lpad(row_number() OVER ()::text, 9, '0'),
    'idem_vol_' || lpad(row_number() OVER ()::text, 9, '0'),
    t.completed_at + interval '1 minute',
    t.completed_at + interval '1 minute'
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
    id, trip_id, trip_status, score, comment,
    created_at, updated_at
)
SELECT
    gen_random_uuid(),
    t.id,
    'completed'::trip_status,
    (1 + (abs(hashtext(t.id::text)) % 5))::smallint,
    'Bulk trip feedback rating score',
    t.completed_at + interval '10 minutes',
    t.completed_at + interval '10 minutes'
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
