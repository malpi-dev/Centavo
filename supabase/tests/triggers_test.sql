-- Trigger, constraint and cascade tests for schema "centavo".
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- Fixtures run as postgres (RLS bypassed); user_id is always explicit.
insert into auth.users (id, email, aud, role) values
  ('a0000000-0000-4000-8000-00000000000a', 'a@centavo.test', 'authenticated', 'authenticated');

insert into centavo.categories (user_id, id, name, type, icon, color, created_at, updated_at) values
  ('a0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000e1', 'Spend', 'expense', 'food', 4293284096,
   '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
  ('a0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a1', 'Earn', 'income', 'salary', 4281236786,
   '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');

-- ---------------------------------------------------------------- keep_newest (last-write-wins)
update centavo.categories set name = 'Stale', updated_at = '2025-12-31T00:00:00Z'
where id = 'c0000000-0000-4000-8000-0000000000e1';
select is((select name from centavo.categories where id = 'c0000000-0000-4000-8000-0000000000e1'), 'Spend',
  'keep_newest: an older updated_at is ignored');

update centavo.categories set name = 'Fresh', updated_at = '2026-02-01T00:00:00Z'
where id = 'c0000000-0000-4000-8000-0000000000e1';
select is((select name from centavo.categories where id = 'c0000000-0000-4000-8000-0000000000e1'), 'Fresh',
  'keep_newest: a newer updated_at is applied');

-- ---------------------------------------------------------------- set_synced_at
insert into centavo.transactions (id, user_id, category_id, type, amount_minor, occurred_on, created_at, updated_at, synced_at)
values ('d0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a',
        'c0000000-0000-4000-8000-0000000000e1', 'expense', 500, '2026-01-10',
        '2026-01-10T12:00:00Z', '2026-01-10T12:00:00Z', '2000-01-01T00:00:00Z');
select isnt((select synced_at from centavo.transactions where id = 'd0000000-0000-4000-8000-000000000001'),
  '2000-01-01T00:00:00Z'::timestamptz, 'set_synced_at: overwritten with server time on insert');

update centavo.transactions set synced_at = '2000-01-01T00:00:00Z', note = 'edited', updated_at = '2026-01-11T00:00:00Z'
where id = 'd0000000-0000-4000-8000-000000000001';
select isnt((select synced_at from centavo.transactions where id = 'd0000000-0000-4000-8000-000000000001'),
  '2000-01-01T00:00:00Z'::timestamptz, 'set_synced_at: refreshed on update');

-- ---------------------------------------------------------------- check_category_type
select throws_ok(
  $$insert into centavo.transactions (id, user_id, category_id, type, amount_minor, occurred_on, created_at, updated_at)
    values ('d0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-00000000000a',
            'c0000000-0000-4000-8000-0000000000e1', 'income', 100, '2026-01-10', now(), now())$$,
  '23514', null, 'check_category_type: income transaction on an expense category is rejected');

select throws_ok(
  $$insert into centavo.budgets (id, user_id, category_id, month, limit_minor, created_at, updated_at)
    values ('d0000000-0000-4000-8000-0000000000b1', 'a0000000-0000-4000-8000-00000000000a',
            'c0000000-0000-4000-8000-0000000000a1', '2026-01-01', 1000, now(), now())$$,
  '23514', null, 'check_category_type: budget on an income category is rejected');

-- ---------------------------------------------------------------- column checks
select throws_ok(
  $$insert into centavo.budgets (id, user_id, category_id, month, limit_minor, created_at, updated_at)
    values ('d0000000-0000-4000-8000-0000000000b2', 'a0000000-0000-4000-8000-00000000000a',
            'c0000000-0000-4000-8000-0000000000e1', '2026-01-15', 1000, now(), now())$$,
  '23514', null, 'month must be the first day of a month');

select throws_ok(
  $$insert into centavo.transactions (id, user_id, category_id, type, amount_minor, occurred_on, created_at, updated_at)
    values ('d0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-00000000000a',
            'c0000000-0000-4000-8000-0000000000e1', 'expense', 0, '2026-01-10', now(), now())$$,
  '23514', null, 'amount_minor = 0 is rejected');

select throws_ok(
  $$insert into centavo.categories (user_id, id, name, type, icon, color, created_at, updated_at)
    values ('a0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000e2', 'Neg', 'expense', 'x', -1, now(), now())$$,
  '23514', null, 'color = -1 is rejected');

-- ---------------------------------------------------------------- partial unique index on budgets
insert into centavo.budgets (id, user_id, category_id, month, limit_minor, created_at, updated_at)
values ('d0000000-0000-4000-8000-0000000000b3', 'a0000000-0000-4000-8000-00000000000a',
        'c0000000-0000-4000-8000-0000000000e1', '2026-01-01', 1000, now(), now());

select throws_ok(
  $$insert into centavo.budgets (id, user_id, category_id, month, limit_minor, created_at, updated_at)
    values ('d0000000-0000-4000-8000-0000000000b4', 'a0000000-0000-4000-8000-00000000000a',
            'c0000000-0000-4000-8000-0000000000e1', '2026-01-01', 2000, now(), now())$$,
  '23505', null, 'two active budgets for the same category and month are rejected');

select lives_ok(
  $$insert into centavo.budgets (id, user_id, category_id, month, limit_minor, created_at, updated_at, deleted_at)
    values ('d0000000-0000-4000-8000-0000000000b5', 'a0000000-0000-4000-8000-00000000000a',
            'c0000000-0000-4000-8000-0000000000e1', '2026-01-01', 2000, now(), now(), now())$$,
  'a soft-deleted budget for the same category and month is allowed');

-- ---------------------------------------------------------------- cascade
delete from centavo.categories where id = 'c0000000-0000-4000-8000-0000000000e1';
select is((select count(*)::int from centavo.transactions where category_id = 'c0000000-0000-4000-8000-0000000000e1'), 0,
  'deleting a category cascades to its transactions');
select is((select count(*)::int from centavo.budgets where category_id = 'c0000000-0000-4000-8000-0000000000e1'), 0,
  'deleting a category cascades to its budgets');

-- ---------------------------------------------------------------- ensure_profile requires a session
select throws_ok($$select centavo.ensure_profile('USD')$$, '28000', 'not authenticated',
  'ensure_profile without auth.uid() is rejected');

select * from finish();
rollback;
