-- ============================================================================
-- 002_seed_small.sql
-- Description: Seeds a small, readable dataset using fixed deterministic UUIDs.
--              Every trip is created in 'requested' state and transitioned
--              via UPDATE statements to exercise transition guards and shape checks.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ============================================================================
-- 1. RIDERS (5 rows)
-- ============================================================================
INSERT INTO rider (id, full_name, phone, email, created_at, updated_at) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Adaeze Okonkwo',     '+2348011111111', 'adaeze@example.com',     '2026-10-01 08:00:00+00', '2026-10-01 08:00:00+00'),
    ('10000000-0000-0000-0000-000000000002', 'Babatunde Adeleke',  '+2348022222222', 'babatunde@example.com',  '2026-10-01 08:15:00+00', '2026-10-01 08:15:00+00'),
    ('10000000-0000-0000-0000-000000000003', 'Chidinma Eze',       '+2348033333333', 'chidinma@example.com',   '2026-10-01 08:30:00+00', '2026-10-01 08:30:00+00'),
    ('10000000-0000-0000-0000-000000000004', 'Damilola Bakare',    '+2348044444444', 'damilola@example.com',   '2026-10-01 08:45:00+00', '2026-10-01 08:45:00+00'),
    ('10000000-0000-0000-0000-000000000005', 'Emeka Nwosu',        '+2348055555555', 'emeka@example.com',      '2026-10-01 09:00:00+00', '2026-10-01 09:00:00+00');

-- ============================================================================
-- 2. DRIVERS (4 rows)
-- ============================================================================
INSERT INTO driver (id, full_name, phone, email, licence_number, created_at, updated_at) VALUES
    ('20000000-0000-0000-0000-000000000001', 'Folake Johnson',  '+2348066666666', 'folake@driver.example.com',  'LIC-LAG-001', '2026-09-15 07:00:00+00', '2026-09-15 07:00:00+00'),
    ('20000000-0000-0000-0000-000000000002', 'Gbolahan Salami', '+2348077777777', 'gbolahan@driver.example.com', 'LIC-LAG-002', '2026-09-15 07:30:00+00', '2026-09-15 07:30:00+00'),
    ('20000000-0000-0000-0000-000000000003', 'Hassan Ibrahim',  '+2348088888888', 'hassan@driver.example.com',   'LIC-LAG-003', '2026-09-15 08:00:00+00', '2026-09-15 08:00:00+00'),
    ('20000000-0000-0000-0000-000000000004', 'Ifeanyi Okafor',  '+2348099999999', 'ifeanyi@driver.example.com',  'LIC-LAG-004', '2026-09-15 08:30:00+00', '2026-09-15 08:30:00+00');

-- ============================================================================
-- 3. VEHICLES (5 rows)
-- ============================================================================
INSERT INTO vehicle (id, driver_id, plate_number, make, model, colour, year, created_at, updated_at) VALUES
    ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'KJA-101AA', 'Toyota',  'Corolla', 'Silver', 2018, '2026-09-16 09:00:00+00', '2026-09-16 09:00:00+00'),
    ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'LSR-202BB', 'Honda',   'Civic',   'Black',  2020, '2026-09-16 09:30:00+00', '2026-09-16 09:30:00+00'),
    ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'APP-303CC', 'Hyundai', 'Elantra', 'Blue',   2019, '2026-09-16 10:00:00+00', '2026-09-16 10:00:00+00'),
    ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', 'EKY-404DD', 'Toyota',  'Camry',   'White',  2021, '2026-09-16 10:30:00+00', '2026-09-16 10:30:00+00'),
    ('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000001', 'BDG-505EE', 'Kia',     'Rio',     'Red',    2017, '2026-09-16 11:00:00+00', '2026-09-16 11:00:00+00');

-- ============================================================================
-- 4. TRIPS (12 rows created in historical sequence)
-- ============================================================================

-- Historic Trips (T6, T7, T8, T9, T10, T11, T12)
-- ----------------------------------------------------------------------------
-- T6: Completed historical trip for R1 with D2
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'requested', 6.425000, 3.420000, 6.450000, 3.400000, 280000, 'NGN', '2026-10-02 08:00:00+00', '2026-10-02 08:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000002', vehicle_id = '30000000-0000-0000-0000-000000000002',
    driver_name_snapshot = 'Gbolahan Salami', vehicle_plate_snapshot = 'LSR-202BB', accepted_at = '2026-10-02 08:02:00+00', updated_at = '2026-10-02 08:02:00+00'
