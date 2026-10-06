# Ride-hailing: requirements

## What it is
A ride-hailing service for one city. A rider asks for a trip, a nearby 
driver accepts, the driver takes the rider to the destination, and the 
rider pays at the end. All amounts are in naira (NGN).

## Who uses it
- **Rider:** requests, tracks, pays for and rates trips.
- **Driver:** accepts and completes trips, using a registered vehicle.

There is no admin user in this design.

## The five most important actions
| Id | Action | Who | What changes |
|----|--------|-----|--------------|
| A1 | Request a trip | Rider | A trip is created in the requested state with pickup, destination and an estimated fare |
| A2 | Accept a trip | Driver | The trip gets a driver and a vehicle, and moves to accepted |
| A3 | Start and complete a trip | Driver | The trip moves to in progress, then to completed with the final fare |
| A4 | Pay for a trip | Rider | A payment is created for the completed trip and settles |
| A5 | Rate the driver | Rider | A rating from 1 to 5 is attached to the completed trip |

Cancelling is not an action of its own. It is a move to the cancelled 
state, allowed for the rider or the driver before the trip starts.

## Business rules
| Id | Rule |
|----|------|
| R1 | A rider has at most one active trip at a time |
| R2 | A driver has at most one active trip at a time |
| R3 | A trip has one rider, at most one driver and at most one vehicle. A vehicle belongs to one driver |
| R4 | The fare is fixed when the trip completes and stays on the trip, even if prices change later |
| R5 | Every amount is a whole number in kobo, stored with its currency |
| R6 | A rating exists only for a completed trip, and each trip has at most one rating |
| R7 | A trip has at most one successful payment, and only a completed trip can be paid |
| R8 | Trips and payments are never hard-deleted, so the record stays for audit and disputes |
| R9 | A trip only moves along allowed state changes. It can never go backwards |

## Needs that shape the design
- A rider watches the driver approach after A2, so the client needs live 
  updates without polling. This feeds the real-time analysis in Step 4.
- Riders and drivers open "my trips" often, so trip history must be 
  fast to list. This feeds the index decisions.
- Money must never be wrong or duplicated. A retried payment request 
  must not charge twice. This feeds the idempotency rules.

## Out of scope
Surge pricing, maps and routing, driver sign-up and verification, promo 
codes, in-app chat, admin tools, and any user interface.

## Assumptions to confirm
1. Riders pay by card through a payment provider. A payment is created, 
   then settled.
2. One currency, NGN, but the currency column still exists on every 
   amount.
3. Locations are stored as latitude and longitude, with no address 
   lookup.
4. Fares are fixed upfront. The final fare equals the estimate calculated 
   at request, so no client input is involved.