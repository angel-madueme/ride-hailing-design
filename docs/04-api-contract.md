# Ride-hailing: API contract

## Conventions
- **Base path:** `/api/v1`. Every route is versioned from the first commit, so a v2 can exist without breaking v1 clients.
- **Format:** JSON in and out. Field names are camelCase. The database uses snake_case and the API maps between them.
- **Identifiers:** UUIDs. A malformed id in a path returns 404, never 500.
- **Time:** ISO 8601 in UTC, for example `2026-10-06T12:30:00Z`.
- **Money:** whole numbers in kobo with a currency, for example `"fareMinor": 350000, "currency": "NGN"`. The client never sends an amount. The server takes every amount from the trip.
- **Authentication (assumed):** every request except sign-up carries a bearer token that names the caller and their role, rider or driver. How tokens are issued is out of scope. The caller's id always comes from the token, never from the body or the path.
- **Success envelope:** `{ "data": ... }` for one item. `{ "data": [...], "meta": { ... } }` for a list.
- **Error envelope:** `{ "error": { "code": "TRIP_NOT_AVAILABLE", "message": "...", "details": { } } }`. `details` is optional. For 422 it holds `fields`.
- **Not yours means not found.** A resource the caller has no link to returns 404, so the API never confirms it exists. A caller with the wrong role for an action gets 403. A driver who is not the assigned driver of a trip gets 404 on it, except for accept.
- **Rate limit:** 100 requests per minute per caller. Over the limit returns 429 with `Retry-After`. The live-location endpoint has its own higher limit.
- **Idempotency header:** where used, `Idempotency-Key: <random uuid>`.

## Object shapes

### Trip
```json
{
  "id": "5b0c8f0e-6d1c-4c43-9a0e-3c1b1f5d7a10",
  "status": "accepted",
  "pickup": { "lat": 6.4474, "lng": 3.3903 },
  "dropoff": { "lat": 6.5244, "lng": 3.3792 },
  "estimatedFareMinor": 350000,
  "fareMinor": null,
  "currency": "NGN",
  "driver": { "id": "a1e2...", "name": "Ada O." },
  "vehicle": { "id": "c9d4...", "plate": "LND-421AA" },
  "cancelledBy": null,
  "acceptedAt": "2026-10-06T12:31:10Z",
  "startedAt": null,
  "completedAt": null,
  "cancelledAt": null,
  "createdAt": "2026-10-06T12:30:00Z",
  "updatedAt": "2026-10-06T12:31:10Z"
}
```
`driver.name` and `vehicle.plate` come from the snapshot columns, so they never change after the trip.

### Payment
```json
{
  "id": "e7a1...", "tripId": "5b0c...", "amountMinor": 350000,
  "currency": "NGN", "status": "pending",
  "createdAt": "2026-10-06T12:50:00Z", "updatedAt": "2026-10-06T12:50:00Z"
}
```

### Rating
```json
{ "id": "f3b2...", "tripId": "5b0c...", "score": 5, "comment": "Smooth ride", "createdAt": "2026-10-06T12:55:00Z" }
```

### Rider, driver, vehicle
- **Rider:** `id, fullName, phone, email, createdAt`
- **Driver:** `id, fullName, phone, email, licenceNumber, createdAt`
- **Vehicle:** `id, plateNumber, make, model, colour, year, createdAt`

## The five actions

### A1 Request a trip
`POST /api/v1/trips`, caller: rider

| Field | Type | Required | Rules |
|---|---|---|---|
| pickup | `{ lat, lng }` | yes | lat from -90 to 90, lng from -180 to 180 |
| dropoff | `{ lat, lng }` | yes | same ranges, and not equal to pickup |

```json
{ "pickup": { "lat": 6.4474, "lng": 3.3903 }, "dropoff": { "lat": 6.5244, "lng": 3.3792 } }
```
**Response 201:** a Trip with status `requested`, `estimatedFareMinor` set by the server, and `fareMinor`, `driver` and `vehicle` all null.

| Status | Code | When |
|---|---|---|
| 400 | INVALID_JSON | the body is not valid JSON |
| 401 | UNAUTHENTICATED | no token, or the token is invalid |
| 403 | WRONG_ROLE | the caller is not a rider |
| 409 | RIDER_HAS_ACTIVE_TRIP | the rider has a trip that is requested, accepted or in progress. `details.tripId` holds it (R1) |
| 422 | VALIDATION_ERROR | a coordinate is out of range, or pickup equals dropoff |
| 429 | RATE_LIMITED | over the limit |

