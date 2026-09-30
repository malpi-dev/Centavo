-- LOCAL ONLY demo seed (never applied to the remote project: auth.users is shared between apps).
-- Mirrors the deterministic pattern of the in-app demo dataset (docs/implementation/fase-05-modo-demo.md §4.1).

-- ---------------------------------------------------------------- demo user
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new)
values ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-4000-8000-000000000001', 'authenticated',
  'authenticated', 'demo@centavo.test', '', now(), '{"provider":"email","providers":["email"]}', '{}',
  now(), now(), '', '', '', '')
on conflict (id) do nothing;

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
values (gen_random_uuid(), 'c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
  '{"sub":"c0000000-0000-4000-8000-000000000001","email":"demo@centavo.test","email_verified":true}',
  'email', now(), now(), now())
on conflict do nothing;

insert into centavo.profiles (id, currency_code)
values ('c0000000-0000-4000-8000-000000000001', 'USD');

-- ---------------------------------------------------------------- categories (same ids/colors as the Dart code)
with base as (
  select (date_trunc('month', current_date) - interval '2 months' + time '09:00') at time zone 'UTC' as created
)
insert into centavo.categories
  (user_id, id, name, type, icon, color, is_default, archived_at, created_at, updated_at)
select 'c0000000-0000-4000-8000-000000000001', c.id::uuid, c.name, c.type, c.icon, c.color, c.is_default,
       case when c.name = 'Old car'
            then (date_trunc('month', current_date) - interval '1 month' + time '12:00') at time zone 'UTC' end,
       b.created, b.created
from base b
cross join (values
  ('00000000-0000-4000-8000-000000000001', 'Food',          'expense', 'food',          4293284096, true),
  ('00000000-0000-4000-8000-000000000002', 'Transport',     'expense', 'transport',     4279592384, true),
  ('00000000-0000-4000-8000-000000000003', 'Home',          'expense', 'home',          4285353025, true),
  ('00000000-0000-4000-8000-000000000004', 'Health',        'expense', 'health',        4291176488, true),
  ('00000000-0000-4000-8000-000000000005', 'Entertainment', 'expense', 'entertainment', 4286259106, true),
  ('00000000-0000-4000-8000-000000000006', 'Shopping',      'expense', 'shopping',      4290910299, true),
  ('00000000-0000-4000-8000-000000000007', 'Other',         'expense', 'other',         4283723386, true),
  ('00000000-0000-4000-8000-000000000101', 'Salary',        'income',  'salary',        4281236786, true),
  ('00000000-0000-4000-8000-000000000102', 'Freelance',     'income',  'freelance',     4278221163, true),
  ('00000000-0000-4000-8000-000000000103', 'Other income',  'income',  'investments',   4281944491, true),
  ('00000000-0000-4000-8000-0000000000c1', 'Coffee',        'expense', 'coffee',        4290275630, false),
  ('00000000-0000-4000-8000-0000000000c2', 'Gym',           'expense', 'fitness',       4290214175, false),
  ('00000000-0000-4000-8000-0000000000c3', 'Old car',       'expense', 'car',           4283723386, false)
) as c (id, name, type, icon, color, is_default);