WHERE id = '40000000-0000-0000-0000-000000000006';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-02 08:10:00+00', updated_at = '2026-10-02 08:10:00+00'
WHERE id = '40000000-0000-0000-0000-000000000006';

UPDATE trip
SET status = 'completed', fare_minor = 280000, completed_at = '2026-10-02 08:40:00+00', updated_at = '2026-10-02 08:40:00+00'
WHERE id = '40000000-0000-0000-0000-000000000006';

-- T7: Completed historical trip for R2 with D3
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'requested', 6.450000, 3.400000, 6.550000, 3.350000, 450000, 'NGN', '2026-10-02 10:00:00+00', '2026-10-02 10:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000003', vehicle_id = '30000000-0000-0000-0000-000000000003',
    driver_name_snapshot = 'Hassan Ibrahim', vehicle_plate_snapshot = 'APP-303CC', accepted_at = '2026-10-02 10:03:00+00', updated_at = '2026-10-02 10:03:00+00'
WHERE id = '40000000-0000-0000-0000-000000000007';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-02 10:12:00+00', updated_at = '2026-10-02 10:12:00+00'
WHERE id = '40000000-0000-0000-0000-000000000007';

UPDATE trip
SET status = 'completed', fare_minor = 450000, completed_at = '2026-10-02 10:55:00+00', updated_at = '2026-10-02 10:55:00+00'
WHERE id = '40000000-0000-0000-0000-000000000007';

-- T8: Completed historical trip for R3 with D1
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000003', 'requested', 6.600000, 3.350000, 6.450000, 3.420000, 600000, 'NGN', '2026-10-03 09:00:00+00', '2026-10-03 09:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000001', vehicle_id = '30000000-0000-0000-0000-000000000001',
    driver_name_snapshot = 'Folake Johnson', vehicle_plate_snapshot = 'KJA-101AA', accepted_at = '2026-10-03 09:04:00+00', updated_at = '2026-10-03 09:04:00+00'
WHERE id = '40000000-0000-0000-0000-000000000008';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-03 09:15:00+00', updated_at = '2026-10-03 09:15:00+00'
WHERE id = '40000000-0000-0000-0000-000000000008';

UPDATE trip
SET status = 'completed', fare_minor = 600000, completed_at = '2026-10-03 10:10:00+00', updated_at = '2026-10-03 10:10:00+00'
WHERE id = '40000000-0000-0000-0000-000000000008';

-- T9: Cancelled from requested by rider R4
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000004', 'requested', 6.500000, 3.360000, 6.450000, 3.420000, 350000, 'NGN', '2026-10-03 12:00:00+00', '2026-10-03 12:00:00+00');

UPDATE trip
SET status = 'cancelled', cancelled_by = 'rider', cancelled_at = '2026-10-03 12:05:00+00', updated_at = '2026-10-03 12:05:00+00'
WHERE id = '40000000-0000-0000-0000-000000000009';

-- T10: Cancelled after acceptance by driver D2
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000005', 'requested', 6.430000, 3.410000, 6.520000, 3.380000, 380000, 'NGN', '2026-10-04 14:00:00+00', '2026-10-04 14:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000002', vehicle_id = '30000000-0000-0000-0000-000000000002',
    driver_name_snapshot = 'Gbolahan Salami', vehicle_plate_snapshot = 'LSR-202BB', accepted_at = '2026-10-04 14:03:00+00', updated_at = '2026-10-04 14:03:00+00'
WHERE id = '40000000-0000-0000-0000-000000000010';

UPDATE trip
SET status = 'cancelled', cancelled_by = 'driver', cancelled_at = '2026-10-04 14:08:00+00', updated_at = '2026-10-04 14:08:00+00'
WHERE id = '40000000-0000-0000-0000-000000000010';

-- T11: Cancelled after acceptance by rider R3 with D3
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000003', 'requested', 6.440000, 3.390000, 6.500000, 3.370000, 290000, 'NGN', '2026-10-05 09:00:00+00', '2026-10-05 09:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000003', vehicle_id = '30000000-0000-0000-0000-000000000003',
    driver_name_snapshot = 'Hassan Ibrahim', vehicle_plate_snapshot = 'APP-303CC', accepted_at = '2026-10-05 09:02:00+00', updated_at = '2026-10-05 09:02:00+00'
WHERE id = '40000000-0000-0000-0000-000000000011';

