-- ============================================================================
-- 000_reset.sql
-- Description: Drops all tables, custom types, transition tables, and functions
--              associated with the ride-hailing database.
-- WARNING: FOR A DEDICATED LOCAL/TEST DATABASE ONLY. This script completely wipes
--          all application schema objects and data.
-- ============================================================================

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS rating CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS trip CASCADE;
DROP TABLE IF EXISTS vehicle CASCADE;
DROP TABLE IF EXISTS driver CASCADE;
DROP TABLE IF EXISTS rider CASCADE;

-- Drop state transition lookup tables
DROP TABLE IF EXISTS trip_status_transition CASCADE;
DROP TABLE IF EXISTS payment_status_transition CASCADE;

-- Drop custom enum types
DROP TYPE IF EXISTS cancelled_by CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS trip_status CASCADE;

-- Drop trigger functions
DROP FUNCTION IF EXISTS set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS check_trip_status_transition() CASCADE;
DROP FUNCTION IF EXISTS check_payment_status_transition() CASCADE;
DROP FUNCTION IF EXISTS check_trip_initial_status() CASCADE;
DROP FUNCTION IF EXISTS check_payment_initial_status() CASCADE;
