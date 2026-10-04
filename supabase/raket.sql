-- Ole's Artemis-raket: opslag met gezins-pincode
-- Plak dit hele script in Supabase > SQL Editor en klik Run.
-- VERVANG EERST 'KIES-JE-PINCODE' (onderaan) door jullie eigen pincode van minimaal 6 cijfers.
-- Raakt de bestaande tabel user_data niet aan.

create extension if not exists pgcrypto with schema extensions;

-- Boekingen: iedereen met de link mag lezen
create table if not exists public.raket_entries (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('klus', 'eigen', 'gift')),
  amount_cents integer not null check (amount_cents > 0 and amount_cents <= 100000),
  date date not null,
  from_name text not null check (length(from_name) between 1 and 40),
  note text not null default '' check (length(note) <= 80),
  created_at timestamptz not null default now()
);

-- Doelbedrag (precies één rij)
create table if not exists public.raket_settings (
  id int primary key default 1 check (id = 1),
  target_cents integer not null default 25999 check (target_cents between 100 and 10000000)
);
insert into public.raket_settings (id) values (1) on conflict do nothing;

-- Pincode (gehasht) + slot na foute pogingen. Niet leesbaar voor bezoekers.
create table if not exists public.raket_secret (
  id int primary key default 1 check (id = 1),
  pin_hash text not null,
  failed int not null default 0,
  locked_until timestamptz
);

alter table public.raket_entries  enable row level security;
alter table public.raket_settings enable row level security;
alter table public.raket_secret   enable row level security;

drop policy if exists "iedereen leest" on public.raket_entries;
create policy "iedereen leest" on public.raket_entries  for select to anon, authenticated using (true);
drop policy if exists "iedereen leest" on public.raket_settings;
create policy "iedereen leest" on public.raket_settings for select to anon, authenticated using (true);
-- raket_secret heeft bewust geen policies: alleen de functies hieronder komen erbij.

grant select on public.raket_entries, public.raket_settings to anon, authenticated;
revoke insert, update, delete on public.raket_entries, public.raket_settings from anon, authenticated;
revoke all on public.raket_secret from anon, authenticated;

-- Controleert de pincode. Geeft false bij een foute code en telt de poging;
-- na 5 foute pogingen 15 minuten op slot.
create or replace function public.raket_pin_ok(p_pin text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare s public.raket_secret;
begin
  select * into s from public.raket_secret where id = 1 for update;
  if not found then return false; end if;
  if s.locked_until is not null and s.locked_until > now() then
    raise exception 'Te veel foute pincodes. Probeer het over 15 minuten opnieuw.';
  end if;
  if s.pin_hash = extensions.crypt(coalesce(p_pin, ''), s.pin_hash) then
    update public.raket_secret set failed = 0, locked_until = null where id = 1;
    return true;
  end if;
  update public.raket_secret
     set failed = s.failed + 1,
         locked_until = case when s.failed + 1 >= 5 then now() + interval '15 minutes' end
   where id = 1;
  return false;
end $$;

-- Een foute pincode geeft {"ok": false} terug in plaats van een fout,
-- zodat de mislukte poging wél wordt opgeslagen.
create or replace function public.raket_verify(p_pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.raket_pin_ok(p_pin) then return jsonb_build_object('ok', false, 'error', 'pin'); end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.raket_add(p_pin text, p_kind text, p_amount_cents integer, p_date date, p_from text, p_note text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare new_id bigint;
begin
  if not public.raket_pin_ok(p_pin) then return jsonb_build_object('ok', false, 'error', 'pin'); end if;
  insert into public.raket_entries (kind, amount_cents, date, from_name, note)
  values (p_kind, p_amount_cents, p_date, trim(p_from), coalesce(trim(p_note), ''))
  returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id);
end $$;

create or replace function public.raket_delete(p_pin text, p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.raket_pin_ok(p_pin) then return jsonb_build_object('ok', false, 'error', 'pin'); end if;
  delete from public.raket_entries where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.raket_set_target(p_pin text, p_target_cents integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.raket_pin_ok(p_pin) then return jsonb_build_object('ok', false, 'error', 'pin'); end if;
  update public.raket_settings set target_cents = p_target_cents where id = 1;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.raket_pin_ok(text) from public, anon, authenticated;
revoke execute on function public.raket_verify(text), public.raket_add(text, text, integer, date, text, text),
  public.raket_delete(text, bigint), public.raket_set_target(text, integer) from public;
grant execute on function public.raket_verify(text), public.raket_add(text, text, integer, date, text, text),
  public.raket_delete(text, bigint), public.raket_set_target(text, integer) to anon, authenticated;

-- Pincode instellen (of later wijzigen: draai alleen dit blok opnieuw met een nieuwe code)
insert into public.raket_secret (id, pin_hash)
values (1, extensions.crypt('KIES-JE-PINCODE', extensions.gen_salt('bf')))
on conflict (id) do update set pin_hash = excluded.pin_hash, failed = 0, locked_until = null;
