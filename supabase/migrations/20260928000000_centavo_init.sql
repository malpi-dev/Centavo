-- Centavo backup schema. Touches ONLY schema "centavo" (docs/definicion.md §7).
-- Supabase is a backup target: the app never reads from here to render screens.

create schema if not exists centavo;
grant usage on schema centavo to authenticated, service_role;

-- ---------------------------------------------------------------- helper trigger functions

-- Keeps profiles.updated_at current (profiles are server-owned rows).
create or replace function centavo.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Last-write-wins: silently ignore an update whose client timestamp is older than the stored one.
create or replace function centavo.keep_newest() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.updated_at < old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

-- Server time of the last successful write.
create or replace function centavo.set_synced_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.synced_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- tables

create table centavo.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  currency_code char(3) not null check (currency_code ~ '^[A-Z]{3}$'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Composite PK: default categories use fixed ids shared by every user (see implementation log).
create table centavo.categories (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id          uuid not null,
  name        text not null check (char_length(name) between 1 and 30),
  type        text not null check (type in ('income', 'expense')),
  icon        text not null check (char_length(icon) between 1 and 40),
  color       bigint not null check (color between 0 and 4294967295),  -- ARGB does not fit in a signed integer
  is_default  boolean not null default false,
  archived_at timestamptz,
  deleted_at  timestamptz,
  created_at  timestamptz not null,
  updated_at  timestamptz not null,
  synced_at   timestamptz not null default now(),
  primary key (user_id, id)
);

create table centavo.transactions (
  id           uuid primary key,
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category_id  uuid not null,
  type         text not null check (type in ('income', 'expense')),
  amount_minor bigint not null check (amount_minor > 0),
  occurred_on  date not null,
  note         text check (note is null or char_length(note) <= 140),
  created_at   timestamptz not null,
  updated_at   timestamptz not null,
  deleted_at   timestamptz,
  synced_at    timestamptz not null default now(),
  -- A transaction can only point to a category of the SAME user.
  foreign key (user_id, category_id) references centavo.categories (user_id, id) on delete cascade
);

create table centavo.budgets (
  id          uuid primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category_id uuid not null,
  month       date not null check (month = date_trunc('month', month)::date),
  limit_minor bigint not null check (limit_minor > 0),
  created_at  timestamptz not null,
  updated_at  timestamptz not null,
  deleted_at  timestamptz,
  synced_at   timestamptz not null default now(),
  foreign key (user_id, category_id) references centavo.categories (user_id, id) on delete cascade
);

-- One active budget per category and month.
create unique index budgets_active_category_month_idx
  on centavo.budgets (user_id, category_id, month) where deleted_at is null;

-- Ordered restores and "changed since" queries.
create index categories_user_updated_idx   on centavo.categories (user_id, updated_at);
create index transactions_user_updated_idx on centavo.transactions (user_id, updated_at);
create index budgets_user_updated_idx      on centavo.budgets (user_id, updated_at);
-- Foreign-key lookups.
create index transactions_user_category_idx on centavo.transactions (user_id, category_id);
create index budgets_user_category_idx      on centavo.budgets (user_id, category_id);

-- ---------------------------------------------------------------- business-rule triggers

-- Transactions must match their category type; budgets only on expense categories.
create or replace function centavo.check_category_type() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_type text;
begin
  select c.type into v_type
  from centavo.categories c
  where c.user_id = new.user_id and c.id = new.category_id;

  if v_type is null then
    return new;  -- the foreign key reports the missing category
  end if;
  -- Nested ifs: budgets has no "type" column, so NEW.type must only be touched for transactions.
  if tg_table_name = 'transactions' then
    if new.type <> v_type then
      raise exception 'transaction type % does not match category type %', new.type, v_type
        using errcode = 'check_violation';
    end if;
  elsif v_type <> 'expense' then
    raise exception 'budgets are only allowed on expense categories'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- Same-event triggers fire in alphabetical order: a_ (LWW) must run first so b_/c_ are skipped for stale updates.
create trigger touch_updated_at before update on centavo.profiles
  for each row execute function centavo.touch_updated_at();

create trigger a_keep_newest before update on centavo.categories
  for each row execute function centavo.keep_newest();
create trigger b_set_synced_at before insert or update on centavo.categories
  for each row execute function centavo.set_synced_at();

create trigger a_keep_newest before update on centavo.transactions
  for each row execute function centavo.keep_newest();
create trigger b_set_synced_at before insert or update on centavo.transactions
  for each row execute function centavo.set_synced_at();
create trigger c_check_category_type before insert or update on centavo.transactions
  for each row execute function centavo.check_category_type();

create trigger a_keep_newest before update on centavo.budgets
  for each row execute function centavo.keep_newest();
create trigger b_set_synced_at before insert or update on centavo.budgets
  for each row execute function centavo.set_synced_at();
create trigger c_check_category_type before insert or update on centavo.budgets
  for each row execute function centavo.check_category_type();

-- ---------------------------------------------------------------- RPC

-- The ONLY way to create a Centavo profile (no trigger on the shared auth.users). Idempotent.
create or replace function centavo.ensure_profile(p_currency_code text default 'USD')
returns centavo.profiles
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_profile centavo.profiles;
begin
  if v_user_id is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into centavo.profiles (id, currency_code)
  values (v_user_id, upper(coalesce(p_currency_code, 'USD')))
  on conflict (id) do nothing;

  select * into v_profile from centavo.profiles where id = v_user_id;
  return v_profile;
end;
$$;

comment on function centavo.ensure_profile(text) is
  'Creates the caller''s Centavo profile if missing and returns it. Called by the app right after OTP verification.';
revoke execute on function centavo.ensure_profile(text) from public, anon;
grant execute on function centavo.ensure_profile(text) to authenticated;

-- ---------------------------------------------------------------- privileges

revoke all on all tables in schema centavo from anon;
grant select on centavo.profiles to authenticated;
grant update (currency_code) on centavo.profiles to authenticated;   -- users may only change their currency
grant select, insert, update, delete on centavo.categories, centavo.transactions, centavo.budgets to authenticated;
grant all on all tables in schema centavo to service_role;

-- ---------------------------------------------------------------- row level security

alter table centavo.profiles     enable row level security;
alter table centavo.categories   enable row level security;
alter table centavo.transactions enable row level security;
alter table centavo.budgets      enable row level security;
-- anon has no policies: every anonymous request is denied.

-- profiles: no insert policy (ensure_profile does it) and no delete policy (cascade from auth.users).
create policy profiles_select_own on centavo.profiles
  for select to authenticated using (id = (select auth.uid()));
comment on policy profiles_select_own on centavo.profiles is 'A user can only read their own profile.';

create policy profiles_update_own on centavo.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
comment on policy profiles_update_own on centavo.profiles is 'A user can only update their own profile (column grant limits it to currency_code).';

-- categories: every operation is limited to the caller's own rows.
create policy categories_select_own on centavo.categories
  for select to authenticated using (user_id = (select auth.uid()));
comment on policy categories_select_own on centavo.categories is 'Users only read their own categories.';

create policy categories_insert_own on centavo.categories
  for insert to authenticated with check (user_id = (select auth.uid()));
comment on policy categories_insert_own on centavo.categories is 'Users cannot insert rows on behalf of another user.';

create policy categories_update_own on centavo.categories
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
comment on policy categories_update_own on centavo.categories is 'Users only update their own rows and cannot move them to another user.';

create policy categories_delete_own on centavo.categories
  for delete to authenticated using (user_id = (select auth.uid()));
comment on policy categories_delete_own on centavo.categories is 'Used only by "Delete my backup": users only delete their own rows.';

-- transactions: every operation is limited to the caller's own rows.
create policy transactions_select_own on centavo.transactions
  for select to authenticated using (user_id = (select auth.uid()));
comment on policy transactions_select_own on centavo.transactions is 'Users only read their own transactions.';

create policy transactions_insert_own on centavo.transactions
  for insert to authenticated with check (user_id = (select auth.uid()));
comment on policy transactions_insert_own on centavo.transactions is 'Users cannot insert rows on behalf of another user.';

create policy transactions_update_own on centavo.transactions
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
comment on policy transactions_update_own on centavo.transactions is 'Users only update their own rows and cannot move them to another user.';

create policy transactions_delete_own on centavo.transactions
  for delete to authenticated using (user_id = (select auth.uid()));
comment on policy transactions_delete_own on centavo.transactions is 'Used only by "Delete my backup": users only delete their own rows.';

-- budgets: every operation is limited to the caller's own rows.
create policy budgets_select_own on centavo.budgets
  for select to authenticated using (user_id = (select auth.uid()));
comment on policy budgets_select_own on centavo.budgets is 'Users only read their own budgets.';

create policy budgets_insert_own on centavo.budgets
  for insert to authenticated with check (user_id = (select auth.uid()));
comment on policy budgets_insert_own on centavo.budgets is 'Users cannot insert rows on behalf of another user.';

create policy budgets_update_own on centavo.budgets
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
comment on policy budgets_update_own on centavo.budgets is 'Users only update their own rows and cannot move them to another user.';

create policy budgets_delete_own on centavo.budgets
  for delete to authenticated using (user_id = (select auth.uid()));
comment on policy budgets_delete_own on centavo.budgets is 'Used only by "Delete my backup": users only delete their own rows.';