UPDATE trip
SET status = 'cancelled', cancelled_by = 'rider', cancelled_at = '2026-10-05 09:06:00+00', updated_at = '2026-10-05 09:06:00+00'
WHERE id = '40000000-0000-0000-0000-000000000011';

-- T12: Completed historical trip for R4 with D1
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000004', 'requested', 6.450000, 3.430000, 6.540000, 3.360000, 320000, 'NGN', '2026-10-05 11:00:00+00', '2026-10-05 11:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000001', vehicle_id = '30000000-0000-0000-0000-000000000001',
    driver_name_snapshot = 'Folake Johnson', vehicle_plate_snapshot = 'KJA-101AA', accepted_at = '2026-10-05 11:03:00+00', updated_at = '2026-10-05 11:03:00+00'
WHERE id = '40000000-0000-0000-0000-000000000012';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-05 11:15:00+00', updated_at = '2026-10-05 11:15:00+00'
WHERE id = '40000000-0000-0000-0000-000000000012';

UPDATE trip
SET status = 'completed', fare_minor = 320000, completed_at = '2026-10-05 11:50:00+00', updated_at = '2026-10-05 11:50:00+00'
WHERE id = '40000000-0000-0000-0000-000000000012';

-- Specific Required Fixtures (T1, T2, T3, T4, T5)
-- ----------------------------------------------------------------------------

-- FIXTURE T1: R1 has trip T1 in_progress, with driver D1 and vehicle V1
-- Used for: Q3 trip completion demo and testing active-trip conflict (R1/R2)
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'requested', 6.447400, 3.390300, 6.524400, 3.379200, 350000, 'NGN', '2026-10-06 08:00:00+00', '2026-10-06 08:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000001', vehicle_id = '30000000-0000-0000-0000-000000000001',
    driver_name_snapshot = 'Folake Johnson', vehicle_plate_snapshot = 'KJA-101AA', accepted_at = '2026-10-06 08:02:10+00', updated_at = '2026-10-06 08:02:10+00'
WHERE id = '40000000-0000-0000-0000-000000000001';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-06 08:10:00+00', updated_at = '2026-10-06 08:10:00+00'
WHERE id = '40000000-0000-0000-0000-000000000001';

-- FIXTURE T2: Completed trip for R3, driver D2, vehicle V2, fare 350000 NGN, NO payment yet, NO rating
-- Used for: Q4 payment insertion demo and invalid payment amount check demo
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', 'requested', 6.431200, 3.415800, 6.512000, 3.398000, 350000, 'NGN', '2026-10-06 09:00:00+00', '2026-10-06 09:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000002', vehicle_id = '30000000-0000-0000-0000-000000000002',
    driver_name_snapshot = 'Gbolahan Salami', vehicle_plate_snapshot = 'LSR-202BB', accepted_at = '2026-10-06 09:03:00+00', updated_at = '2026-10-06 09:03:00+00'
WHERE id = '40000000-0000-0000-0000-000000000002';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-06 09:12:00+00', updated_at = '2026-10-06 09:12:00+00'
WHERE id = '40000000-0000-0000-0000-000000000002';

UPDATE trip
SET status = 'completed', fare_minor = 350000, completed_at = '2026-10-06 09:50:00+00', updated_at = '2026-10-06 09:50:00+00'
WHERE id = '40000000-0000-0000-0000-000000000002';

-- FIXTURE T3: Requested trip for rider R2
-- Used for: Q2 driver acceptance demo and invalid rating on non-completed trip check
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'requested', 6.460000, 3.375000, 6.580000, 3.340000, 420000, 'NGN', '2026-10-06 10:00:00+00', '2026-10-06 10:00:00+00');

-- FIXTURE T4: Completed trip for R4, driver D3, vehicle V3, with a succeeded payment and a rating
-- Used for: Demonstrating fully settled lifecycle (A1-A5 complete)
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', 'requested', 6.480000, 3.360000, 6.610000, 3.350000, 500000, 'NGN', '2026-10-06 10:30:00+00', '2026-10-06 10:30:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000003', vehicle_id = '30000000-0000-0000-0000-000000000003',
    driver_name_snapshot = 'Hassan Ibrahim', vehicle_plate_snapshot = 'APP-303CC', accepted_at = '2026-10-06 10:33:00+00', updated_at = '2026-10-06 10:33:00+00'
WHERE id = '40000000-0000-0000-0000-000000000004';

