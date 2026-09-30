-- RLS and privilege tests for schema "centavo".
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- Fixtures (as postgres): two users.
insert into auth.users (id, email, aud, role) values
  ('a0000000-0000-4000-8000-00000000000a', 'a@centavo.test', 'authenticated', 'authenticated'),
  ('b0000000-0000-4000-8000-00000000000b', 'b@centavo.test', 'authenticated', 'authenticated');

-- ================================================================ user A
set local role authenticated;
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-00000000000a","role":"authenticated"}';

select is((select currency_code::text from centavo.ensure_profile('EUR')), 'EUR', 'A: ensure_profile creates the profile');
select is((select currency_code::text from centavo.ensure_profile('USD')), 'EUR', 'A: ensure_profile is idempotent');

-- user_id is omitted on purpose: the default auth.uid() must fill it.
insert into centavo.categories (id, name, type, icon, color, is_default, created_at, updated_at) values
  ('00000000-0000-4000-8000-000000000001', 'Food', 'expense', 'food', 4293284096, true, now(), now()),
  ('aaaaaaaa-0000-4000-8000-000000000001', 'A only', 'expense', 'other', 4283723386, false, now(), now());
insert into centavo.transactions (id, category_id, type, amount_minor, occurred_on, created_at, updated_at) values
  ('aaaaaaaa-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-000000000001', 'expense', 1000, current_date, now(), now());
insert into centavo.budgets (id, category_id, month, limit_minor, created_at, updated_at) values
  ('aaaaaaaa-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-000000000001',
   date_trunc('month', current_date)::date, 5000, now(), now());

select is((select count(*)::int from centavo.categories), 2, 'A: sees own categories');
select is((select count(*)::int from centavo.transactions), 1, 'A: sees own transactions');
select is((select user_id from centavo.transactions limit 1), 'a0000000-0000-4000-8000-00000000000a'::uuid,
  'A: user_id defaulted to auth.uid()');

-- ================================================================ user B
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b0000000-0000-4000-8000-00000000000b","role":"authenticated"}';

select is((select count(*)::int from centavo.categories), 0, 'B: sees no categories of A');
select is((select count(*)::int from centavo.transactions), 0, 'B: sees no transactions of A');
select is((select count(*)::int from centavo.budgets), 0, 'B: sees no budgets of A');
select is((select count(*)::int from centavo.profiles), 0, 'B: sees no profiles of A');

select lives_ok(
  $$insert into centavo.categories (id, name, type, icon, color, is_default, created_at, updated_at)
    values ('00000000-0000-4000-8000-000000000001', 'Food', 'expense', 'food', 4293284096, true, now(), now())$$,
  'B: can insert the same fixed default id as A (composite PK)');

select throws_ok(
  $$insert into centavo.categories (user_id, id, name, type, icon, color, created_at, updated_at)
    values ('a0000000-0000-4000-8000-00000000000a', 'bbbbbbbb-0000-4000-8000-000000000001', 'Spoof', 'expense', 'x', 1, now(), now())$$,
  '42501', null, 'B: cannot insert a row on behalf of A');

with u as (update centavo.categories set name = 'Hacked'
           where user_id = 'a0000000-0000-4000-8000-00000000000a' returning 1)
select is(count(*)::int, 0, 'B: update on A rows affects 0 rows') from u;

with d as (delete from centavo.transactions
           where user_id = 'a0000000-0000-4000-8000-00000000000a' returning 1)
select is(count(*)::int, 0, 'B: delete on A rows affects 0 rows') from d;

select throws_ok(
  $$insert into centavo.transactions (id, category_id, type, amount_minor, occurred_on, created_at, updated_at)
    values ('bbbbbbbb-0000-4000-8000-0000000000f1', 'aaaaaaaa-0000-4000-8000-000000000001', 'expense', 100, current_date, now(), now())$$,
  '23503', null, 'B: cannot point a transaction to the private category of A');

select throws_ok(
  $$insert into centavo.profiles (id, currency_code) values ('b0000000-0000-4000-8000-00000000000b', 'USD')$$,
  '42501', null, 'B: cannot insert into profiles directly');

select throws_ok(
  $$update centavo.profiles set created_at = now() where id = 'b0000000-0000-4000-8000-00000000000b'$$,
  '42501', null, 'B: cannot update profile columns other than currency_code');

-- ================================================================ anon
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';

select throws_ok($$select * from centavo.categories$$, '42501', null, 'anon: cannot select categories');
select throws_ok($$select centavo.ensure_profile('USD')$$, '42501', null, 'anon: cannot execute ensure_profile');

select * from finish();
rollback;
