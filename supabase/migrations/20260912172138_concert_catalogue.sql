create table public.performances (
    id uuid primary key default gen_random_uuid(),
    kopis_id text unique,
    title text not null check (length(btrim(title)) between 1 and 300),
    poster_url text,
    venue text,
    region text,
    start_date date not null,
    end_date date not null check (end_date >= start_date),
    description text,
    source text not null default 'operator' check (source in ('operator', 'kopis')),
    synced_at timestamptz,
    created_at timestamptz not null default now()
);

create table public.performance_sessions (
    id uuid primary key default gen_random_uuid(),
    performance_id uuid not null references public.performances(id) on delete restrict,
    starts_at timestamptz not null,
    ends_at timestamptz check (ends_at > starts_at),
    schedule_source text not null check (schedule_source in ('operator', 'kopis')),
    created_at timestamptz not null default now(),
    unique (performance_id, starts_at)
);

create index performances_date_id_idx on public.performances(start_date, id);
create index performances_region_date_idx on public.performances(region, start_date, id);

alter table public.performances enable row level security;
alter table public.performance_sessions enable row level security;
revoke all on public.performances, public.performance_sessions from anon, authenticated;
grant select on public.performances, public.performance_sessions to anon, authenticated;
grant all on public.performances, public.performance_sessions to service_role;
create policy catalogue_public_read on public.performances for select to anon, authenticated using (true);
create policy sessions_public_read on public.performance_sessions for select to anon, authenticated using (true);
