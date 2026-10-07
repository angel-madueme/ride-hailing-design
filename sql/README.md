# Ride-Hailing Database Validation (Step 5)

This directory contains plain PostgreSQL 18 SQL scripts that implement and prove the ride-hailing database design, constraints, transition triggers, and query execution plans.

> [!NOTE]
> All scripts use standard PostgreSQL client tools (`psql`). No passwords are stored in any file. Ensure your local PostgreSQL environment sets `PGPASSWORD` or prompts interactively.

---

## Execution Instructions

Run each SQL script in this order for a clean evidence run:

```powershell
# 0. Reset environment (wipes and recreates clean database objects)
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/000_reset.sql

# 1. Apply schema, custom enums, constraints, triggers, and query indexes
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/001_schema.sql

# 2. Seed small deterministic dataset with lifecycle state transitions
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/002_seed_small.sql

# 3. Seed high-volume dataset (60,000 trips) and analyze planner statistics
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/003_seed_volume.sql

# 4. Execute application action queries (A1-A5) and history pagination (H1)
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/004_queries.sql

# 5. Generate EXPLAIN (ANALYZE, BUFFERS) query plans
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/005_explain.sql

# 6. Execute constraint & trigger negative tests and rollback valid counterparts
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -p 5433 -d ride_hailing -f sql/006_invalid_inserts.sql
```

Scripts `004_queries.sql` and `006_invalid_inserts.sql` roll back every write,
so either may be rerun after the seed scripts, and running them in either order
produces the same fixture state.

## Deterministic fixtures used by the evidence scripts

| Fixture | Original state after `002_seed_small.sql` |
|---|---|
| R1 (`10000000-0000-0000-0000-000000000001`) | Rider with T1 active; used for the duplicate-active-trip test |
| T1 (`40000000-0000-0000-0000-000000000001`) | `in_progress`, assigned to D1/V1 |
| T2 (`40000000-0000-0000-0000-000000000002`) | `completed`, fare `350000 NGN`, no payment or rating |
| T3 (`40000000-0000-0000-0000-000000000003`) | `requested` |
| T5 (`40000000-0000-0000-0000-000000000005`) | `accepted`, assigned to D4/V4 |
| R3 (`10000000-0000-0000-0000-000000000003`) | Rider with no active trip; used for the valid counterpart in test 1 |

For a clean evidence run, reset and recreate the schema, load the small seed,
load the volume seed, then run `004_queries.sql`, `005_explain.sql`, and
`006_invalid_inserts.sql`. The query and invalid-insert scripts leave the
fixtures unchanged, so `004` followed by `006` and `006` followed by `004`
produce the same test results.

---

## Script Overview & Screenshot Guidance

### 1. `sql/000_reset.sql`
- **Purpose:** Drops all application tables, enum types, transition guards, and functions with `CASCADE`.
- **What to screenshot:** Clean `DROP TABLE`, `DROP TYPE`, and `DROP FUNCTION` output notices.

### 2. `sql/001_schema.sql`
- **Purpose:** Atomic transaction creating tables (`rider`, `driver`, `vehicle`, `trip`, `payment`, `rating`), check constraints, partial unique indexes, transition lookup tables, and trigger functions.
- **What to screenshot:** Successful `COMMIT` indicating all constraints and triggers compiled cleanly.

### 3. `sql/002_seed_small.sql`
- **Purpose:** Seeds 5 riders, 4 drivers, 5 vehicles, and 12 trips using deterministic UUIDs. Every trip begins as `requested` and is advanced via `UPDATE` statements to verify transition triggers.
- **What to screenshot:** Successful insertion and update output logs.

### 4. `sql/003_seed_volume.sql`
- **Purpose:** Bulk-loads ~2,000 riders, 300 drivers, 400 vehicles, and 60,000 trips (mostly completed, with payments and ratings) with power-law skew for realistic query planning. Runs `ANALYZE` on all tables.
- **What to screenshot:** Final `COMMIT` and `ANALYZE` completion.

### 5. `sql/004_queries.sql`
- **Purpose:** Demonstrates operational queries Q1–Q5 for actions A1–A5 and query H1 for rider history cursor pagination.
- **What to screenshot:** Query output rows showing correct tuple return structures and updated values.

### 6. `sql/005_explain.sql`
- **Purpose:** Runs `EXPLAIN (ANALYZE, BUFFERS)` on rider trip history (`H1`) and driver rating summary (`Q5`) for the highest-volume actors identified via `\gset`.
- **What to screenshot:**
  - **Plan 1 (H1):** `Index Scan` / `Bitmap Index Scan` on `trip_rider_history_idx` verifying fast cursor pagination without sequential table scans.
  - **Plan 2 (Q5):** Efficient index lookup on `trip_driver_history_idx` joined with `rating_one_per_trip`.

### 7. `sql/006_invalid_inserts.sql`
- **Purpose:** Demonstrates explicit rejection of invalid database states and invalid state transitions:
  1. Second active trip for rider R1 (`trip_one_active_per_rider` unique violation).
  2. Rating a non-completed trip (`rating_trip_is_completed_fk` foreign key violation).
  3. Mismatched payment amount (`payment_matches_trip_fare_fk` foreign key violation).
  4. Cancelling an in-progress trip (`trip_status_transition_trg` trigger check violation).
  5. Vehicle owned by another driver (`trip_vehicle_belongs_to_driver_fk` foreign key violation).
- **What to screenshot:** Each error message block matching the expected constraint / trigger name, followed by successful rollback of valid counterparts.
