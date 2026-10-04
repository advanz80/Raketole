# Ole's Artemis-raket

Spaarpagina voor de LEGO NASA Artemis SLS (10341): klusjes, eigen inleg en giften bijhouden, terwijl de raket steentje voor steentje verschijnt.

- **Kijken:** iedereen met de link, zonder inloggen.
- **Invoeren, wissen, doel aanpassen:** alleen met de gezinspincode. Die vul je één keer per apparaat in.
- **Opslag:** Supabase (tabellen `raket_entries`, `raket_settings`, `raket_secret`). De bestaande tabel `user_data` wordt niet gebruikt en niet aangeraakt.

## Installatie

1. **Database:** open `supabase/raket.sql`, vervang onderaan `KIES-JE-PINCODE` door een pincode van minimaal 6 cijfers, en plak het hele script in Supabase → SQL Editor → Run.
2. **Koppelen:** vul in `index.html` bij `CONFIG` de *Project URL* en de *anon public key* in (Project Settings → API). Gebruik nooit de `service_role` key.
3. **Online zetten:** GitHub → Settings → Pages → Source *Deploy from a branch* → `master` / `(root)`. De site komt op `https://advanz80.github.io/Raketole/`. Voor een private repo heb je een betaald GitHub-abonnement nodig, of je maakt de repo openbaar (er staan geen geheimen in).

Zolang `CONFIG` niet is ingevuld, draait de pagina in testmodus en slaat hij alleen op in de browser.

## Beheer

- **Pincode wijzigen:** draai alleen het laatste `insert … on conflict` blok uit `raket.sql` opnieuw, met de nieuwe code. Apparaten met de oude code vragen daarna vanzelf om de nieuwe.
- **Slot:** na 5 foute pincodes kan 15 minuten niemand wijzigen.
- **Backup:** Supabase → Table Editor → `raket_entries` → Export to CSV.
