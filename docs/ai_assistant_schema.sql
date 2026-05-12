create extension if not exists "pgcrypto";

create table if not exists public.ai_chat_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'Postur Asistani',
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.ai_chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.ai_chat_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  safety_level text not null default 'general'
    check (safety_level in ('general', 'caution', 'urgent')),
  posture_context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_threads_user_time
  on public.ai_chat_threads (user_id, last_message_at desc);

create index if not exists idx_ai_messages_thread_time
  on public.ai_chat_messages (thread_id, created_at asc);


alter table public.ai_chat_threads enable row level security;
alter table public.ai_chat_messages enable row level security;

drop policy if exists "ai_threads_own_all" on public.ai_chat_threads;
drop policy if exists "ai_messages_own_all" on public.ai_chat_messages;

create policy "ai_threads_own_all"
on public.ai_chat_threads
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "ai_messages_own_all"
on public.ai_chat_messages
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
