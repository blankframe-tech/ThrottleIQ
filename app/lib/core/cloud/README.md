# Cloud Directory

This directory contains components related to `cloud`.

## Files

The following files are present in this directory:

- `cloud_repository.dart`: Repository implementation.
- `export_service.dart`: Dart source code.
- `firestore_quota.dart`: The over-quota flag that pauses sync and the outbox while Firestore refuses requests for its daily quota (issues §104).
- `maintenance_settings_sync.dart`: Cloud backup of a bike's maintenance settings and running costs (issues §88.2).
- `outbox_service.dart`: Durable outbox — queues cloud writes in SQLite and drains them with backoff.
- `ride_track_codec.dart`: Chunked flat-array encoding of a ride's GPS trail for Firestore.
- `ride_track_loader.dart`: Loads a ride's GPS trail from local points or the cloud.
- `sync_manager.dart`: Dart source code.
- `write_ack.dart`: `ackOrQueued`, a bounded wait for a Firestore write's ack; a timeout means queued, not failed (issues §104.6).

