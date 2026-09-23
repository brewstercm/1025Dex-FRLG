-- FireRed gameplay compatibility for post-Gen-3 evolutions whose modern
-- trigger cannot be represented by the stock FireRed evolution engine.
--
-- The Pokédex keeps displaying the real modern requirement from the generated
-- evolution database. These rows only choose a practical FireRed gameplay
-- trigger.
--
-- Evolutions that already map cleanly need no override here:
--   EEVEE -> LEAFEON       Leaf Stone
--   MAGNETON -> MAGNEZONE Thunderstone
--   NOSEPASS -> PROBOPASS Thunderstone

return {
  EEVEE = {
    -- Ice Stone does not exist in FireRed.
    GLACEON = { method = "EVO_ITEM", item = "MOON_STONE" },
    -- Fairy-move + friendship cannot be represented by a stock Gen 3 row.
    SYLVEON = { method = "EVO_ITEM", item = "SUN_STONE" },
  },


  SLOWPOKE = {
    -- Slowbro already evolves at level 37. Sun Stone gives Slowking a clean
    -- selectable single-save branch instead of requiring cancelled evolutions.
    SLOWKING = { method = "EVO_ITEM", item = "SUN_STONE" },
  },

  CLAMPERL = {
    -- Huntail is level 36; Water Stone selects Gorebyss.
    GOREBYSS = { method = "EVO_ITEM", item = "WATER_STONE" },
  },

  TOGETIC = {
    -- Shiny Stone substitute.
    TOGEKISS = { method = "EVO_ITEM", item = "SUN_STONE" },
  },

  AIPOM = {
    -- Modern rule: level up knowing Double Hit.
    AMBIPOM = { method = "EVO_LEVEL", level = 32 },
  },

  YANMA = {
    -- Modern rule: level up knowing Ancient Power.
    YANMEGA = { method = "EVO_LEVEL", level = 33 },
  },

  MURKROW = {
    -- Dusk Stone substitute.
    HONCHKROW = { method = "EVO_ITEM", item = "MOON_STONE" },
  },

  MISDREAVUS = {
    -- Dusk Stone substitute.
    MISMAGIUS = { method = "EVO_ITEM", item = "MOON_STONE" },
  },

  GIRAFARIG = {
    -- Modern rule: level up knowing Twin Beam.
    FARIGIRAF = { method = "EVO_LEVEL", level = 32 },
  },

  DUNSPARCE = {
    -- Modern rule: level up knowing Hyper Drill.
    DUDUNSPARCE = { method = "EVO_LEVEL", level = 32 },
  },

  GLIGAR = {
    -- Modern rule: level up at night holding Razor Fang.
    GLISCOR = { method = "EVO_LEVEL", level = 40 },
  },

  LICKITUNG = {
    -- Modern rule: level up knowing Rollout.
    LICKILICKY = { method = "EVO_LEVEL", level = 33 },
  },

  RHYDON = {
    RHYPERIOR = { method = "EVO_LEVEL", level = 50 },
  },

  TANGELA = {
    -- Modern rule: level up knowing Ancient Power.
    TANGROWTH = { method = "EVO_LEVEL", level = 38 },
  },

  SCYTHER = {
    -- Black Augurite does not exist in FireRed. Scizor's Metal Coat trade
    -- branch remains untouched; Moon Stone becomes the separate Kleavor path.
    KLEAVOR = { method = "EVO_ITEM", item = "MOON_STONE" },
  },

  ELECTABUZZ = {
    ELECTIVIRE = { method = "EVO_LEVEL", level = 42 },
  },

  MAGMAR = {
    MAGMORTAR = { method = "EVO_LEVEL", level = 42 },
  },

  PRIMEAPE = {
    -- Modern rule: use Rage Fist 20 times.
    ANNIHILAPE = { method = "EVO_LEVEL", level = 40 },
  },

  ROSELIA = {
    -- Shiny Stone substitute.
    ROSERADE = { method = "EVO_ITEM", item = "SUN_STONE" },
  },

  DUSCLOPS = {
    DUSKNOIR = { method = "EVO_LEVEL", level = 48 },
  },

  SNORUNT = {
    -- Dawn Stone + female-only cannot be represented by a stock Gen 3 row.
    -- Sun Stone gives Froslass a distinct item branch; Glalie's level branch
    -- remains intact.
    FROSLASS = { method = "EVO_ITEM", item = "SUN_STONE" },
  },

  SNEASEL = {
    -- Modern rule: level up at night holding Razor Claw.
    WEAVILE = { method = "EVO_LEVEL", level = 40 },
  },

  URSARING = {
    -- Modern rule: Peat Block during a full moon.
    URSALUNA = { method = "EVO_ITEM", item = "MOON_STONE" },
  },

  PILOSWINE = {
    -- Modern rule: level up knowing Ancient Power.
    MAMOSWINE = { method = "EVO_LEVEL", level = 40 },
  },

  PORYGON2 = {
    PORYGON_Z = { method = "EVO_LEVEL", level = 40 },
  },

  STANTLER = {
    -- Modern rule: use Psyshield Bash in Agile Style 20 times.
    WYRDEER = { method = "EVO_LEVEL", level = 40 },
  },

  KIRLIA = {
    -- Dawn Stone + male-only cannot be represented by a stock Gen 3 row.
    -- Gardevoir's level-30 branch remains intact.
    GALLADE = { method = "EVO_ITEM", item = "SUN_STONE" },
  },
}
