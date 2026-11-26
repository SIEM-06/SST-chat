-- =============================================================================
-- NØLL CHAT: reference Supabase schema
-- Run this once in a FRESH Supabase project (SQL Editor → New query → Run).
-- It creates the tables, Row Level Security policies, the realtime publication
-- and the storage bucket that index.html expects.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  username       text not null unique check (char_length(username) between 2 and 32),
  role           text not null default 'member' check (role in ('member', 'admin')),
  banned         boolean not null default false,
  avatar_color   text,
  accent         text,
  bio            text,
  status         text not null default 'online',
  custom_status  text,
  created_at     timestamptz not null default now()
);

create table if not exists public.channels (
  id           bigint generated always as identity primary key,
  name         text not null unique,
  description  text,
  created_at   timestamptz not null default now()
);

create table if not exists public.messages (
  id               bigint generated always as identity primary key,
  channel_id       bigint not null references public.channels (id) on delete cascade,
  user_id          uuid not null references public.profiles (id) on delete cascade,
  username         text not null,
  content          text,
  attachment_url   text,
  attachment_type  text,
  reply_to         bigint references public.messages (id) on delete set null,
  reply_username   text,
  reply_excerpt    text,
  created_at       timestamptz not null default now(),
  edited_at        timestamptz,
  constraint message_not_empty check (content is not null or attachment_url is not null)
);
create index if not exists messages_channel_created_idx on public.messages (channel_id, created_at desc);

create table if not exists public.reactions (
  id          bigint generated always as identity primary key,
  message_id  bigint not null references public.messages (id) on delete cascade,
  channel_id  bigint not null references public.channels (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  username    text not null,
  emoji       text not null,
  created_at  timestamptz not null default now(),
  unique (message_id, user_id, emoji)
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and not banned);
$$;

-- Regular users must not be able to promote themselves or lift their own ban.
create or replace function public.protect_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- auth.uid() is null for the SQL editor / service role, so those stay unrestricted.
  if auth.uid() is not null and not public.is_admin() then
    new.role   := old.role;
    new.banned := old.banned;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_privileges on public.profiles;
create trigger protect_profile_privileges
  before update on public.profiles
  for each row execute function public.protect_profile_privileges();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles  enable row level security;
alter table public.channels  enable row level security;
alter table public.messages  enable row level security;
alter table public.reactions enable row level security;

-- profiles
create policy "profiles: read (signed in)"   on public.profiles for select to authenticated using (true);
create policy "profiles: create own"         on public.profiles for insert to authenticated
  with check (id = auth.uid() and role = 'member' and banned = false);
create policy "profiles: update own / admin" on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin());

-- channels (everyone reads, only admins manage)
create policy "channels: read (signed in)"   on public.channels for select to authenticated using (true);
create policy "channels: admin insert"       on public.channels for insert to authenticated with check (public.is_admin());
create policy "channels: admin update"       on public.channels for update to authenticated using (public.is_admin());
create policy "channels: admin delete"       on public.channels for delete to authenticated using (public.is_admin());

-- messages
create policy "messages: read (signed in)"   on public.messages for select to authenticated using (true);
create policy "messages: send (not banned)"  on public.messages for insert to authenticated
  with check (user_id = auth.uid() and public.is_active_user());
create policy "messages: edit own"           on public.messages for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "messages: delete own / admin" on public.messages for delete to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- reactions
create policy "reactions: read (signed in)"  on public.reactions for select to authenticated using (true);
create policy "reactions: add (not banned)"  on public.reactions for insert to authenticated
  with check (user_id = auth.uid() and public.is_active_user());
create policy "reactions: remove own / admin"        on public.reactions for delete to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- Realtime (postgres_changes feeds used by the client)
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.profiles, public.channels, public.messages, public.reactions;

-- ---------------------------------------------------------------------------
-- Storage: public bucket for message attachments
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', true)
on conflict (id) do nothing;

create policy "attachments: upload (signed in)" on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments');
create policy "attachments: read (public)"      on storage.objects for select
  using (bucket_id = 'attachments');

-- ---------------------------------------------------------------------------
-- Seed: a default channel
-- ---------------------------------------------------------------------------
insert into public.channels (name, description)
values ('genel', 'General chat')
on conflict (name) do nothing;

-- To make yourself admin after signing up, run this in the SQL editor:
--   update public.profiles set role = 'admin' where username = 'YOUR_USERNAME';