UPDATE trip
SET status = 'in_progress', started_at = '2026-10-06 10:45:00+00', updated_at = '2026-10-06 10:45:00+00'
WHERE id = '40000000-0000-0000-0000-000000000004';

UPDATE trip
SET status = 'completed', fare_minor = 500000, completed_at = '2026-10-06 11:35:00+00', updated_at = '2026-10-06 11:35:00+00'
WHERE id = '40000000-0000-0000-0000-000000000004';

-- FIXTURE T5: Accepted trip for R5, driver D4, vehicle V4
-- Used for: testing cross-driver vehicle foreign key check
INSERT INTO trip (id, rider_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, estimated_fare_minor, currency, created_at, updated_at)
VALUES ('40000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000005', 'requested', 6.455000, 3.395000, 6.530000, 3.365000, 310000, 'NGN', '2026-10-06 11:00:00+00', '2026-10-06 11:00:00+00');

UPDATE trip
SET status = 'accepted', driver_id = '20000000-0000-0000-0000-000000000004', vehicle_id = '30000000-0000-0000-0000-000000000004',
    driver_name_snapshot = 'Ifeanyi Okafor', vehicle_plate_snapshot = 'EKY-404DD', accepted_at = '2026-10-06 11:04:00+00', updated_at = '2026-10-06 11:04:00+00'
WHERE id = '40000000-0000-0000-0000-000000000005';

-- ============================================================================
-- 5. PAYMENTS (Exercising pending, succeeded, failed, refunded)
-- ============================================================================

-- P1: Succeeded payment for T4
INSERT INTO payment (id, trip_id, amount_minor, currency, status, provider, provider_reference, idempotency_key, created_at, updated_at)
VALUES ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004', 500000, 'NGN', 'pending', 'paystack', NULL, 'idem-key-small-001', '2026-10-06 11:36:00+00', '2026-10-06 11:36:00+00');

UPDATE payment
SET status = 'succeeded', provider_reference = 'pstk_ref_live_001', updated_at = '2026-10-06 11:36:05+00'
WHERE id = '50000000-0000-0000-0000-000000000001';

-- P2: Refunded payment for T6 (pending -> succeeded -> refunded)
INSERT INTO payment (id, trip_id, amount_minor, currency, status, provider, provider_reference, idempotency_key, created_at, updated_at)
VALUES ('50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000006', 280000, 'NGN', 'pending', 'paystack', NULL, 'idem-key-small-002', '2026-10-02 08:41:00+00', '2026-10-02 08:41:00+00');

UPDATE payment
SET status = 'succeeded', provider_reference = 'pstk_ref_live_002', updated_at = '2026-10-02 08:41:04+00'
WHERE id = '50000000-0000-0000-0000-000000000002';

UPDATE payment
SET status = 'refunded', updated_at = '2026-10-02 09:00:00+00'
WHERE id = '50000000-0000-0000-0000-000000000002';

-- P3: Failed payment for T7
INSERT INTO payment (id, trip_id, amount_minor, currency, status, provider, provider_reference, idempotency_key, created_at, updated_at)
VALUES ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000007', 450000, 'NGN', 'pending', 'flutterwave', NULL, 'idem-key-small-003', '2026-10-02 10:56:00+00', '2026-10-02 10:56:00+00');

UPDATE payment
SET status = 'failed', updated_at = '2026-10-02 10:56:08+00'
WHERE id = '50000000-0000-0000-0000-000000000003';

-- P4: Pending retry payment for T7
INSERT INTO payment (id, trip_id, amount_minor, currency, status, provider, provider_reference, idempotency_key, created_at, updated_at)
VALUES ('50000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000007', 450000, 'NGN', 'pending', 'paystack', NULL, 'idem-key-small-004', '2026-10-02 10:58:00+00', '2026-10-02 10:58:00+00');

-- ============================================================================
-- 6. RATINGS (3 rows)
-- ============================================================================
INSERT INTO rating (id, trip_id, trip_status, score, comment, created_at, updated_at) VALUES
    ('60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004', 'completed', 5, 'Excellent trip! Very polite driver and great conversation.', '2026-10-06 11:40:00+00', '2026-10-06 11:40:00+00'),
    ('60000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000006', 'completed', 4, 'Good driving, arrived quickly at the pickup point.',         '2026-10-02 08:45:00+00', '2026-10-02 08:45:00+00'),
    ('60000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000008', 'completed', 5, 'Clean car, smooth ride, and good music.',                     '2026-10-03 10:15:00+00', '2026-10-03 10:15:00+00');

COMMIT;
