create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table private.member_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null,
  adult_verified boolean not null default false,
  suspended boolean not null default false
);
alter table private.member_profiles enable row level security;

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.performance_sessions(id) on delete restrict,
  host_user_id uuid not null references auth.users(id) on delete restrict,
  host_nickname text not null,
  title text not null check (length(btrim(title)) between 1 and 80),
  description text not null default '' check (length(description) <= 1000),
  category text not null check (category in ('meal', 'cafe', 'drinking')),
  adult_only boolean not null,
  capacity integer not null check (capacity between 2 and 10),
  member_count integer not null default 1 check (member_count between 0 and capacity),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (category <> 'drinking' or adult_only)
);
create index rooms_session_idx on public.rooms(session_id, created_at, id);
create index rooms_host_idx on public.rooms(host_user_id);
create index rooms_expiry_idx on public.rooms(expires_at);

create table public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete restrict,
  nickname text not null,
  status text not null default 'active' check (status in ('active', 'left', 'kicked')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);
create index room_members_user_idx on public.room_members(user_id, status, room_id);
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
revoke all on public.rooms, public.room_members from anon, authenticated;
grant select on public.rooms to anon, authenticated;
grant select on public.room_members to authenticated;
grant all on public.rooms, public.room_members to service_role;

create function private.is_room_member(p_room_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.room_members m
    join public.rooms r on r.id = m.room_id
    join auth.users u on u.id = m.user_id
    join private.member_profiles p on p.user_id = m.user_id
    where m.room_id = p_room_id and m.user_id = (select auth.uid())
      and m.status = 'active' and r.member_count > 0 and r.expires_at > now()
      and not p.suspended and u.email_confirmed_at is not null
      and not coalesce(u.is_anonymous, false)
  );
$$;
revoke all on function private.is_room_member(uuid) from public, anon;
grant execute on function private.is_room_member(uuid) to authenticated;

create policy rooms_public_read on public.rooms for select to anon, authenticated
using (member_count > 0 and expires_at > now());
create policy members_participant_read on public.room_members for select to authenticated
using (private.is_room_member(room_id));

create function private.require_actor() returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_nickname text;
begin
  select left(coalesce(nullif(btrim(raw_user_meta_data->>'nickname'), ''), '관객'), 30)
    into v_nickname from auth.users
    where id = v_actor and email_confirmed_at is not null and not coalesce(is_anonymous, false);
  if not found then raise exception 'AUTH_REQUIRED'; end if;
  insert into private.member_profiles(user_id, nickname) values (v_actor, v_nickname)
    on conflict (user_id) do nothing;
  if exists(select 1 from private.member_profiles where user_id = v_actor and suspended) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return v_actor;
end $$;
revoke all on function private.require_actor() from public, anon, authenticated;

