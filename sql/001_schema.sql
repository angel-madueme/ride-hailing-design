-- ============================================================================
-- 001_schema.sql
-- Description: Creates the full ride-hailing PostgreSQL 18 schema within a
--              single transaction, including custom enum types, transition
--              lookup tables, domain constraints, status shape checks,
--              transition/initialization triggers, and optimized indexes.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ============================================================================
-- 1. ENUM TYPES
-- ============================================================================

CREATE TYPE trip_status AS ENUM (
    'requested',
    'accepted',
    'in_progress',
    'completed',
    'cancelled'
);

CREATE TYPE payment_status AS ENUM (
    'pending',
    'succeeded',
    'failed',
    'refunded'
);

CREATE TYPE cancelled_by AS ENUM (
    'rider',
    'driver'
);

-- ============================================================================
-- 2. TRANSITION GUARD TABLES
-- ============================================================================

CREATE TABLE trip_status_transition (
    from_status trip_status NOT NULL,
    to_status   trip_status NOT NULL,
    CONSTRAINT trip_status_transition_pkey PRIMARY KEY (from_status, to_status)
);

-- Exactly 5 allowed trip status transitions as specified in docs/03 section 3
INSERT INTO trip_status_transition (from_status, to_status) VALUES
    ('requested',   'accepted'),
    ('requested',   'cancelled'),
    ('accepted',    'in_progress'),
    ('accepted',    'cancelled'),
    ('in_progress', 'completed');

CREATE TABLE payment_status_transition (
    from_status payment_status NOT NULL,
    to_status   payment_status NOT NULL,
    CONSTRAINT payment_status_transition_pkey PRIMARY KEY (from_status, to_status)
);

-- Exactly 3 allowed payment status transitions as specified in docs/03 section 3
INSERT INTO payment_status_transition (from_status, to_status) VALUES
    ('pending',   'succeeded'),
    ('pending',   'failed'),
    ('succeeded', 'refunded');

-- ============================================================================
-- 3. CORE ENTITY TABLES AND CONSTRAINTS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- rider
-- ----------------------------------------------------------------------------
CREATE TABLE rider (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name  text        NOT NULL,
    phone      text        NOT NULL,
    email      text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,

    CONSTRAINT rider_email_chk CHECK (position('@' IN email) > 0)
);

CREATE UNIQUE INDEX rider_phone_active_key ON rider (phone) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX rider_email_active_key ON rider (email) WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- driver
-- ----------------------------------------------------------------------------
CREATE TABLE driver (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name      text        NOT NULL,
    phone          text        NOT NULL,
    email          text        NOT NULL,
    licence_number text        NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,

    CONSTRAINT driver_email_chk CHECK (position('@' IN email) > 0)
);

CREATE UNIQUE INDEX driver_phone_active_key   ON driver (phone)          WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX driver_email_active_key   ON driver (email)          WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX driver_licence_active_key ON driver (licence_number) WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- vehicle
-- ----------------------------------------------------------------------------
CREATE TABLE vehicle (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id    uuid        NOT NULL REFERENCES driver (id) ON DELETE RESTRICT,
    plate_number text        NOT NULL,
    make         text        NOT NULL,
    model        text        NOT NULL,
    colour       text        NOT NULL,
    year         smallint    NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,

    CONSTRAINT vehicle_id_driver_id_key UNIQUE (id, driver_id),
    CONSTRAINT vehicle_year_chk CHECK (year BETWEEN 1990 AND 2100)
);

CREATE UNIQUE INDEX vehicle_plate_active_key ON vehicle (plate_number) WHERE deleted_at IS NULL;