**Idempotent:** not by key. Rule R1 already stops duplicates. A rider who loses the first response and retries gets 409 with the existing `tripId`, and fetches that trip.

### A2 Accept a trip
`POST /api/v1/trips/:id/accept`, caller: driver

| Field | Type | Required | Rules |
|---|---|---|---|
| vehicleId | uuid | yes | a vehicle that belongs to the caller and is not deleted |

**Response 200:** the Trip with status `accepted`, the driver and vehicle filled in from the token and the snapshots.

| Status | Code | When |
|---|---|---|
| 401 | UNAUTHENTICATED | no token |
| 403 | WRONG_ROLE | the caller is not a driver |
| 404 | NOT_FOUND | the trip does not exist, or the vehicle is not the caller's |
| 409 | TRIP_NOT_AVAILABLE | the trip is not in `requested`. `details.status` holds the current status |
| 409 | DRIVER_HAS_ACTIVE_TRIP | the driver already has an accepted or in-progress trip (R2) |
| 422 | VALIDATION_ERROR | `vehicleId` is missing or malformed |
| 429 | RATE_LIMITED | over the limit |

**Idempotent by state.** The server runs `UPDATE trip SET status = 'accepted' ... WHERE id = $1 AND status = 'requested'`. When two drivers accept at once, only one update matches and the other gets TRIP_NOT_AVAILABLE. If the same driver repeats the call and the trip is already accepted by them, the response is 200 with the current trip.

### A3 Start, complete and cancel a trip
All three are commands with their own caller and effect, so each has its own route. `PATCH /trips/:id` with a status field was the alternative. It lets the client name any status, and it blurs who may do what. The database transition guard still backs every route.

| Route | Caller | Moves | Body |
|---|---|---|---|
| `POST /api/v1/trips/:id/start` | assigned driver | accepted to in_progress | none |
| `POST /api/v1/trips/:id/complete` | assigned driver | in_progress to completed | none |
| `POST /api/v1/trips/:id/cancel` | rider (requested or accepted), assigned driver (accepted) | requested or accepted to cancelled | optional `{ "reason": string, max 200 }` |

**Response 200:** the Trip after the move. `complete` sets `fareMinor` to the trip's `estimatedFareMinor` and sets `completedAt`. Fares are fixed upfront in this design, so no client input is involved. `cancel` sets `cancelledBy` from the token's role and `cancelledAt`.

| Status | Code | When |
|---|---|---|
| 401 | UNAUTHENTICATED | no token |
| 403 | WRONG_ROLE | for example a rider calls `start` |
| 404 | NOT_FOUND | the trip does not exist or is not the caller's |
| 409 | INVALID_STATE_TRANSITION | the move is not allowed. `details` holds `from` and `to`. This covers cancelling an in-progress trip |
| 422 | VALIDATION_ERROR | the cancel reason is too long |
| 429 | RATE_LIMITED | over the limit |

**Idempotent by state.** Repeating `start` on a trip already in progress, `complete` on a completed trip, or `cancel` on a cancelled trip returns 200 with the trip unchanged.

### Live location (supports A2 and A3)
`POST /api/v1/trips/:id/location`, caller: assigned driver

Body `{ "lat": number, "lng": number, "recordedAt": timestamp }`. Response **204**. Nothing is written to the database. The point goes to the live channel (see the real-time analysis).

| Status | Code | When |
|---|---|---|
| 401 / 403 / 404 | as above | |
| 409 | TRIP_NOT_ACTIVE | the trip is not accepted or in progress |
| 422 | VALIDATION_ERROR | bad coordinates or timestamp |
| 429 | RATE_LIMITED | over the location limit |

**Idempotent:** yes. The latest `recordedAt` wins and an older point is ignored.

### A4 Pay for a trip
`POST /api/v1/trips/:id/payments`, caller: the trip's rider. Header `Idempotency-Key` is required.

| Field | Type | Required | Rules |
|---|---|---|---|
| paymentMethodToken | string | yes | a token from the payment provider. Card numbers never reach this API |

The amount and currency are copied from the trip's `fareMinor` and `currency`. The client cannot send them.

**Response 201:** a Payment with status `pending`. The charge request to the provider goes through a background job, so a provider outage never fails this call. The provider's webhook settles the payment (below). The client reads `GET /api/v1/payments/:id` to see the result.

