-- Fixtures never commit. Run via SQL editor or MCP execute_sql.
begin;
insert into public.performances (id, title, start_date, end_date)
values ('11111111-1111-1111-1111-111111111111', 'catalogue-access-test', '2026-09-13', '2026-09-14');
insert into public.performance_sessions (performance_id, starts_at, schedule_source)
values ('11111111-1111-1111-1111-111111111111', '2026-09-13T18:00:00+09:00', 'operator');
set local role anon;
do $$
begin
  if not exists (select 1 from public.performances where title = 'catalogue-access-test') then
    raise exception 'Public catalogue read failed';
  end if;
  if not exists (select 1 from public.performance_sessions where performance_id = '11111111-1111-1111-1111-111111111111' and ends_at is null) then
    raise exception 'Public session read or unknown end failed';
  end if;
  begin
    insert into public.performances(title, start_date, end_date) values ('forbidden', '2026-09-13', '2026-09-14');
    raise exception 'Anonymous insert incorrectly allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
set local role authenticated;
do $$
begin
  begin
    update public.performances set title = 'forbidden';
    raise exception 'Authenticated update incorrectly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.performance_sessions;
    raise exception 'Authenticated deletion incorrectly allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
