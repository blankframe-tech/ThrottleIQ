# Entities Directory

Contains core business logic entities. These represent the fundamental data structures without framework dependencies.

## Files

The following files are present in this directory:

- `maintenance_entity.dart`: Service types, logs (with visit fields) and per-bike check configs (km/day intervals, baselines, custom checks).
- `maintenance_profile.dart`: Per-bike setup profile, paperwork expiries, and quick-check (T-CLOCS) issues.
- `service_visit.dart`: A visit as a group of logs, the Log-a-visit draft, and the pure row builder.
