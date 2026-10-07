# Upstream 1.2.15 merge record

Merged on October 6, 2026 into maintained checkout based on commit `9e95ea6`.
The working tree was clean before the merge.

## Compared inputs

- [Latest upstream release 1.2.15](https://github.com/Bentley734/1025Dex/releases/tag/1.2.15), confirmed through GitHub's releases/latest API.
- Attached installable `1025Dex-v1.2.15.zip`, rather than the automatic source archive.
- Attached `1025Dex-v1.2.5.zip` as the three-way baseline for the maintained 1.2.5 build.

ZIP SHA-256:

```
1.2.5  835c1a1160dc2fbec758ee817d701139b96f1a22cba4dbff4a15abc3f3ff8dc8
1.2.15 4cd0958f3c67e219ae51e0dd945e36e9972f64457aa335218518210f4f402095
```

The 1.2.15 digest matches GitHub's published asset digest. The release adds
50 files and changes 13; it removes none. All 9,544 files beneath
`sprites/assets/` and `cries/assets/` are byte-identical between both ZIPs and
the merged checkout. Remaining differences were compared after normalizing
line endings.

## Integrated changes

Evolution registration/reload and conditional checks; Gen 3 wild moves and
TM/HM permissions; first-catch UI return; native/campaign encounter metadata,
habitat corrections, missing routes, cave balance and Ultra Beast rarity;
all-eleven-game registration, cries, encounters and storage; Hoennto collection
projection; and the shared National species-number API.

Updated the manifest to 1.2.15 and engine requirement `>=0.3.54 <0.4.0`, retaining
the maintained GitHub repository identity. Events remain scoped to FR/LG and
Emerald. The new Gen 1/2 and Ruby/Sapphire support follows upstream.

## Maintained integrations

- Preserved event gift identities, one-time state, ticket flags and EVENTS-before-MODS ordering.
- Preserved all FR/LG evolution overrides and upstream held-item precedence. The new move-availability argument and FR/LG override argument coexist; Emerald/Ruby/Sapphire retain upstream defaults.
- Preserved correct added-species gender ratios and saved party/PC unknown-gender repair.
- Preserved the FR/LG Area index, National-mode default and missing-footprint protection in RSE, plus the maintained Emerald Area adapter.
- Extended Area adapters to include Ultra Beast groups and Ruby/Sapphire policy map translation; refresh live cartridge profiles before querying them.
- Kept Area pool lookup deterministic while preserving protected Diglett/Dugtrio weighted rolls in actual encounter selection.
- Retained animated sprites, battle placement, menu world rendering, credits/licenses and the existing release workflow.
- Regenerated maintained Emerald ordinary and postgame guides from the merged standalone policy. Kept upstream atlas/audit references and added a reproducible maintained guide generator.
- Made the upstream all-games/native-encounter Python test runners accept this checkout's paths. Updated boundary fixtures for saved-gender repair and the 0.3.54 capture helper.

## Validation performed

Used Lua 5.3 through lupa, Gen1Recomp tag `v0.3.54` (commit
`c116459047d45293ef490662d07287f80835141f`), the `v0.3.43` capture-flow source,
and the Hoennto 0.2.0 release as test dependencies. All listed checks passed:

| Check | Result |
|---|---|
| Lua syntax | 231 files |
| Animated shiny/normal sprites | 50 assertions |
| Battle placement | 144 assertions |
| Special homes and League transitions | 50,512 assertions |
| Cave levels/rarity and public APIs | 70,622 checks |
| Ultra Beast pools/gates/rarity | 305,766 assertions |
| Kanto/Hoenn campaign | 65,201 checks |
| Missing-route policy/public APIs | 4,344 / 4,599 checks |
| Native/habitat encounters FR/LG/Emerald | 231,267 / 232,007 / 231,308 checks |
| Registry/TM-HM/wild moves/reload | 5,417,665 checks |
| Wild battle bridge and options | 541,084 checks |
| Capture return, old/new engine and NoNickname ordering | 1,040 checks |
| Maintained gender/evolution/Area/events/tickets/species API | 1,512 checks |
| Schema-backed registration | 1,025 species in each of 11 games |
| Hoennto collection projection | 1,025 species in each of 11 games |
| Ruby/Sapphire live native API | 584 entries each |
| Maintained Emerald guide | 1,025 species rows |
| Assets and local-only components | Byte-preservation audit passed |
| Diff whitespace | `git diff --check` passed |

These are headless checks. No graphical playthrough or live save was used.
The separate DexNav companion-dependent suite and PokeAPI CSV source audit
were not run; their source artifacts are imported from the verified upstream
ZIP, and final wild moves plus public encounter APIs were exercised directly.

The changes are local and reviewable; no commit, push or release publication
was performed as part of this merge.
