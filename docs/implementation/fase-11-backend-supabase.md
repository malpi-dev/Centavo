# Fase 11 · Backend Supabase (local)

**Rama:** `feat/fase-11-backend-supabase`
**Objetivo:** schema `centavo` en Supabase local: tablas espejo, constraints, triggers (last-write-wins, `synced_at`,
tipo de categoría), RLS con políticas comentadas, RPC `ensure_profile`, seed de demo local, tests pgTAP y job de CI.
Todavía **no** se toca el proyecto remoto (fase 14) ni el cliente Flutter (fase 12).
**Referencias:** definición §7 completo, §13 (BD), §14 (job opcional) · `CLAUDE.md` del portafolio (Backend, Convenciones
del proyecto compartido) · bitácora (PK compuesta de categorías, `color bigint`, `ensure_profile(p_currency_code)`).
**Requisitos previos:** fase 10 terminada. Docker Desktop encendido (si no: **🙋 Acción del autor**). Supabase CLI instalada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

**Conflicto de puertos:** Agendo usa los mismos puertos locales (54321–54324). Antes de arrancar Centavo, detén
Agendo si está corriendo: `cd ../Agendo && supabase stop && cd ../Centavo` (o `supabase stop --project-id agendo`).

## Paso 1 · Inicializar Supabase

```bash
supabase init            # crea supabase/config.toml (responde "N" a generar settings de VS Code/Deno si pregunta)
```

Edita `supabase/config.toml`:

- `project_id = "centavo"`.
- `[api]`: `schemas = ["public", "graphql_public", "centavo"]`, `extra_search_path = ["public", "extensions"]`
  (mantén `max_rows = 1000`; el cliente pagina de 1000 en 1000).
- `[auth]`: `enable_signup = true`.
- `[auth.email]`: `enable_signup = true`, `enable_confirmations = true`, `otp_length = 6`, `otp_expiry = 3600`.
- `[auth.rate_limit]`: sube `email_sent` a `30` **solo en local** (comentario: "local only; remote uses the default SMTP limits").
- Plantillas de email (convención común: código de 6 dígitos, texto neutro):
  ```toml
  [auth.email.template.confirmation]
  subject = "Your verification code"
  content_path = "./supabase/templates/otp.html"

  [auth.email.template.magic_link]
  subject = "Your verification code"
  content_path = "./supabase/templates/otp.html"
  ```
- `[db.seed]`: `enabled = true`, `sql_paths = ["./seed.sql"]`.

`supabase/templates/otp.html`:

```html
<h2>Your verification code</h2>
<p>Enter this code in the app:</p>
<p style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">{{ .Token }}</p>
<p>The code expires in 1 hour. If you didn't request it, you can ignore this email.</p>
```

Si alguna clave no existe con ese nombre en la versión de la CLI instalada, busca la equivalente en el `config.toml`
generado (trae todas las opciones comentadas) y anótalo en la bitácora.

## Paso 2 · Migración `supabase/migrations/20260928000000_centavo_init.sql`

Crea el archivo **a mano con ese nombre** (no uses `supabase db push`; en remoto se aplicará con `psql`, fase 14).
Contenido completo (inglés; ajusta solo si algo no compila, y anótalo):

```sql
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
  if tg_table_name = 'transactions' and new.type <> v_type then
    raise exception 'transaction type % does not match category type %', new.type, v_type
      using errcode = 'check_violation';
  end if;
  if tg_table_name = 'budgets' and v_type <> 'expense' then
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
```

Continúa el archivo con las **cuatro políticas por tabla** para `categories`, `transactions` y `budgets` (12 en total),
todas `to authenticated`, cada una con su `comment on policy` en inglés y un comentario SQL encima. Plantilla para
`categories` (repite cambiando el nombre de tabla):

```sql
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
```

## Paso 3 · Seed local (`supabase/seed.sql`)

Solo local (§7.6: **nunca** se aplica en remoto, `auth.users` es compartido). Replica el patrón de la fase 05 §4.1.

