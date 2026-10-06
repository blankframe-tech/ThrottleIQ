# Domain Directory

Domain layer containing core business rules, entities, and repository interfaces.

## Submodules

This directory contains the following submodules:

- **[calculators](./calculators)**: Pure maintenance maths — `maintenance_forecast.dart` (the one definition of "due": km or time, baselines, projected dates), `riding_conditions.dart` (telemetry / road-profile interval adjustments), `maintenance_money.dart` (spend per month and per km), plus fuel-unit conversion and ride running-cost calculations.
- **catalog**: `schedule_templates.dart` — per-model and per-cc service schedules, oil grades, and Log-a-visit bundles.
- **[entities](./entities)**: Contains core business logic entities. These represent the fundamental data structures without framework dependencies.
