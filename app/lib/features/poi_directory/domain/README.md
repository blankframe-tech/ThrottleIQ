# Domain Directory

Domain layer containing core business rules, entities, and repository interfaces.

## Submodules

This directory contains the following submodules:

- **[entities](./entities)**: Contains core business logic entities. These represent the fundamental data structures without framework dependencies.

## Files

The following files are present in this directory:

- `place_directions.dart`: Builds the map-app URLs behind a place's "Directions" button.
- `place_tags.dart`: `PlaceTag`, the rider tags on a place (24/7, octane 95, EFI diagnostics…).
- `places_query.dart`: `PlacesQuery` and `applyPlacesQuery`, the Places hub's search, filter, sort and chip counts.
- `highway_radar.dart`: `computeHighwayRadar`, which finds the speed cameras and police checkposts around the rider.
- `marker_clustering.dart`: grid clustering for the map's pins.
