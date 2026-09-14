#!/usr/bin/env python3
"""Run migrations and SQL behavior tests in a disposable local PostgreSQL cluster.

Requires initdb, pg_ctl and psql on PATH. Auth is a minimal local schema, not a
replacement for hosted Supabase Auth/PostgREST integration checks.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs).stdout


def main():
    with tempfile.TemporaryDirectory(prefix="curtaincall-pg-") as temporary:
        directory = Path(temporary)
        data = directory / "data"
        run("initdb", "-D", str(data), "-A", "trust", "--no-locale", "-E", "UTF8")
        run("pg_ctl", "-D", str(data), "-l", str(directory / "server.log"), "-o",
            f"-k {directory} -h '' -p 55473", "-w", "start")
        args = ["psql", "-X", "-h", str(directory), "-p", "55473", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-At"]

        def sql(query):
            return run(*args, input=query).strip()

        try:
            sql("""
                create role anon;
                create role authenticated;
                create role service_role bypassrls;
                create schema auth;
                grant usage on schema auth to anon, authenticated, service_role;
                create table auth.users (
                  id uuid primary key, email text, email_confirmed_at timestamptz,
                  raw_user_meta_data jsonb, is_anonymous boolean default false
                );
                create function auth.uid() returns uuid language sql stable as
                  $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
            """)
            for migration in sorted((ROOT / "supabase/migrations").glob("*.sql")):
                sql(migration.read_text())
            for test in sorted((ROOT / "supabase/tests").glob("*.sql")):
                sql(test.read_text())
                print(f"PASS {test.name}", flush=True)
            concurrency_test(sql, args)
        finally:
            run("pg_ctl", "-D", str(data), "-m", "immediate", "-w", "stop")


def concurrency_test(sql, args):
    host, guest, third, performance, session = [str(uuid.uuid4()) for _ in range(5)]
    sql(f"""
      insert into auth.users(id,email,email_confirmed_at) values
      ('{host}','host@example.invalid',now()), ('{guest}','guest@example.invalid',now()),
      ('{third}','third@example.invalid',now());
      insert into public.performances(id,title,start_date,end_date)
      values('{performance}','Concurrent admission',current_date,current_date);
      insert into public.performance_sessions(id,performance_id,starts_at,ends_at,schedule_source)
      values('{session}','{performance}',now(),now()+interval '2 hours','operator');
    """)
    room = sql(f"""select set_config('request.jwt.claim.sub','{host}',false);
        set role authenticated;
        select public.room_command('create', p_session_id=>'{session}',p_title=>'Last slot',p_capacity=>2);
    """).splitlines()[-1]
    # Hold the room lock until both client transactions are waiting on it.
    lock = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    lock.stdin.write(f"begin; select id from public.rooms where id='{room}' for update;\n")
    lock.stdin.flush()
    clients = []
    try:
        deadline = time.monotonic() + 10
        while sql(f"select count(*) from pg_stat_activity where pid <> pg_backend_pid() and state='idle in transaction' and query like '%{room}%' ") == "0":
            if time.monotonic() > deadline:
                raise AssertionError("Room lock was not acquired")
            time.sleep(0.02)
        for actor in (guest, third):
            client = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            client.stdin.write(f"select set_config('request.jwt.claim.sub','{actor}',false); set role authenticated; select public.room_command('join','{room}');\n")
            client.stdin.close()
            client.stdin = None
            clients.append(client)
        while int(sql("select count(*) from pg_stat_activity where wait_event_type='Lock' and query like '%room_command%'")) < 2:
            if time.monotonic() > deadline:
                raise AssertionError("Both admission transactions did not contend for the lock")
            time.sleep(0.02)
        lock.stdin.write("commit;\n")
        lock.stdin.close()
        lock.stdin = None
        lock.communicate(timeout=10)
        results = [(client, client.communicate(timeout=10)) for client in clients]
        assert sum(client.returncode == 0 for client, _ in results) == 1, results
        assert sum("ROOM_FULL" in output[1] for _, output in results) == 1, results
        assert sql(f"select member_count from public.rooms where id='{room}'") == "2"
        assert sql(f"select count(*) from public.room_members where room_id='{room}' and status='active'") == "2"
        print("PASS concurrent last-slot admission (two contending transactions)", flush=True)
    finally:
        for process in [lock, *clients]:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)


if __name__ == "__main__":
    main()
