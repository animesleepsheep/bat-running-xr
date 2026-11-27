\set ON_ERROR_STOP on
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select set_config('request.jwt.claims','{"is_anonymous":false}',false);
select public.br_xr_submit('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','control_practice',7,'quest3');
select public.br_xr_submit('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','control_practice',7,'quest3');
do $$ begin
 if (public.br_xr_profile()->>'sessions')::int <> 1 or (public.br_xr_profile()->>'selections')::int <> 7 then raise exception 'dedupe failed'; end if;
 begin
   insert into public.br_xr_events(user_id,event_id,activity,score,platform) values('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','control_practice',2,'focus3');
   raise exception 'spoof allowed';
 exception when insufficient_privilege then null; end;
 begin
   perform public.br_xr_submit('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','control_practice',-1,'quest3');
   raise exception 'invalid score allowed';
 exception when check_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ begin
 if (select count(*) from public.br_xr_events) <> 0 then raise exception 'cross-user leakage'; end if;
 if (public.br_xr_profile()->>'sessions')::int <> 0 then raise exception 'profile leakage'; end if;
end $$;
select public.br_xr_submit('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','control_practice',3,'focus3');
do $$ begin if (public.br_xr_profile()->>'selections')::int <> 3 then raise exception 'wrong account aggregate'; end if; end $$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select set_config('request.jwt.claims','{"is_anonymous":true}',false);
do $$ begin
 if (select count(*) from public.br_xr_events) <> 0 then raise exception 'anonymous auth leakage'; end if;
 begin
  perform public.br_xr_submit('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','control_practice',2,'web');
  raise exception 'anonymous insert allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set role anon;
do $$ begin
 begin perform public.br_xr_profile(); raise exception 'anon rpc allowed'; exception when insufficient_privilege then null; end;
 begin perform count(*) from public.br_xr_events; raise exception 'anon table read allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'XR004_RLS_PASS: dedupe, cross-account read, spoof, invalid score, anonymous and unauthenticated denial' as result;