-- ----------------------------------------------------------------------------
-- trip
-- ----------------------------------------------------------------------------
CREATE TABLE trip (
    id                     uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id               uuid          NOT NULL REFERENCES rider (id) ON DELETE RESTRICT,
    driver_id              uuid          REFERENCES driver (id) ON DELETE RESTRICT,
    vehicle_id             uuid,
    status                 trip_status   NOT NULL DEFAULT 'requested',
    pickup_lat             numeric(9, 6) NOT NULL,
    pickup_lng             numeric(9, 6) NOT NULL,
    dropoff_lat            numeric(9, 6) NOT NULL,
    dropoff_lng            numeric(9, 6) NOT NULL,
    estimated_fare_minor   bigint        NOT NULL,
    fare_minor             bigint,
    currency               char(3)       NOT NULL,
    driver_name_snapshot   text,
    vehicle_plate_snapshot text,
    cancelled_by           cancelled_by,
    accepted_at            timestamptz,
    started_at             timestamptz,
    completed_at           timestamptz,
    cancelled_at           timestamptz,
    created_at             timestamptz   NOT NULL DEFAULT now(),
    updated_at             timestamptz   NOT NULL DEFAULT now(),

    -- Pairs and triples exposed for downstream foreign key validation
    CONSTRAINT trip_fare_currency_key UNIQUE (id, fare_minor, currency),
    CONSTRAINT trip_status_key        UNIQUE (id, status),

    -- Foreign key to vehicle ensuring vehicle belongs to the assigned driver
    CONSTRAINT trip_vehicle_belongs_to_driver_fk
        FOREIGN KEY (vehicle_id, driver_id)
        REFERENCES vehicle (id, driver_id)
        ON DELETE RESTRICT,

    -- Value & domain validation checks
    CONSTRAINT trip_estimated_fare_chk CHECK (estimated_fare_minor >= 0),
    CONSTRAINT trip_fare_chk           CHECK (fare_minor IS NULL OR fare_minor >= 0),
    CONSTRAINT trip_currency_chk       CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT trip_lat_lng_chk        CHECK (
        pickup_lat BETWEEN -90 AND 90 AND
        pickup_lng BETWEEN -180 AND 180 AND
        dropoff_lat BETWEEN -90 AND 90 AND
        dropoff_lng BETWEEN -180 AND 180
    ),
    CONSTRAINT trip_pickup_dropoff_diff_chk CHECK (
        pickup_lat <> dropoff_lat OR pickup_lng <> dropoff_lng
    ),

    -- Shape check tying each status to required / prohibited fields
    CONSTRAINT trip_status_shape_chk CHECK (
        (
            status = 'requested' AND
            driver_id IS NULL AND
            vehicle_id IS NULL AND
            fare_minor IS NULL AND
            driver_name_snapshot IS NULL AND
            vehicle_plate_snapshot IS NULL AND
            accepted_at IS NULL AND
            started_at IS NULL AND
            completed_at IS NULL AND
            cancelled_at IS NULL AND
            cancelled_by IS NULL
        ) OR (
            status = 'accepted' AND
            driver_id IS NOT NULL AND
            vehicle_id IS NOT NULL AND
            driver_name_snapshot IS NOT NULL AND
            vehicle_plate_snapshot IS NOT NULL AND
            accepted_at IS NOT NULL AND
            fare_minor IS NULL AND
            started_at IS NULL AND
            completed_at IS NULL AND
            cancelled_at IS NULL AND
            cancelled_by IS NULL
        ) OR (
            status = 'in_progress' AND
            driver_id IS NOT NULL AND
            vehicle_id IS NOT NULL AND
            driver_name_snapshot IS NOT NULL AND
            vehicle_plate_snapshot IS NOT NULL AND
            accepted_at IS NOT NULL AND
            started_at IS NOT NULL AND
            fare_minor IS NULL AND
            completed_at IS NULL AND
            cancelled_at IS NULL AND
            cancelled_by IS NULL
        ) OR (
            status = 'completed' AND
            driver_id IS NOT NULL AND
            vehicle_id IS NOT NULL AND
            driver_name_snapshot IS NOT NULL AND
            vehicle_plate_snapshot IS NOT NULL AND
            accepted_at IS NOT NULL AND
            started_at IS NOT NULL AND
            completed_at IS NOT NULL AND
            fare_minor IS NOT NULL AND
            cancelled_at IS NULL AND
            cancelled_by IS NULL
        ) OR (
            status = 'cancelled' AND
            cancelled_at IS NOT NULL AND
            cancelled_by IS NOT NULL AND
            fare_minor IS NULL AND
            started_at IS NULL AND
            completed_at IS NULL AND
            ((driver_id IS NULL) = (vehicle_id IS NULL)) AND
            ((driver_id IS NULL) = (accepted_at IS NULL)) AND
            ((driver_name_snapshot IS NOT NULL) = (driver_id IS NOT NULL)) AND
            ((vehicle_plate_snapshot IS NOT NULL) = (driver_id IS NOT NULL))
        )
    )
);

-- Partial unique indexes enforcing business rules R1 and R2
CREATE UNIQUE INDEX trip_one_active_per_rider ON trip (rider_id)
    WHERE status IN ('requested', 'accepted', 'in_progress');

CREATE UNIQUE INDEX trip_one_active_per_driver ON trip (driver_id)
    WHERE status IN ('accepted', 'in_progress');

-- ----------------------------------------------------------------------------
-- payment
-- ----------------------------------------------------------------------------
CREATE TABLE payment (
    id                 uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id            uuid           NOT NULL,
    amount_minor       bigint         NOT NULL,
    currency           char(3)        NOT NULL,
    status             payment_status NOT NULL DEFAULT 'pending',
    provider           text           NOT NULL,
    provider_reference text,
    idempotency_key    text           NOT NULL,
    created_at         timestamptz    NOT NULL DEFAULT now(),
    updated_at         timestamptz    NOT NULL DEFAULT now(),

    -- Foreign key to trip ensuring payment matches trip fare and currency
    CONSTRAINT payment_matches_trip_fare_fk
        FOREIGN KEY (trip_id, amount_minor, currency)
        REFERENCES trip (id, fare_minor, currency)
        ON DELETE RESTRICT,

    CONSTRAINT payment_idempotency_key_key UNIQUE (idempotency_key),
    CONSTRAINT payment_amount_chk CHECK (amount_minor >= 1),
    CONSTRAINT payment_currency_chk CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT payment_succeeded_reference_chk CHECK (
        status <> 'succeeded' OR provider_reference IS NOT NULL
    )
);

