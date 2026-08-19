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
  for all using (is_approved_member(id))
  with check (is_approved_member(id));

-- Postgres RLS "with check" sieht nur die NEUE Zeile, nicht die alte - ein
-- Vergleich wie "owner_id = shared_projects.owner_id" wäre eine Tautologie
-- (vergleicht die neue Spalte mit sich selbst) und würde eine Übernahme des
-- Projekts durch ein einfaches Mitglied per UPDATE owner_id NICHT
-- verhindern. Stattdessen die Spalte owner_id per Spalten-Rechten komplett
-- vor UPDATE schützen: die App aktualisiert ohnehin nur data/updated_at
-- (siehe sharing_service.dart pushUpdate), owner_id ändert sich nach dem
-- Anlegen nie.
revoke update on shared_projects from authenticated;
grant update (data, updated_at) on shared_projects to authenticated;

create policy "anyone can request to join" on project_members
  for insert with check (user_id = auth.uid());

create policy "see own or owner sees all" on project_members
  for select using (user_id = auth.uid() or is_project_owner(project_id));

create policy "owner can update status" on project_members
  for update using (is_project_owner(project_id));

-- Erlaubt einer abgelehnten Person, per erneuter Beitrittsanfrage
-- (upsert in requestToJoin) ihre eigene Zeile auf "pending" zurückzusetzen.
-- "with check" verhindert dabei eine Selbst-Genehmigung (status muss
-- "pending" bleiben) - nur der Owner darf auf "approved"/"rejected" setzen.
create policy "member can re-request after rejection" on project_members
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and status = 'pending');

-- Realtime aktivieren, damit Beitrittsanfragen und Projekt-Updates live
-- ankommen (ohne manuelles Neuladen).
alter publication supabase_realtime add table shared_projects, project_members;
