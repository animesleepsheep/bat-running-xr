-- BAT RUNNING XR only; apply to the explicitly selected project after review.
-- No existing application tables, auth providers or grants are modified.
begin;
create table public.br_xr_events (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  event_id uuid not null,
  activity text not null check (activity in ('control_practice')),
  score integer not null check (score between 1 and 10000),
  platform text not null check (platform in ('quest3','focus3','web','desktop')),
  recorded_at timestamptz not null default now(),
  primary key (user_id, event_id)
);
alter table public.br_xr_events enable row level security;
revoke all on public.br_xr_events from public, anon, authenticated;
grant select on public.br_xr_events to authenticated;
grant insert (event_id, activity, score, platform) on public.br_xr_events to authenticated;
create policy br_xr_read_own on public.br_xr_events for select to authenticated
using ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false');
create policy br_xr_insert_own on public.br_xr_events for insert to authenticated
with check ((select auth.uid()) = user_id and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false');
create index br_xr_events_recent_idx on public.br_xr_events(user_id, recorded_at desc);
create function public.br_xr_submit(p_event_id uuid, p_activity text, p_score integer, p_platform text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') <> 'false' then
    raise exception 'Account required' using errcode='42501';
  end if;
  insert into public.br_xr_events(event_id, activity, score, platform)
  values(p_event_id,p_activity,p_score,p_platform)
  on conflict(user_id,event_id) do nothing;
  return jsonb_build_object('accepted', true, 'event_id', p_event_id);
end;
$$;
create function public.br_xr_profile()
returns jsonb language sql stable security invoker set search_path = '' as $$
select jsonb_build_object(
 'sessions', count(*),
 'selections', coalesce(sum(score),0),
 'best', coalesce(max(score),0),
 'recent', coalesce((select jsonb_agg(to_jsonb(q) order by q.recorded_at desc) from
    (select activity, score, platform, recorded_at from public.br_xr_events
    where user_id=(select auth.uid()) order by recorded_at desc,event_id desc limit 10) q), '[]'::jsonb))
from public.br_xr_events where user_id=(select auth.uid())
$$;
revoke all on function public.br_xr_submit(uuid,text,integer,text) from public, anon, authenticated;
revoke all on function public.br_xr_profile() from public, anon, authenticated;
grant execute on function public.br_xr_submit(uuid,text,integer,text) to authenticated;
grant execute on function public.br_xr_profile() to authenticated;
commit;