| Status | Code | When |
|---|---|---|
| 400 | MISSING_IDEMPOTENCY_KEY | the header is absent |
| 401 | UNAUTHENTICATED | no token |
| 403 | WRONG_ROLE | the caller is not a rider |
| 404 | NOT_FOUND | the trip is not the caller's |
| 409 | TRIP_NOT_COMPLETED | the trip has no fare yet (R7) |
| 409 | TRIP_ALREADY_PAID | a succeeded payment exists |
| 409 | PAYMENT_IN_PROGRESS | another payment for this trip is still pending |
| 422 | VALIDATION_ERROR | `paymentMethodToken` is missing |
| 422 | IDEMPOTENCY_KEY_MISMATCH | the key was already used for a different trip |
| 429 | RATE_LIMITED | over the limit |

**Idempotent by key.** The key is stored in `payment.idempotency_key`, which is unique. A replay with the same key and the same trip returns 200 with the original payment and charges nothing. A failed payment can be retried with a **new** key, which creates a new payment row.

**Webhook:** `POST /api/v1/webhooks/payments`, called by the provider, not by users.
- Header `X-Signature`, checked against the shared secret.
- Body `{ providerReference, status: "succeeded" | "failed", amountMinor, currency }`.
- Returns 200 when applied, or when it repeats a status already applied.
- Errors: 400 INVALID_JSON, 401 INVALID_SIGNATURE, 404 NOT_FOUND (unknown reference), 409 INVALID_STATE_TRANSITION (for example failed to succeeded), 422 AMOUNT_MISMATCH.
- **Idempotent:** yes. The provider retries, and a repeat changes nothing.

### A5 Rate the driver
`POST /api/v1/trips/:id/rating`, caller: the trip's rider

| Field | Type | Required | Rules |
|---|---|---|---|
| score | integer | yes | 1 to 5 |
| comment | string | no | up to 500 characters |

**Response 201:** the Rating.

| Status | Code | When |
|---|---|---|
| 401 | UNAUTHENTICATED | no token |
| 403 | WRONG_ROLE | the caller is not a rider |
| 404 | NOT_FOUND | the trip is not the caller's |
| 409 | TRIP_NOT_COMPLETED | the trip is not completed (R6) |
| 409 | TRIP_ALREADY_RATED | a rating exists with different content |
| 422 | VALIDATION_ERROR | the score is out of range |
| 429 | RATE_LIMITED | over the limit |

**Idempotent by content.** The database allows one rating per trip. Repeating the call with the same score and comment returns 200 with the existing rating. Different content returns 409.

## Basic operations by entity

### Rider and driver
| Method and path | Caller | Body | Success | Errors | Idempotent |
|---|---|---|---|---|---|
| `POST /riders` | anyone (sign-up) | fullName, phone, email | 201 Rider | 400, 409 DUPLICATE_VALUE, 422, 429 | No. A repeat returns 409 because the phone is unique |
| `GET /riders/:id` | that rider | none | 200 | 401, 404 | Yes |
| `PATCH /riders/:id` | that rider | any of fullName, phone, email | 200 | 401, 404, 409 DUPLICATE_VALUE, 422 | Yes |
| `DELETE /riders/:id` | that rider | none | 204 | 401, 404, 409 ACCOUNT_HAS_ACTIVE_TRIP | The end state repeats. A second call returns 404 because the account is gone |
| `POST /drivers` | anyone (sign-up) | fullName, phone, email, licenceNumber | 201 Driver | 400, 409, 422, 429 | No, same reason |
| `GET /drivers/:id` | that driver. A rider sees only `fullName` and the rating summary of a driver on one of their trips | none | 200 | 401, 404 | Yes |
| `PATCH /drivers/:id` | that driver | any of fullName, phone, email | 200 | 401, 404, 409, 422 | Yes |
| `DELETE /drivers/:id` | that driver | none | 204 | 401, 404, 409 ACCOUNT_HAS_ACTIVE_TRIP | As for riders |

Deleting an account is a soft delete. Name, phone and email are replaced, `deleted_at` is set, and the trips stay.

