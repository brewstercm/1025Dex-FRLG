# 1025Dex — Credits

## Original mod

**1025Dex is based on national-dex by Sanjin and Tekky.**
Thank you to both creators for the original mod and the foundation this project
was built from. The original national-dex work belongs to its creators;
1025Dex's FireRed/LeafGreen/Emerald adaptations and additions build on that work.

Original project: https://github.com/sanjinpepic/gen1recomp-national-dex

The upstream copyright notice and license are preserved in
[dex/LICENSE-national-dex.txt](dex/LICENSE-national-dex.txt).

## Pokémon sprites

**Credit to Gen9 Resource Pack and all of its contributing sprite artists
for their Pokémon sprites.** These sprites are third-party artwork, not
original artwork created for 1025Dex.

The bundled sprite component also documents its DBK animated sprite-sheet
source and the “icones animados” party-icon source. Those existing source notes
are preserved in [sprites/UPSTREAM-README.md](sprites/UPSTREAM-README.md) and
[sprites/assets/icons/README.md](sprites/assets/icons/README.md).

## Data, audio and engine

- **PokeAPI and its contributors** — the Pokémon data used by national-dex.
  https://pokeapi.co
- **PokeAPI/cries**, with upstream sources Pokémon Showdown and Veekun — cry
  audio. See [cries/NOTICE.txt](cries/NOTICE.txt) and the included CC0 notice.
  https://github.com/PokeAPI/cries
- **Gen1Recomp and its contributors** — the engine this mod runs on.
  https://github.com/bryanthaboi/gen1recomp

Pokémon and its characters belong to their respective rights holders.
Attribution here does not imply endorsement by the original creators.

## Emerald compatibility

The native Emerald Pokédex adapter in `compat/emerald_pokedex.lua` is adapted
from gen1recomp 0.3.36's `src/ui/game3/rse/pokedex.lua`. The engine's GPL-3.0
license and Additional Terms are reproduced in
[compat/ENGINE-LICENSE.md](compat/ENGINE-LICENSE.md).

The extended body-color search table comes from PokéAPI's species CSV,
retrieved September 30, 2026:
https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon_species.csv

Hoenn map profiles contain encounter metadata derived from the user's Emerald
ROM. No ROM bytes or extracted native graphics are included in either release.
