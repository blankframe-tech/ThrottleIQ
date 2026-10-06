# Data Directory

Data layer handling external data sources, APIs, local storage, and repository implementations.

## Submodules

This directory contains the following submodules:

- **[models](./models)**: Contains data transfer objects (DTOs) and data models, typically with JSON serialization/deserialization logic.
- **repositories**: Riverpod-free loaders shared by the page, the home-screen widget and notifications — `maintenance_forecast_repository.dart` (configs + logs + profile + usage → forecast) and `maintenance_usage_repository.dart` (riding pace and telemetry for a bike).
- **services**: `maintenance_alerts.dart` (due-soon / overdue / paperwork notifications and scheduled reminders) and `service_record_pdf.dart` (the exportable service record).
