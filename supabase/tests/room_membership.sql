-- Atomic membership acceptance test. All fixtures roll back.
begin;
do $$
<<test>>
declare
  host_id uuid := gen_random_uuid();
  guest_id uuid := gen_random_uuid();
  third_id uuid := gen_random_uuid();
  performance_id uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid();
  room_id uuid;
  actual_count integer;
begin
  insert into auth.users(id, email, email_confirmed_at, raw_user_meta_data)
  values (host_id, host_id || '@example.invalid', now(), '{"nickname":"Host"}'),
         (guest_id, guest_id || '@example.invalid', now(), '{"nickname":"Guest"}'),
         (third_id, third_id || '@example.invalid', now(), '{"nickname":"Third"}');
  insert into public.performances(id, title, start_date, end_date)
  values (performance_id, 'room-transaction-test', current_date, current_date + 1);
  insert into public.performance_sessions(id, performance_id, starts_at, ends_at, schedule_source)
  values (session_id, performance_id, now() + interval '1 hour', now() + interval '3 hours', 'operator');
  perform set_config('request.jwt.claim.sub', host_id::text, true);
  set local role authenticated;
  room_id := public.room_command('create', p_session_id => session_id, p_title => 'Test', p_capacity => 2);
  select member_count into actual_count from public.rooms where id = room_id;
  if actual_count <> 1 then raise exception 'Host must be first member'; end if;
  perform set_config('request.jwt.claim.sub', guest_id::text, true);
  perform public.room_command('join', room_id);
  perform public.room_command('join', room_id);
  select member_count into actual_count from public.rooms where id = room_id;
  if actual_count <> 2 then raise exception 'Repeated join duplicated membership'; end if;
  perform set_config('request.jwt.claim.sub', third_id::text, true);
  begin
    perform public.room_command('join', room_id);
    raise exception 'Full room admitted third member';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ROOM_FULL' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub', host_id::text, true);
  begin
    perform public.room_command('leave', room_id);
    raise exception 'Host left without transfer';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'HOST_TRANSFER_REQUIRED' then raise; end if;
  end;
  perform public.room_command('kick', room_id, p_target_id => guest_id);
  perform set_config('request.jwt.claim.sub', guest_id::text, true);
  begin
    perform public.room_command('join', room_id);
    raise exception 'Kicked member reentered';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ROOM_KICKED' then raise; end if;
  end;
  if exists(select 1 from public.room_members m where m.room_id = test.room_id) then
    raise exception 'Kicked member retained member-list access';
  end if;
  perform set_config('request.jwt.claim.sub', third_id::text, true);
  perform public.room_command('join', room_id);
  perform set_config('request.jwt.claim.sub', host_id::text, true);
  perform public.room_command('transfer', room_id, p_target_id => third_id);
  perform public.room_command('leave', room_id);
  perform set_config('request.jwt.claim.sub', third_id::text, true);
  perform public.room_command('leave', room_id);
  if exists(select 1 from public.rooms where id = room_id) then
    raise exception 'Empty room still listed';
  end if;
  begin
    perform public.room_command('join', room_id);
    raise exception 'Empty room reopened';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ROOM_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.room_command('create', p_session_id => session_id, p_title => 'Adults', p_category => 'drinking');
    raise exception 'Unverified adult created drinking room';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ADULT_VERIFICATION_REQUIRED' then raise; end if;
  end;
  reset role;
end $$;
rollback;