1. Usuario demo (UUID fijo `c0000000-0000-4000-8000-000000000001`, email `demo@centavo.test`):
   ```sql
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
   ```
   (Las columnas de token deben ser `''`, no `NULL`, o GoTrue falla al iniciar sesión. Si alguna columna no existe en
   tu versión, quítala y anótalo.)
2. Perfil: `insert into centavo.profiles (id, currency_code) values ('c0000000-…-000000000001', 'USD');`
3. Categorías: las 10 por defecto + Coffee, Gym y Old car (archivada), con los mismos ids que en Dart. Colores en
   decimal (`bigint`):

   | Color | Decimal | | Color | Decimal |
   |---|---|---|---|---|
   | `0xFFE65100` | 4293284096 | | `0xFF2E7D32` | 4281236786 |
   | `0xFF1565C0` | 4279592384 | | `0xFF00796B` | 4278221163 |
   | `0xFF6D4C41` | 4285353025 | | `0xFF3949AB` | 4281944491 |
   | `0xFFC62828` | 4291176488 | | `0xFFB8692E` | 4290275630 |
   | `0xFF7B1FA2` | 4286259106 | | `0xFFB7791F` | 4290214175 |
   | `0xFFC2185B` | 4290910299 | | `0xFF546E7A` | 4283723386 |

4. Movimientos con SQL puro (sin `DO`), usando `generate_series` y una tabla de reglas `values`:
   ```sql
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
   rules (day_of_month, only_offset, category_id, type, amount_minor, note) as (
     values
       (1, null::int, '00000000-0000-4000-8000-000000000101'::uuid, 'income', 320000, 'Monthly salary'),
       (1, null, '00000000-0000-4000-8000-000000000003', 'expense', 95000, 'Rent'),
       (1, 0, '00000000-0000-4000-8000-0000000000c1', 'expense', 450, 'Latte'),
       (1, 0, '00000000-0000-4000-8000-000000000005', 'expense', 1599, 'Streaming subscription')
       -- … one row per rule/day of the table in phase 05 §4.1 (groceries: one row per day with its amount)
   ),
   generated as (
     select d.day, r.category_id, r.type, r.amount_minor, r.note
     from days d join rules r
       on extract(day from d.day) = r.day_of_month and (r.only_offset is null or r.only_offset = d.offset_n)
     union all
     select d.day, '00000000-0000-4000-8000-0000000000c1'::uuid, 'expense',
            case when extract(day from d.day)::int % 2 = 1 then 420 else 375 end, 'Morning coffee'
     from days d
     where extract(isodow from d.day) between 1 and 5
   )
   insert into centavo.transactions (id, user_id, category_id, type, amount_minor, occurred_on, note, created_at, updated_at)
   select gen_random_uuid(), 'c0000000-0000-4000-8000-000000000001', g.category_id, g.type, g.amount_minor, g.day, g.note,
          (g.day + time '12:00') at time zone 'UTC', (g.day + time '12:00') at time zone 'UTC'
   from generated g;
   ```
5. Presupuestos: M2 y M1 con los límites fijos; M0 con Food/Transport/Shopping fijos y Coffee/Entertainment calculados
   con la misma fórmula que en Dart a partir de `sum(amount_minor)` de los movimientos de M0 recién insertados
   (`ceil(sum * 100 / 90.0)` y `greatest(100, sum * 80 / 100)`).

Comprueba: `supabase db reset` termina sin errores y
`select count(*) from centavo.transactions;` da ~80–130 según el día del mes.

## Paso 4 · Tests pgTAP (`supabase/tests/`)

Dos archivos: `rls_test.sql` y `triggers_test.sql`. Estructura:

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(<N>);

-- Fixtures (as postgres): two users.
insert into auth.users (id, email, aud, role) values
  ('a0000000-0000-4000-8000-00000000000a', 'a@centavo.test', 'authenticated', 'authenticated'),
  ('b0000000-0000-4000-8000-00000000000b', 'b@centavo.test', 'authenticated', 'authenticated');

-- Act as user A.
set local role authenticated;
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-00000000000a","role":"authenticated"}';
-- … assertions …

-- Switch to user B (reset role first so SET ROLE is allowed).
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b0000000-0000-4000-8000-00000000000b","role":"authenticated"}';
-- … assertions …