### Vehicle
| Method and path | Caller | Body | Success | Errors | Idempotent |
|---|---|---|---|---|---|
| `POST /vehicles` | driver | plateNumber, make, model, colour, year | 201 | 403, 409 DUPLICATE_VALUE, 422 | No |
| `GET /vehicles` | driver, own only | none | 200 list | 401, 403 | Yes |
| `GET /vehicles/:id` | owning driver | none | 200 | 401, 404 | Yes |
| `PATCH /vehicles/:id` | owning driver | any of make, model, colour, year. The plate cannot change | 200 | 401, 404, 422 | Yes |
| `DELETE /vehicles/:id` | owning driver | none | 204 | 401, 404, 409 VEHICLE_IN_ACTIVE_TRIP | End state repeats. A second call returns 404 |

### Trip, payment and rating reads
| Method and path | Caller | Success | Errors |
|---|---|---|---|
| `GET /trips` | rider or driver (see lists) | 200 list | 400 INVALID_QUERY, 401, 403 |
| `GET /trips/:id` | the rider, the assigned driver, or any driver when the status is requested | 200 Trip | 401, 404 |
| `GET /trips/:id/payments` | the trip's rider | 200 list | 401, 404 |
| `GET /payments/:id` | the rider who paid | 200 Payment | 401, 404 |
| `GET /trips/:id/rating` | the trip's rider or driver | 200 Rating | 401, 404 (also when no rating exists) |
| `GET /drivers/:id/rating-summary` | that driver, or a rider with a trip with them | 200 `{ average, count }` | 401, 404 |

All reads are idempotent. Trips, payments and ratings have no update or delete routes, because trips and payments are never deleted (R8) and ratings are immutable.

## Lists: pagination, filtering and sorting

**Common rules for every list**
- `limit`: default 20, maximum 100. A value above 100 is clamped to 100. A value below 1 returns 400 INVALID_QUERY.
- `cursor`: an opaque string copied from the previous response. A bad cursor returns 400 INVALID_QUERY. A cursor past the end returns an empty list.
- `meta` is `{ "limit": 20, "hasMore": true, "nextCursor": "..." }`. There is **no total**. Counting a growing table on every page is slow, and the number changes while the user pages.
- Order is fixed, always with the id as a final tiebreaker, so every page is stable. Any `sort` parameter returns 400 INVALID_QUERY.
- **Why cursor and not offset:** new trips arrive at the top while a rider pages. With offset, rows shift between pages and repeat or vanish. A cursor remembers where the reader stopped, and it follows the index.

| Endpoint | Filters | Fixed order | Index |
|---|---|---|---|
| `GET /trips` | `scope`: `mine` (default) or `open` (drivers only). `status`: one or more values, mine only. `createdFrom`, `createdTo` | mine: `createdAt` newest first. open: `createdAt` oldest first | mine: the rider or driver history index. open: the open-requests index |
| `GET /vehicles` | none | `createdAt` newest first | `vehicle_driver_id_idx` |
| `GET /trips/:id/payments` | `status` | `createdAt` newest first | `payment_trip_id_idx` |

The `open` scope shows requested trips and hides the rider's phone and email. Filtering open requests by distance is out of scope.

## Error catalogue
| Status | Code | Meaning |
|---|---|---|
| 400 | INVALID_JSON, MISSING_IDEMPOTENCY_KEY, INVALID_QUERY | a malformed request |
| 401 | UNAUTHENTICATED, INVALID_SIGNATURE | no valid identity |
| 403 | WRONG_ROLE | the role cannot do this action |
| 404 | NOT_FOUND | missing, or not the caller's. Includes malformed ids |
| 409 | RIDER_HAS_ACTIVE_TRIP, DRIVER_HAS_ACTIVE_TRIP, TRIP_NOT_AVAILABLE, INVALID_STATE_TRANSITION, TRIP_NOT_ACTIVE, TRIP_NOT_COMPLETED, TRIP_ALREADY_PAID, PAYMENT_IN_PROGRESS, TRIP_ALREADY_RATED, ACCOUNT_HAS_ACTIVE_TRIP, VEHICLE_IN_ACTIVE_TRIP, DUPLICATE_VALUE | the request conflicts with the current state |
| 422 | VALIDATION_ERROR, IDEMPOTENCY_KEY_MISMATCH, AMOUNT_MISMATCH | well-formed but not acceptable |
| 429 | RATE_LIMITED | over the limit, with `Retry-After` |
| 500 | INTERNAL_ERROR | a bug. The body shows no stack trace |
| 503 | SERVICE_UNAVAILABLE | the database is unreachable, with `Retry-After` |

Never return 200 with an error in the body, and never return 500 for a problem the client caused.