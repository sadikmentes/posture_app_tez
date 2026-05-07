# Database design (posture_app)

## 1) Goals
- Keep posture samples queryable by time ranges (day/week/month)
- Keep user/device/session relation explicit
- Support offline-first mobile flow
- Keep storage cost under control with retention + aggregates

## 2) Recommended stack
- Local on device: SQLite (sqflite/drift)
- Cloud: PostgreSQL (Supabase/Firebase SQL alternative)
- Sync model: local write-first, background sync job

## 3) Core entities
- users: app user profile
- devices: physical BLE devices paired by user
- posture_sessions: each tracking session (start/end, sensitivity, calibration)
- posture_samples: high-frequency sample table (score + angles + state)
- posture_daily_stats: pre-aggregated metrics for fast dashboard
- exercise_logs: optional exercise completion history

## 4) Why this shape
- Reports page already depends on timestamped score/state samples.
- Session table allows easier debugging (which calibration/sensitivity generated which data).
- Daily aggregates reduce expensive scans over raw sample rows.

## 5) Retention
- Raw `posture_samples`: keep 90 days
- Daily aggregates: keep forever (or 2 years)
- Optional: move old raw data to cold storage before delete

## 6) Minimum indexes
- posture_samples(user_id, measured_at desc)
- posture_samples(session_id, measured_at)
- posture_sessions(user_id, started_at desc)
- posture_daily_stats(user_id, day)

## 7) App migration from current SharedPreferences
1. Keep current local storage working as fallback.
2. Add SQLite tables mirroring `posture_sessions` + `posture_samples`.
3. Write new samples to SQLite first.
4. Run one-time migration: load existing `metrics.posture.samples.v1` and insert.
5. Add sync worker to push unsynced rows to cloud.

## 8) Notes for current code
- Current sample model already has: `ts`, `score`, `state`.
- Consider adding `pitch`, `roll`, `sensitivity`, `device_id` to improve analytics.
- Keep sample cadence stable (currently every 30s persistence) so reports stay consistent.
