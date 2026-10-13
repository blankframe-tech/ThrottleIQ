# Domain Directory

Domain layer containing core business rules, entities, and repository interfaces.

## Submodules

This directory contains the following submodules:

- **[entities](./entities)**: Contains core business logic entities. These represent the fundamental data structures without framework dependencies.

## Files

The following files are present in this directory:

- `bike_visibility.dart`: Who may see a rider's garage, and the predicate that answers it.
- `safe_qr_payload.dart`: Builds the plain-text payload encoded into a SafeQR code.
