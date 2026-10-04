-- FixPose account-sync schema (PLANNING §2 / §4 SYNC_ENGINE)
-- Idempotent: safe to re-run. Applied via tools/sync_schema.ps1 (Management API).
--
-- Contract (mirrors lib/data/sync/server_payload.dart):
--   * every table is user-scoped with RLS `auth.uid() = user_id`
--   * `updated_at` (trigger-set) is the LWW watermark the client downloads
--   * account deletion cascades from auth.users

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- --- workout sessions (append-only history) -------------------------------
create table if not exists public.workout_sessions (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  workout_id text not null,
  plan_session_id text,
  started_at timestamptz not null,
  ended_at timestamptz,
  status text not null,
  exercises jsonb not null default '[]'::jsonb,
  rest jsonb not null default '[]'::jsonb,
  paused jsonb,
  duration_sec integer not null default 0,
  total_reps integer not null default 0,
  avg_cadence_rpm double precision not null default 0,
  form_accuracy_pct double precision not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists workout_sessions_user_idx on public.workout_sessions (user_id);

-- --- training plans -------------------------------------------------------
create table if not exists public.training_plans (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start timestamptz not null,
  source text not null,
  days jsonb not null default '[]'::jsonb,
  last_updated timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists training_plans_user_idx on public.training_plans (user_id);

-- --- meal entries ---------------------------------------------------------
create table if not exists public.meal_entries (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  date_key text not null,
  name text not null,
  calories integer not null,
  meal_type text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists meal_entries_user_day_idx on public.meal_entries (user_id, date_key);

-- --- meal target (one row per user) ---------------------------------------
create table if not exists public.meal_targets (
  user_id uuid not null primary key references auth.users (id) on delete cascade,
  daily_calories integer not null,
  updated_at timestamptz not null default now()
);

-- --- body metrics (one row per user per day) ------------------------------
create table if not exists public.body_metrics (
  user_id uuid not null references auth.users (id) on delete cascade,
  date_key text not null,
  weight_kg double precision not null,
  height_cm double precision,
  notes text,
  updated_at timestamptz not null default now(),
  primary key (user_id, date_key)
);

-- --- strike state (one row per user) --------------------------------------
create table if not exists public.strike_states (
  user_id uuid not null primary key references auth.users (id) on delete cascade,
  current_strike integer not null default 0,
  longest_strike integer not null default 0,
  last_active_date_key text not null,
  unlocked_tiers jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

-- --- chat messages --------------------------------------------------------
create table if not exists public.chat_messages (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null,
  content text not null,
  created_at timestamptz not null,
  context_ref text,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists chat_messages_user_idx on public.chat_messages (user_id);

-- --- account directory (who exists) --------------------------------------
-- Canonical email→user registry for check-user: one indexed exact lookup
-- instead of paging the GoTrue admin list (capped at 20 pages × 100 rows).
-- Written by the create-user edge action (and self-healed by check-user);
-- read service-role by check-user. Email is stored lowercased, matching
-- the edge function's normalization.
create table if not exists public.profiles (
  user_id uuid not null primary key references auth.users (id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_email_idx on public.profiles (lower(email));

-- --- updated_at triggers --------------------------------------------------
drop trigger if exists workout_sessions_updated_at on public.workout_sessions;
create trigger workout_sessions_updated_at before update on public.workout_sessions
  for each row execute function public.set_updated_at();
drop trigger if exists training_plans_updated_at on public.training_plans;
create trigger training_plans_updated_at before update on public.training_plans
  for each row execute function public.set_updated_at();
drop trigger if exists meal_entries_updated_at on public.meal_entries;
create trigger meal_entries_updated_at before update on public.meal_entries
  for each row execute function public.set_updated_at();
drop trigger if exists meal_targets_updated_at on public.meal_targets;
create trigger meal_targets_updated_at before update on public.meal_targets
  for each row execute function public.set_updated_at();
drop trigger if exists body_metrics_updated_at on public.body_metrics;
create trigger body_metrics_updated_at before update on public.body_metrics
  for each row execute function public.set_updated_at();
drop trigger if exists strike_states_updated_at on public.strike_states;
create trigger strike_states_updated_at before update on public.strike_states
  for each row execute function public.set_updated_at();
drop trigger if exists chat_messages_updated_at on public.chat_messages;
create trigger chat_messages_updated_at before update on public.chat_messages
  for each row execute function public.set_updated_at();

-- --- RLS: strictly account-scoped ----------------------------------------
alter table public.workout_sessions enable row level security;
drop policy if exists own_rows on public.workout_sessions;
create policy own_rows on public.workout_sessions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.training_plans enable row level security;
drop policy if exists own_rows on public.training_plans;
create policy own_rows on public.training_plans for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.meal_entries enable row level security;
drop policy if exists own_rows on public.meal_entries;
create policy own_rows on public.meal_entries for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.meal_targets enable row level security;
drop policy if exists own_rows on public.meal_targets;
create policy own_rows on public.meal_targets for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.body_metrics enable row level security;
drop policy if exists own_rows on public.body_metrics;
create policy own_rows on public.body_metrics for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.strike_states enable row level security;
drop policy if exists own_rows on public.strike_states;
create policy own_rows on public.strike_states for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.chat_messages enable row level security;
drop policy if exists own_rows on public.chat_messages;
create policy own_rows on public.chat_messages for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter table public.profiles enable row level security;
drop policy if exists own_rows on public.profiles;
create policy own_rows on public.profiles for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- --- explicit grants (defense in depth over default privileges) -----------
grant select, insert, update, delete on public.workout_sessions to authenticated;
grant select, insert, update, delete on public.training_plans to authenticated;
grant select, insert, update, delete on public.meal_entries to authenticated;
grant select, insert, update, delete on public.meal_targets to authenticated;
grant select, insert, update, delete on public.body_metrics to authenticated;
grant select, insert, update, delete on public.strike_states to authenticated;
grant select, insert, update, delete on public.chat_messages to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