CREATE UNIQUE INDEX payment_provider_reference_key ON payment (provider_reference)
    WHERE provider_reference IS NOT NULL;

CREATE UNIQUE INDEX payment_one_success_per_trip ON payment (trip_id)
    WHERE status = 'succeeded';

-- ----------------------------------------------------------------------------
-- rating
-- ----------------------------------------------------------------------------
CREATE TABLE rating (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     uuid        NOT NULL,
    trip_status trip_status NOT NULL DEFAULT 'completed',
    score       smallint    NOT NULL,
    comment     text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT rating_one_per_trip UNIQUE (trip_id),
    CONSTRAINT rating_trip_status_completed_chk CHECK (trip_status = 'completed'),
    CONSTRAINT rating_score_chk CHECK (score BETWEEN 1 AND 5),

    -- Foreign key ensuring rating only attaches to a completed trip
    CONSTRAINT rating_trip_is_completed_fk
        FOREIGN KEY (trip_id, trip_status)
        REFERENCES trip (id, status)
        ON DELETE RESTRICT
);

-- ============================================================================
-- 4. TRIGGERS AND FUNCTIONS
-- ============================================================================

-- Function to maintain updated_at on modification
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_rider
    BEFORE UPDATE ON rider
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_updated_at_driver
    BEFORE UPDATE ON driver
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_updated_at_vehicle
    BEFORE UPDATE ON vehicle
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_updated_at_trip
    BEFORE UPDATE ON trip
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_updated_at_payment
    BEFORE UPDATE ON payment
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_updated_at_rating
    BEFORE UPDATE ON rating
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Initial status check triggers on INSERT
CREATE OR REPLACE FUNCTION check_trip_initial_status()
RETURNS trigger AS $$
BEGIN
    IF NEW.status <> 'requested' THEN
        RAISE EXCEPTION 'New trip must start with status requested, got %', NEW.status
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trip_initial_status_trg
    BEFORE INSERT ON trip
    FOR EACH ROW
    EXECUTE FUNCTION check_trip_initial_status();

CREATE OR REPLACE FUNCTION check_payment_initial_status()
RETURNS trigger AS $$
BEGIN
    IF NEW.status <> 'pending' THEN
        RAISE EXCEPTION 'New payment must start with status pending, got %', NEW.status
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payment_initial_status_trg
    BEFORE INSERT ON payment
    FOR EACH ROW
    EXECUTE FUNCTION check_payment_initial_status();

-- Transition check triggers on UPDATE
CREATE OR REPLACE FUNCTION check_trip_status_transition()
RETURNS trigger AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NOT EXISTS (
            SELECT 1 FROM trip_status_transition
            WHERE from_status = OLD.status AND to_status = NEW.status
        ) THEN
            RAISE EXCEPTION 'Invalid trip status change: % to %', OLD.status, NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trip_status_transition_trg
    BEFORE UPDATE OF status ON trip
    FOR EACH ROW
    EXECUTE FUNCTION check_trip_status_transition();

CREATE OR REPLACE FUNCTION check_payment_status_transition()
RETURNS trigger AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NOT EXISTS (
            SELECT 1 FROM payment_status_transition
            WHERE from_status = OLD.status AND to_status = NEW.status
        ) THEN
            RAISE EXCEPTION 'Invalid payment status change: % to %', OLD.status, NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payment_status_transition_trg
    BEFORE UPDATE OF status ON payment
    FOR EACH ROW
    EXECUTE FUNCTION check_payment_status_transition();

-- ============================================================================
-- 5. QUERY INDEXES
-- ============================================================================

-- Action A2: open requests listing ordered by oldest first with tiebreaker
CREATE INDEX trip_open_requests_idx ON trip (created_at, id)
    WHERE status = 'requested';

-- Rider trip history pagination ordered by newest first with tiebreaker
CREATE INDEX trip_rider_history_idx ON trip (rider_id, created_at DESC, id DESC);

-- Driver trip history pagination and rating calculations
CREATE INDEX trip_driver_history_idx ON trip (driver_id, created_at DESC, id DESC);

-- Payment lookups by trip
CREATE INDEX payment_trip_id_idx ON payment (trip_id);

-- Vehicle listing by driver
CREATE INDEX vehicle_driver_id_idx ON vehicle (driver_id);

COMMIT;