create function private.room_command(
  p_action text, p_room_id uuid default null, p_session_id uuid default null,
  p_title text default null, p_description text default '', p_category text default 'cafe',
  p_adult_only boolean default false, p_capacity integer default 2, p_target_id uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := private.require_actor();
  v_room public.rooms%rowtype;
  v_session public.performance_sessions%rowtype;
  v_profile private.member_profiles%rowtype;
  v_status text;
  v_expires timestamptz;
  v_adult boolean;
begin
  select * into strict v_profile from private.member_profiles where user_id = v_actor;
  if p_action in ('create', 'update') then
    if p_title is null or length(btrim(p_title)) not between 1 and 80
       or p_description is null or length(p_description) > 1000
       or p_capacity is null or p_capacity not between 2 and 10 then
      raise exception 'INVALID_ROOM';
    end if;
  end if;
  if p_action = 'create' then
    select * into v_session from public.performance_sessions where id = p_session_id for share;
    if not found or v_session.ends_at is null then raise exception 'SCHEDULE_UNAVAILABLE'; end if;
    v_expires := (((v_session.starts_at at time zone 'Asia/Seoul')::date + interval '1 month') at time zone 'Asia/Seoul');
    if now() > v_session.ends_at + interval '24 hours' or now() >= v_expires then
      raise exception 'CREATION_DEADLINE_PASSED';
    end if;
    if p_category is null or p_category not in ('meal', 'cafe', 'drinking') or p_adult_only is null then
      raise exception 'INVALID_ROOM';
    end if;
    v_adult := p_adult_only or p_category = 'drinking';
    if v_adult and not v_profile.adult_verified then raise exception 'ADULT_VERIFICATION_REQUIRED'; end if;
    insert into public.rooms(session_id, host_user_id, host_nickname, title, description, category, adult_only, capacity, expires_at)
    values(p_session_id, v_actor, v_profile.nickname, btrim(p_title), btrim(p_description), p_category, v_adult, p_capacity, v_expires)
    returning * into v_room;
    insert into public.room_members(room_id, user_id, nickname) values(v_room.id, v_actor, v_profile.nickname);
    return v_room.id;
  end if;

  -- Every capacity/membership/host mutation acquires this same lock first.
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.member_count = 0 or now() >= v_room.expires_at then
    raise exception 'ROOM_UNAVAILABLE';
  end if;
  select status into v_status from public.room_members where room_id = p_room_id and user_id = v_actor;
  if p_action = 'join' then
    if v_status = 'kicked' then raise exception 'ROOM_KICKED'; end if;
    if v_status = 'active' then return p_room_id; end if;
    if v_room.adult_only and not v_profile.adult_verified then raise exception 'ADULT_VERIFICATION_REQUIRED'; end if;
    if v_room.member_count >= v_room.capacity then raise exception 'ROOM_FULL'; end if;
    insert into public.room_members(room_id, user_id, nickname) values(p_room_id, v_actor, v_profile.nickname)
      on conflict (room_id, user_id) do update set status = 'active', joined_at = now(), nickname = excluded.nickname;
    update public.rooms set member_count = member_count + 1 where id = p_room_id;
    return p_room_id;
  end if;
  if p_action = 'leave' and v_status = 'left' then return p_room_id; end if;
  if v_status is distinct from 'active' then raise exception 'ROOM_ACCESS_DENIED'; end if;
  if p_action = 'leave' then
    if v_room.host_user_id = v_actor and v_room.member_count > 1 then raise exception 'HOST_TRANSFER_REQUIRED'; end if;
    update public.room_members set status = 'left' where room_id = p_room_id and user_id = v_actor;
    update public.rooms set member_count = member_count - 1 where id = p_room_id;
  elsif p_action in ('kick', 'transfer', 'update') then
    if v_room.host_user_id <> v_actor then raise exception 'HOST_REQUIRED'; end if;
    if p_action = 'update' then
      if p_capacity < v_room.member_count then raise exception 'CAPACITY_BELOW_MEMBERS'; end if;
      update public.rooms set title = btrim(p_title), description = btrim(p_description), capacity = p_capacity where id = p_room_id;
    else
      if p_target_id is null or p_target_id = v_actor then raise exception 'INVALID_TARGET'; end if;
      if not exists(select 1 from public.room_members where room_id = p_room_id and user_id = p_target_id and status = 'active') then
        raise exception 'INVALID_TARGET';
      end if;
      if p_action = 'kick' then
        update public.room_members set status = 'kicked' where room_id = p_room_id and user_id = p_target_id;
        update public.rooms set member_count = member_count - 1 where id = p_room_id;
      else
        if not exists(select 1 from private.member_profiles p join auth.users u on u.id = p.user_id
            where p.user_id = p_target_id and not p.suspended and u.email_confirmed_at is not null
              and (not v_room.adult_only or p.adult_verified)) then raise exception 'INVALID_TARGET'; end if;
        update public.rooms set host_user_id = p_target_id,
          host_nickname = (select nickname from public.room_members where room_id = p_room_id and user_id = p_target_id)
          where id = p_room_id;
      end if;
    end if;
  else raise exception 'INVALID_ACTION';
  end if;
  return p_room_id;
end $$;
revoke all on function private.room_command(text,uuid,uuid,text,text,text,boolean,integer,uuid) from public, anon;
grant execute on function private.room_command(text,uuid,uuid,text,text,text,boolean,integer,uuid) to authenticated;

-- Exposed wrapper keeps privileged implementation in an unexposed schema.
create function public.room_command(
  p_action text, p_room_id uuid default null, p_session_id uuid default null,
  p_title text default null, p_description text default '', p_category text default 'cafe',
  p_adult_only boolean default false, p_capacity integer default 2, p_target_id uuid default null
) returns uuid language sql security invoker set search_path = '' as $$
  select private.room_command(p_action, p_room_id, p_session_id, p_title, p_description, p_category, p_adult_only, p_capacity, p_target_id);
$$;
revoke all on function public.room_command(text,uuid,uuid,text,text,text,boolean,integer,uuid) from public, anon;
grant execute on function public.room_command(text,uuid,uuid,text,text,text,boolean,integer,uuid) to authenticated;
