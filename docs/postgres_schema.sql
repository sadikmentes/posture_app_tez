-- posture_app baseline schema (PostgreSQL)
-- Run in a migration tool (dbmate, sqitch, Supabase migration, etc.)

create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists user_health_profiles (
  user_id uuid primary key references users(id) on delete cascade,
  full_name text not null,
  age int not null check (age between 5 and 120),
  gender text not null,
  height_cm double precision not null check (height_cm between 80 and 230),
  weight_kg double precision not null check (weight_kg between 20 and 250),
  occupation text,
  sitting_hours_per_day double precision not null default 0
    check (sitting_hours_per_day between 0 and 24),
  computer_hours_per_day double precision not null default 0
    check (computer_hours_per_day between 0 and 24),
  has_posture_condition_history boolean not null default false,
  posture_conditions jsonb not null default '[]'::jsonb,
  has_surgery_history boolean not null default false,
  surgery_areas jsonb not null default '[]'::jsonb,
  has_regular_pain boolean not null default false,
  pain_areas jsonb not null default '[]'::jsonb,
  pain_severity double precision not null default 0
    check (pain_severity between 0 and 10),
  weekly_exercise_frequency text not null,
  usage_goals jsonb not null default '[]'::jsonb,
  risk_level text not null check (risk_level in ('low', 'medium', 'high')),
  raw_profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  ble_name text,
  ble_identifier text,
  firmware_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create table if not exists posture_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  device_id uuid references devices(id) on delete set null,
  sensitivity text not null check (sensitivity in ('strict', 'balanced', 'relaxed')),
  calibration_pitch_offset double precision,
  calibration_roll_offset double precision,
  started_at timestamptz not null,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists posture_samples (
  id bigserial primary key,
  user_id uuid not null references users(id) on delete cascade,
  session_id uuid references posture_sessions(id) on delete set null,
  measured_at timestamptz not null,
  pitch_deg double precision,
  roll_deg double precision,
  score smallint not null check (score between 0 and 100),
  posture_state smallint not null check (posture_state between 0 and 3),
  risk_load double precision,
  severe_evidence double precision,
  created_at timestamptz not null default now()
);

create table if not exists posture_daily_stats (
  user_id uuid not null references users(id) on delete cascade,
  day date not null,
  avg_score smallint not null check (avg_score between 0 and 100),
  tracking_minutes integer not null default 0,
  bad_posture_minutes integer not null default 0,
  break_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

create table if not exists exercise_logs (
  id bigserial primary key,
  user_id uuid not null references users(id) on delete cascade,
  exercise_code text not null,
  duration_seconds integer,
  completed_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_posture_samples_user_time
  on posture_samples (user_id, measured_at desc);

create index if not exists idx_posture_samples_session_time
  on posture_samples (session_id, measured_at);

create index if not exists idx_posture_sessions_user_start
  on posture_sessions (user_id, started_at desc);

create index if not exists idx_devices_user
  on devices (user_id);

create index if not exists idx_health_profiles_risk
  on user_health_profiles (risk_level);

-- optional retention helper
-- delete from posture_samples where measured_at < now() - interval '90 days';
