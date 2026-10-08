# Test Directory

Contains unit, widget, and integration tests for the application.

## Submodules

This directory contains the following submodules:

- **[calculators](./calculators)**: Contains domain-specific calculators and algorithms (e.g., fuel efficiency, distance).
- **[cloud](./cloud)**: Ride upload-payload tests (route columns).
- **[core](./core)**: Contains core application infrastructure, services, theme definitions, and utilities shared across the app. SyncManager's guard behaviour is covered in `core/cloud/sync_manager_guard_test.dart`.
- **[database](./database)**: Components and logic related to database.
- **[features](./features)**: Contains all the feature-based modules of the application following clean architecture.
- **[repositories](./repositories)**: Ride repository tests.

## Files

The following files are present in this directory:

- `widget_test.dart`: Unit/Widget test file.
