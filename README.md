# 1025Dex 1.2.0

Adds the full 1,025-species National Dex to FireRed, LeafGreen and Emerald, animated Pokémon
sprites, generation-selectable wild encounters, Kanto, Sevii and Hoenn encounter pools and
36 PC boxes with space for 1,080 Pokémon.

**Based on national-dex by Sanjin and Tekky.**
Original mod: https://github.com/sanjinpepic/gen1recomp-national-dex

**Pokémon sprite credits: Gen9 Resource Pack and its contributing artists.**
See [CREDITS.md](CREDITS.md) for attribution and included source/license notices.

Browse the [complete Emerald wild encounter location list](docs/emerald-gen1-9-locations.md)
for all 1,025 Pokémon with WILD GENS set to GEN 1–9.

## 1.2.0 — Emerald port

Requires gen1recomp **0.3.36 or newer in 0.3.x**. Install alongside
**WildFollowers 2.15.0** for visible wilds and party followers in Hoenn.

- All 1,025 National species use the correct Emerald internal slots. Native
  Gen 1–3 species keep their ROM data; new species receive Gen 3-compatible
  learnsets, evolutions, animated sprites and cries. Moves unavailable in
  Gen 3 use the existing compatibility substitutions.
- The native Emerald Pokédex retains its 202-species Hoenn list and gains a
  1,025-species National list, six sort orders, color/type search, descriptions,
  animated pictures and four-digit seen/owned totals. National mode is enabled
  while the mod is active. Added entry text wraps within the native page.
- 116 native Hoenn encounter-map profiles supply separate land, Surf, fishing
  and Rock Smash pools. WILD GENS has all 17 generation selections. Later
  species receive habitat homes and appropriate evolution-level gates.
  Old Rod and Rock Smash rolls retain their native level ceiling.
- Legendary, mythical and other special species remain outside ordinary
  random pools. Native scripted and static battles are preserved.
- 36 PC boxes hold 1,080 Pokémon. Native save serialization retains additions,
  including the last box and slot; existing storage metadata is preserved.
- Kanto/Sevii distributions and bundled sprite/audio bytes remain unchanged.

The upstream 1.2.0 release reports validation using the 0.3.36 Loader/sandbox and supplied Emerald USA data:
all 1,025 slot mappings; all 3,417 Hoenn terrain/generation pools; all six native
Pokédex sorts; color search; descriptions; four-digit totals; Gen 3 learnsets;
36-box save roundtrip; and dataset reload. Full in-game playthrough pending.

This maintained checkout also keeps its FireRed/LeafGreen Pokédex Area encounter
index and its Gen 3 compatibility evolution choices. The ZIP's held-item rules
for Slowking and Clamperl take precedence over the older stone alternatives.

## Updating

Replace the previous 1025Dex folder and restart the game. If using visible wild
Pokémon, use WildFollowers 2.15.0 or a compatible newer release.

Back up your save before updating. Keep expanded-storage support enabled while
boxes 15–36 contain Pokémon; the unmodified engine supports only 14 boxes.