select * from finish();
rollback;
```

**`rls_test.sql`** (CA4 de F8), como mínimo:
- A: `ensure_profile('EUR')` funciona; llamarla otra vez con `'USD'` devuelve `EUR` (idempotente).
- A inserta categorías (una por defecto con id fijo y una propia), un movimiento y un presupuesto sin enviar `user_id`
  (usa el default `auth.uid()`).
- B: `count(*)` en `categories`, `transactions`, `budgets` y `profiles` = 0.
- B puede insertar una categoría con el **mismo id fijo** que A (PK compuesta).
- B no puede insertar una fila con `user_id` de A (`throws_ok(..., '42501')`).
- `update`/`delete` de B sobre filas de A afectan 0 filas (`with u as (update … returning 1) select count(*) from u`).
- B no puede crear un movimiento que apunte a la categoría **propia** de A (violación de FK, `23503`).
- B no puede insertar en `profiles` directamente (`42501`) ni actualizar otra columna que no sea `currency_code`.
- `anon` (tras `reset role; set local role anon;`): `select` en `centavo.categories` → `42501`.
- `anon` no puede ejecutar `centavo.ensure_profile` (`42501`).

**`triggers_test.sql`**, como mínimo:
- `keep_newest`: actualizar con un `updated_at` más antiguo no cambia la fila; con uno más nuevo sí.
- `set_synced_at`: se rellena al insertar y cambia al actualizar.
- `check_category_type`: movimiento `income` en categoría `expense` → `23514`; presupuesto sobre categoría de ingreso → `23514`.
- `month` que no es día 1 → `23514`; `amount_minor = 0` → `23514`; `color = -1` → `23514`.
- Índice único parcial: dos presupuestos activos misma categoría/mes → `23505`; si uno tiene `deleted_at`, se permite.
- Borrar una categoría borra en cascada sus movimientos y presupuestos.

```bash
supabase db reset && supabase test db
```

## Paso 5 · Job de base de datos en CI

Añade a `.github/workflows/ci.yaml` un segundo job (en paralelo al de Flutter):

```yaml
  database:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with:
          version: latest
      - name: Start Supabase (only the services the tests need)
        run: supabase start -x studio,imgproxy,storage-api,realtime,edge-runtime,logflare,vector,supavisor
      - run: supabase test db
```

Comprueba los nombres válidos para `-x` con `supabase start --help` en tu versión. Si el job es inestable, déjalo con
`continue-on-error: true`, anótalo en la bitácora y avisa al autor (el job de Flutter debe seguir siendo obligatorio).

## Paso 6 · Entorno local para la app

```bash
supabase status          # copia la API URL y la publishable key (sb_publishable_…) — NUNCA la secret key
```

Crea `.env.json` (ignorado por git) a partir de `.env.example.json` con `SUPABASE_URL = http://10.0.2.2:54321` (emulador)
y la publishable key local. Verifica que `git status` **no** lo muestra.

Comprobación rápida de que `anon` no ve nada (debe responder error de permisos o lista vacía, nunca datos):

```bash
curl -s "http://127.0.0.1:54321/rest/v1/categories?select=id" \
  -H "apikey: <publishable key>" -H "Accept-Profile: centavo"
```

## Paso 7 · Cierre

`00-guia-general.md` §3.3 (incluye `supabase db reset` y `supabase test db`). Deja Supabase local corriendo para la fase 12
o detenlo con `supabase stop`.

---

## Criterios de terminado

- [ ] `supabase/config.toml` expone el schema `centavo`, OTP de 6 dígitos y plantilla con `{{ .Token }}`.
- [ ] Migración `20260928000000_centavo_init.sql` solo toca `centavo`: tablas, índices, triggers, `ensure_profile`, grants y RLS en las 4 tablas con **todas** las políticas comentadas.
- [ ] `supabase db reset` aplica migración + seed sin errores; el seed replica el patrón del demo.
- [ ] `supabase test db` en verde (RLS y triggers).
- [ ] Job `database` en CI; `.env.json` local creado y fuera de git.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
