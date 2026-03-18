# ReadlePress Mobile

Teacher-facing observation capture app for the ReadlePress HPC platform. Offline-first architecture with local Isar database, background sync via WorkManager, and GPS timestamp corroboration.

## Prerequisites

- Flutter SDK 3.16+
- Dart 3.2+

## Setup

**Important:** You must run the code generator before the project will compile.

```bash
# Install dependencies
flutter pub get

# Generate Isar schema (required — creates .g.dart files for models)
dart run build_runner build --delete-conflicting-outputs

# Add platform folders if missing (e.g. first-time setup)
flutter create . --platforms=android,ios

# Run the app
flutter run
```

If you see errors like `MasteryEventDraftSchema` or `part 'mastery_event_draft.g.dart'` not found, run the build_runner step above.

## Project Structure

```
lib/
  config/
    api_config.dart       # API base URL and endpoints (matches Node.js /api/v1/)
  models/
    mastery_event_draft.dart   # Isar collection for offline drafts
    evidence_upload.dart       # Isar collection for evidence queue
    sync_conflict.dart         # Isar collection for conflict resolution
    schema.dart                # Exports all schemas for Isar.open()
  services/
    auth_service.dart          # Login, token storage, JWT refresh
    sync_service.dart          # syncPendingDrafts, syncPendingEvidence, resolveConflicts
    gps_timestamp_service.dart # GPS_FIX / GPS_OFFSET / NTP_SYNCED / DEVICE_CLOCK
    capture_service.dart       # Create drafts, attach evidence, queue sync
  widgets/
    observation_form.dart      # Placeholder observation capture UI
  main.dart                    # App entry, Isar/Riverpod/WorkManager init
```

## API Configuration

Default base URL: `http://localhost:3000`. Override via `ApiConfig` for staging/production.

Key endpoints used by the app:

- `POST /api/v1/auth/login` — Authenticate
- `POST /api/v1/capture/sync` — Sync offline mastery event drafts
- `POST /api/v1/evidence` — Upload evidence (photos/media)

## Offline-First Flow

1. Teacher captures observation → `CaptureService.captureObservation()` creates `MasteryEventDraft` in Isar
2. Evidence (photos) attached → `EvidenceUpload` records created, linked via `evidenceLocalIds`
3. GPS timestamp service provides `observed_at` with source/confidence (GPS_FIX highest, DEVICE_CLOCK lowest)
4. WorkManager runs periodic sync when online
5. `SyncService.syncPendingDrafts()` POSTs to `/api/v1/capture/sync` — idempotent by `localId`
6. `SyncService.syncPendingEvidence()` POSTs to `/api/v1/evidence` for pending uploads
7. Conflicts stored in `SyncConflict` for UI-driven resolution

## Sync Protocol

- **observed_at** is preserved exactly as captured; never overwritten with server time
- Same `local_id` is not re-uploaded (idempotent)
- Sync failures mark drafts as `FAILED` with retry on next cycle
- Conflict resolution: `KEEP_DEVICE`, `KEEP_SERVER`, `MERGE`, `DISCARD`

## Platform Permissions

- **Android**: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` for GPS timestamp
- **iOS**: `NSLocationWhenInUseUsageDescription` in Info.plist
- **Background**: WorkManager for periodic sync (Android); configure Background Modes (iOS)

## Development

```bash
# Run tests
flutter test

# Analyze
flutter analyze
```
