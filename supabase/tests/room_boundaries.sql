begin;
do $$
declare
  actor uuid := gen_random_uuid(); performance uuid := gen_random_uuid();
  exact_session uuid := gen_random_uuid(); late_session uuid := gen_random_uuid();
  unknown_session uuid := gen_random_uuid(); room uuid; expiry timestamptz;
begin
  insert into auth.users(id,email,email_confirmed_at) values(actor,actor||'@example.invalid',now());
  insert into public.performances(id,title,start_date,end_date)
    values(performance,'boundary-test',current_date-2,current_date);
  insert into public.performance_sessions(id,performance_id,starts_at,ends_at,schedule_source) values
    (exact_session,performance,now()-interval '2 days',now()-interval '24 hours','operator'),
    (late_session,performance,now()-interval '3 days',now()-interval '24 hours 1 microsecond','operator'),
    (unknown_session,performance,now()+interval '1 hour',null,'operator');
  perform set_config('request.jwt.claim.sub',actor::text,true);
  set local role authenticated;
  room := public.room_command('create',p_session_id=>exact_session,p_title=>'Exact deadline');
  if room is null then raise exception 'Inclusive creation deadline rejected'; end if;
  select expires_at into expiry from public.rooms where id = room;
  if expiry <> (((now()-interval '2 days') at time zone 'Asia/Seoul')::date + interval '1 month') at time zone 'Asia/Seoul' then
    raise exception 'Expiry must be one Seoul calendar month after the session date';
  end if;
  begin
    perform public.room_command('create',p_session_id=>late_session,p_title=>'Too late');
    raise exception 'Late creation succeeded';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'CREATION_DEADLINE_PASSED' then raise; end if;
  end;
  begin
    perform public.room_command('create',p_session_id=>unknown_session,p_title=>'Unknown');
    raise exception 'Unknown end accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  reset role;
  update public.rooms set expires_at=now() where id=room;
  set local role authenticated;
  if exists(select 1 from public.rooms where id=room) then raise exception 'Expired room visible'; end if;
  if exists(select 1 from public.room_members where room_id=room) then raise exception 'Expired member list visible'; end if;
  begin
    perform public.room_command('join',room);
    raise exception 'Expired room admitted member';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ROOM_UNAVAILABLE' then raise; end if;
  end;
  reset role;
end $$;
rollback;
