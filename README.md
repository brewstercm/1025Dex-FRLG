# 1025Dex 1.2.15 — maintained version

Adds all 1,025 National species, animated normal/shiny sprites, cries,
generation-selectable wild encounters and expanded PC storage. Supports Red,
Blue, Yellow, Gold, Silver, Crystal, Ruby, Sapphire, FireRed, LeafGreen and Emerald.

Requires **Gen1Recomp 0.3.54 or newer in 0.3.x**. Compatible with Hoennto 0.2.0
and the WildFollowers 3.0.0-beta.1 encounter provider API.

Based on [1025Dex](https://github.com/Bentley734/1025Dex/releases/tag/1.2.15)
and [national-dex by Sanjin and Tekky](https://github.com/sanjinpepic/gen1recomp-national-dex).
Pokémon sprite credits: Gen9 Resource Pack and its contributing artists.
See [CREDITS.md](CREDITS.md) for attribution and included source/license notices.

## Updates merged from upstream

- Evolution rows and TM/HM permissions survive late content registration and
  ROM reloads. Added wild Pokémon receive three or four usable Gen 3 moves;
  unsupported modern attacks receive comparable replacements at their learn levels.
- First-catch Pokédex screens return to the battle UI before nickname/PC messages,
  retaining the caught Pokémon's personality, OT and shiny appearance.
- Native encounter species, channels and level ranges are retained alongside
  habitat-compatible additions. Mt. Moon and Diglett's Cave use corrected native
  level/rarity rules. Ultra Beasts require League clear and have separate rarity rolls.
- All eleven games register the complete roster. Ruby/Sapphire read their live
  native encounter tables; Game Boy additions preserve successful native rolls
  and failed encounters. Hoennto projection retains the expanded collection.
- Mods can use the shared [National species-number API](SPECIES-NUMBERS.md)
  without changing native cartridge IDs in existing saves.

See [the merge record](docs/upstream-1.2.15-merge.md),
[Gen 3 move rules](GEN3-MOVE-RULES.txt) and [evolution rules](EVOLUTION-RULES.txt).
The evolution reference describes upstream defaults; the FR/LG substitutions
below take precedence in this maintained build.

## Maintained additions

The **EVENTS** archive appears above MODS in the field menu in FireRed,
LeafGreen and Emerald. It provides one-time gifts of Mew, Celebi, Jirachi,
Deoxys, Lugia, Ho-Oh, Latias and Latios. Celebi and Jirachi retain their AGETO
and WISHMKR event identities. Tickets also enable native island flags:
Mystic/Aurora Tickets in FR/LG; Eon/Mystic/Aurora Tickets and Old Sea Map in Emerald.

FR/LG and RSE Pokédex Area pages follow the current WILD GENS selection and
League state, including Ultra Beast pools. The RSE Pokédex starts in National
mode by default and safely omits unavailable later-species footprints.

FR/LG retains [the maintained evolution substitutions](dex/data/evolutions/compat_overrides.lua)
for unavailable modern triggers, including distinct Sun/Moon Stone branches.
Held-item branches for Slowking, Clamperl and other native trade-item species
retain upstream precedence. Emerald and Ruby/Sapphire use upstream evolution defaults.

Added Gen 3 species retain their correct gender ratios. Previously saved added
Pokémon with an unknown gender are repaired from their existing personality,
including Pokémon in expanded PC boxes.

## Encounter references

- [Emerald ordinary wild locations](docs/emerald-gen1-9-locations.md)
- [Post-League special and Ultra Beast homes](POSTGAME-SPAWNS.txt)
- [Upstream encounter atlas](EncounterAtlas.csv) and [encounter audit](ENCOUNTER-AUDIT.md)

The maintained location references are regenerated from this checkout's live
standalone policy using WILD GENS GEN 1–9. Hoennto campaign assignments differ.
Run `python tools/build_maintained_guides.py` with lupa installed to refresh them.

## Updating

Replace the previous 1025Dex folder and restart the game. Update the engine to
0.3.54+ first. If installed, use 1025DexNav 0.1.13 or newer for matching wild-move
previews. Visible wild providers must support the applicable 1025Dex encounter API.

Back up your save before updating. Keep expanded-storage support enabled while
boxes 15–36 contain Pokémon; the unmodified Gen 3 engine supports only 14 boxes.

Validation includes headless encounter, move, capture-flow, species-registration,
Hoennto projection and maintained integration tests. A graphical playthrough of
this merged build has not been performed.