-- ---------------------------------------------------------------- transactions (M2, M1 and M0 up to today)
with months as (
  select m.offset_n, (date_trunc('month', current_date) - make_interval(months => m.offset_n))::date as month_start
  from (values (2), (1), (0)) as m (offset_n)
),
days as (
  select mo.offset_n, d::date as day
  from months mo
  cross join generate_series(mo.month_start, (mo.month_start + interval '1 month - 1 day')::date, interval '1 day') as d
  where d::date <= current_date
),
rules (day_of_month, only_offset, skip_offset, category_id, type, amount_minor, note) as (
  values
    (1,  null::int, null::int, '00000000-0000-4000-8000-000000000101'::uuid, 'income',  320000, 'Monthly salary'),
    (1,  null, null, '00000000-0000-4000-8000-000000000003', 'expense',  95000, 'Rent'),
    (1,  0,    null, '00000000-0000-4000-8000-0000000000c1', 'expense',    450, 'Latte'),
    (1,  0,    null, '00000000-0000-4000-8000-000000000005', 'expense',   1599, 'Streaming subscription'),
    (2,  null, null, '00000000-0000-4000-8000-000000000002', 'expense',   3500, 'Transit card top-up'),
    (9,  null, null, '00000000-0000-4000-8000-000000000002', 'expense',   3500, 'Transit card top-up'),
    (16, null, null, '00000000-0000-4000-8000-000000000002', 'expense',   3500, 'Transit card top-up'),
    (23, null, null, '00000000-0000-4000-8000-000000000002', 'expense',   3500, 'Transit card top-up'),
    (30, null, null, '00000000-0000-4000-8000-000000000002', 'expense',   3500, 'Transit card top-up'),
    (3,  null, null, '00000000-0000-4000-8000-000000000001', 'expense',   6240, 'Groceries'),
    (10, null, null, '00000000-0000-4000-8000-000000000001', 'expense',   4815, 'Groceries'),
    (17, null, null, '00000000-0000-4000-8000-000000000001', 'expense',   7190, 'Groceries'),
    (24, null, null, '00000000-0000-4000-8000-000000000001', 'expense',   5530, 'Groceries'),
    (5,  null, null, '00000000-0000-4000-8000-000000000004', 'expense',   3000, 'Pharmacy'),
    (6,  null, null, '00000000-0000-4000-8000-000000000002', 'expense',   4200, 'Fuel'),
    (20, null, null, '00000000-0000-4000-8000-000000000002', 'expense',   4200, 'Fuel'),
    (7,  null, null, '00000000-0000-4000-8000-000000000005', 'expense',   2400, 'Cinema'),
    (8,  null, null, '00000000-0000-4000-8000-0000000000c2', 'expense',   4500, 'Gym membership'),
    (11, 2,    null, '00000000-0000-4000-8000-0000000000c3', 'expense',  18000, 'Car service'),
    (12, null, null, '00000000-0000-4000-8000-000000000006', 'expense',   3999, 'Clothes'),
    (15, null, null, '00000000-0000-4000-8000-000000000102', 'income',   45000, 'Freelance project'),
    (18, null, null, '00000000-0000-4000-8000-000000000007', 'expense',   1500, 'Haircut'),
    (21, null, null, '00000000-0000-4000-8000-000000000005', 'expense',   5500, 'Concert'),
    (26, null, null, '00000000-0000-4000-8000-000000000006', 'expense',   2450, 'Home goods'),
    (27, 1,    null, '00000000-0000-4000-8000-000000000102', 'income',   28000, 'Logo design')
),
generated as (
  select d.offset_n, d.day, 0 as rule_order, r.category_id, r.type, r.amount_minor, r.note
  from days d join rules r
    on extract(day from d.day) = r.day_of_month and (r.only_offset is null or r.only_offset = d.offset_n)
  union all
  select d.offset_n, d.day, 1, '00000000-0000-4000-8000-0000000000c1'::uuid, 'expense',
         case when extract(day from d.day)::int % 2 = 1 then 420 else 375 end, 'Morning coffee'
  from days d
  where extract(isodow from d.day) between 1 and 5
),
numbered as (
  select g.*, row_number() over (partition by g.offset_n order by g.day, g.rule_order) as nnn
  from generated g
)
insert into centavo.transactions
  (id, user_id, category_id, type, amount_minor, occurred_on, note, created_at, updated_at)
select gen_random_uuid(), 'c0000000-0000-4000-8000-000000000001', n.category_id, n.type, n.amount_minor, n.day, n.note,
       (n.day + time '12:00' + make_interval(secs => n.nnn)) at time zone 'UTC',
       (n.day + time '12:00' + make_interval(secs => n.nnn)) at time zone 'UTC'
from numbered n;

-- ---------------------------------------------------------------- budgets
with months as (
  select m.offset_n, (date_trunc('month', current_date) - make_interval(months => m.offset_n))::date as month_start
  from (values (2), (1), (0)) as m (offset_n)
),
m0_spend as (
  select t.category_id, sum(t.amount_minor) as total
  from centavo.transactions t
  where t.user_id = 'c0000000-0000-4000-8000-000000000001'
    and t.occurred_on >= date_trunc('month', current_date)
    and t.category_id in ('00000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-0000000000c1')
  group by t.category_id
),
limits (category_id, past_limit) as (
  values
    ('00000000-0000-4000-8000-000000000001'::uuid, 60000),
    ('00000000-0000-4000-8000-000000000002', 15000),
    ('00000000-0000-4000-8000-000000000006', 20000),
    ('00000000-0000-4000-8000-000000000005', 12000),
    ('00000000-0000-4000-8000-0000000000c1', 8000)
)
insert into centavo.budgets (id, user_id, category_id, month, limit_minor, created_at, updated_at)
select gen_random_uuid(), 'c0000000-0000-4000-8000-000000000001', l.category_id, mo.month_start,
       case
         when mo.offset_n > 0 then l.past_limit
         -- Current month: Entertainment lands at ~90 % (warning) and Coffee at ~125 % (exceeded) on any day.
         when l.category_id = '00000000-0000-4000-8000-000000000005' then ceil(s.total * 100 / 90.0)::bigint
         when l.category_id = '00000000-0000-4000-8000-0000000000c1' then greatest(100, s.total * 80 / 100)
         else l.past_limit
       end,
       (date_trunc('month', mo.month_start) + time '09:00') at time zone 'UTC',
       (date_trunc('month', mo.month_start) + time '09:00') at time zone 'UTC'
from months mo
cross join limits l
left join m0_spend s on s.category_id = l.category_id;
