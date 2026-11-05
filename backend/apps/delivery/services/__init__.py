"""Delivery services (06 §1.1: business logic lives here; views and the admin stay thin).

- `riders`: what the rider app does to its own profile (register, profile, KYC, bank).
- `kyc`: what staff do to riders (approve, reject, suspend, review documents), with the 05 §3
  role checks and the audit log. The admin panel calls these.
- `presenters`: API bodies.
- `shifts` (slice 5.2): going online/offline, location ingestion, auto-offline.
"""
