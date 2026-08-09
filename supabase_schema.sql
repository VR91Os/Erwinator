-- Kompletter Aufbau (räumt vorher alles Bisherige auf, kann beliebig oft
-- ausgeführt werden).

drop table if exists project_members cascade;
drop table if exists shared_projects cascade;
drop function if exists is_project_owner(uuid);
drop function if exists is_approved_member(uuid);

create table shared_projects (
  id uuid primary key default gen_random_uuid(),
  local_project_id text not null,
  owner_id uuid not null references auth.users(id),
  data jsonb not null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references shared_projects(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  display_name text not null,
  kurzzeichen text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  invited_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (project_id, user_id)
);

alter table shared_projects enable row level security;
alter table project_members enable row level security;

-- SECURITY DEFINER-Funktionen: brechen die zirkuläre Abhängigkeit auf, die
-- entsteht, weil shared_projects-Policies project_members lesen müssen und
-- umgekehrt (sonst "infinite recursion detected in policy").
create or replace function is_project_owner(pid uuid) returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from shared_projects where id = pid and owner_id = auth.uid()
  );
$$;

create or replace function is_approved_member(pid uuid) returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from project_members
    where project_id = pid and user_id = auth.uid() and status = 'approved'
  );
$$;

create policy "owner full access" on shared_projects
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "members read/write" on shared_projects
  for all using (is_approved_member(id));

create policy "anyone can request to join" on project_members
  for insert with check (user_id = auth.uid());

create policy "see own or owner sees all" on project_members
  for select using (user_id = auth.uid() or is_project_owner(project_id));

create policy "owner can update status" on project_members
  for update using (is_project_owner(project_id));

-- Realtime aktivieren, damit Beitrittsanfragen und Projekt-Updates live
-- ankommen (ohne manuelles Neuladen).
alter publication supabase_realtime add table shared_projects, project_members;
