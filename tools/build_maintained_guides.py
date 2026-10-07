"""Refresh the maintained Markdown/text guides from the live Gen 3 policy.

Requires lupa (Lua 5.3). Run from any directory; outputs stay in this checkout.
"""
from pathlib import Path
import os

from lupa.lua53 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def pools(game):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().edition = game
    return lua.execute("""
local function d(n)return dofile('encounters/'..n..'.lua')end
local P=d('policy');local roster=d('roster');local locations=d('locations')
for _,loc in ipairs(d('hoenn_locations'))do locations[#locations+1]=loc end
local source=d('native');local native={}
for map,rows in pairs(source[edition=='leafgreen' and 'leafgreen' or 'firered'])do native[map]=rows end
for map,rows in pairs(source.emerald)do native[map]=rows end
locations=d('native_profiles').prepare(locations,native)
local channels=d('campaign_terrains')
for map,rows in pairs(native)do
 local key=map:gsub('[^%w]',''):upper();channels[key]={}
 for terrain in pairs(rows)do channels[key][terrain]=true end
end
local policy=P.new(roster,locations,nil,nil,function()return false end,d('campaign'),channels)
local rows={}
for _,base in ipairs(locations)do
 if (edition=='emerald')==not not base.hoenn and native[base.map] then
  for terrain in pairs(native[base.map])do
   local pool,loc=policy:pool(base.map,17,terrain,{postgame=true})
   for _,group in ipairs({'common','rare','featured','special','ultra'})do
    for _,mon in ipairs(pool[group] or {})do
     local lo,hi=math.min(loc.hi,math.max(loc.lo,mon.gate or 1)),loc.hi
     if loc.native and loc.native[mon.id]then lo,hi=loc.native[mon.id][1],loc.native[mon.id][2]end
     if group=='special'then lo,hi=P.specialLevelRange(mon)end
     if group=='ultra'then lo,hi=P.ultraLevelRange(mon,loc,pool.ultraEndgame)end
     if pool.residentSlots then
      lo,hi=nil,nil
      for _,slot in ipairs(pool.residentSlots)do if slot[1]==mon.id then
       lo=math.min(lo or slot[2],slot[2]);hi=math.max(hi or slot[2],slot[2])
      end end
     end
     rows[#rows+1]={national=mon.id,name=mon.name,map=base.map,terrain=terrain,group=group,lo=lo,hi=hi,
       chance=group=='ultra' and (pool.ultraEndgame and '1%' or '0.1%') or '1%'}
    end
   end
  end
 end
end
return rows,roster
""")


def map_name(raw):
    return raw.removeprefix("EM_").removeprefix("FR_").removeprefix("LG_").replace("_", " ").title()


def main():
    os.chdir(ROOT)
    all_rows = {}
    roster = None
    for game in ("firered", "leafgreen", "emerald"):
        rows, roster = pools(game)
        all_rows[game] = [dict(row.items()) for _, row in rows.items()]
    ordinary = {}
    for row in all_rows["emerald"]:
        if row["group"] in ("special", "ultra"):
            continue
        mark = " ★" if row["group"] == "featured" else " †" if row["group"] == "rare" else ""
        home = f"{map_name(row['map'])} ({row['lo']}–{row['hi']}){mark}"
        ordinary.setdefault((row["national"], row["terrain"]), set()).add(home)
    species = sorted((dict(mon.items()) for _, mon in roster.items()), key=lambda mon: mon["id"])
    lines = [
        "# 1025Dex v1.2.15: Emerald ordinary wild locations for all 1,025 Pokémon",
        "",
        "Generated from this checkout's live policy and bundled native Emerald encounter profiles, with WILD GENS set to GEN 1–9 and standalone mode. Land, Surf, fishing and Rock Smash are separate channels. ★ marks featured additions; † marks rare additions. Listed levels are policy ranges; native fishing and Rock Smash rolls may further restrict added species by their evolution gate.",
        "",
        "League-gated legendary, mythical and Ultra Beast pools are listed in [POSTGAME-SPAWNS.txt](../POSTGAME-SPAWNS.txt). Ordinary locations below exclude those groups. Map access and story progress still apply; event gifts, evolution, scripted encounters and Hoennto campaign assignments are outside this table.",
        "",
        f"{len({national for national, _ in ordinary})} species have an ordinary wild pool in the bundled native encounter maps.",
    ]
    generation = None
    for mon in species:
        if mon["gen"] != generation:
            generation = mon["gen"]
            lines += ["", f"## Generation {generation}", "", "| # | Pokémon | Land | Surf | Fishing | Rock Smash |", "|---:|---|---|---|---|---|"]
        homes = ["; ".join(sorted(ordinary.get((mon["id"], terrain), []))) or "—" for terrain in ("land", "water", "fishing", "rocks")]
        lines.append(f"| {mon['id']} | {mon['name'].replace('_', ' ').title()} | " + " | ".join(homes) + " |")
    (ROOT / "docs/emerald-gen1-9-locations.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    text = ["1025Dex 1.2.15 — Post-League special and Ultra Beast encounter homes", "", "Generated from the maintained live policy, standalone mode, WILD GENS GEN 1–9.", "Added pools require League clear. Special pools share a 1% roll when ordinary", "candidates exist (otherwise the special pool may be chosen directly). Ultra", "Beasts use 1% in designated endgame hubs and 0.1% in eligible late land areas.", "Native scripted/static/roaming encounters retain their own rules."]
    for game, rows in all_rows.items():
        text += ["", game.upper(), ""]
        homes = {}
        for row in rows:
            if row["group"] not in ("special", "ultra"):
                continue
            rarity = f", shared {row['chance']} Ultra Beast roll" if row["group"] == "ultra" else ""
            home = f"{row['map']} ({row['terrain']}, {row['lo']}–{row['hi']}{rarity})"
            homes.setdefault((row["national"], row["name"]), set()).add(home)
        for (nat, name), locations in sorted(homes.items()):
            text.append(f"#{nat:04d} {name}: " + "; ".join(sorted(locations)))
    (ROOT / "POSTGAME-SPAWNS.txt").write_text("\n".join(text) + "\n", encoding="utf-8")
    print("Updated Emerald ordinary locations and postgame spawn references.")


if __name__ == "__main__":
    main()
