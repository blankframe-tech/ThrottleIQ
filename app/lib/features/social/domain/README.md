# Domain Directory

Domain layer containing core business rules, entities, and repository interfaces.

## Submodules

This directory contains the following submodules:

- **[entities](./entities)**: Contains core business logic entities. These represent the fundamental data structures without framework dependencies.
- **[utilities](./utilities)**: Components and logic related to utilities.

## Files

The following files are present in this directory:

- `feed_page_merge.dart`: Merges several paged Firestore queries into one feed page.
- `feed_sort.dart`: How the social feed is ordered/filtered.
