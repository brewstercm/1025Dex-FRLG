-- Gen 3 event archive: redeem the original event species and event tickets
-- from the FireRed-style field menu. Ticket flags follow each game's native
-- save constants so supported ferry/island scripts see the unlocks.
return function(mod)
  local Version = require("src.core.GameVersion")
  local version = Version.get()
  local Choice = require("src.ui.game3.choice")
  local Message = require("src.ui.game3.message")
  local StartMenu = require("src.ui.game3.start_menu")
  local Bag = require("src.core.game3.bag")
  local Pokemon = require("src.core.game3.pokemon")
  local MysteryGift = require("src.core.game3.mystery_gift")

  local SAVE_KEY = "1025dexEventArchive"

  local POKEMON = {
    { key = "mew",      name = "MEW",      national = 151, level = 30 },
    { key = "celebi",   name = "CELEBI",   national = 251, level = 10,
      otName = "AGETO", otId = 31121,
      moves = { [1] = 93, [2] = 105, [3] = 215, [4] = 219 } },
    { key = "jirachi",  name = "JIRACHI",  national = 385, level = 5,
      otName = "WISHMKR", otId = 20043,
      moves = { [1] = 273, [2] = 93, [3] = 156, [4] = 129 } },
    { key = "deoxys",   name = "DEOXYS",   national = 386, level = 30,
      moves = { [1] = 354, [2] = 282, [3] = 228, [4] = 129 } },
    { key = "lugia",    name = "LUGIA",    national = 249, level = 70 },
    { key = "ho_oh",    name = "HO-OH",    national = 250, level = 70 },
    { key = "latias",   name = "LATIAS",   national = 380, level = 50 },
    { key = "latios",   name = "LATIOS",   national = 381, level = 50 },
  }

  -- Emerald's event-item indices share the Generation III item table with
  -- FRLG. Its SYSTEM_FLAGS begin at 0x860; FRLG uses the explicit 0x84A/84B
  -- ferry flags for the two tickets it supports.
  local TICKETS = {
    firered = {
      { key = "mystic_ticket", name = "MYSTIC TICKET", item = 370,
        flags = { 0x84A, 0x2A8 } },
      { key = "aurora_ticket", name = "AURORA TICKET", item = 371,
        flags = { 0x84B, 0x2A7 } },
    },
    leafgreen = {
      { key = "mystic_ticket", name = "MYSTIC TICKET", item = 370,
        flags = { 0x84A, 0x2A8 } },
      { key = "aurora_ticket", name = "AURORA TICKET", item = 371,
        flags = { 0x84B, 0x2A7 } },
    },
    emerald = {
      { key = "eon_ticket", name = "EON TICKET", item = 369,
        flags = { 0x8B3, 0x2AA } },
      { key = "mystic_ticket", name = "MYSTIC TICKET", item = 370,
        flags = { 0x8E0, 0x2A8 } },
      { key = "aurora_ticket", name = "AURORA TICKET", item = 371,
        flags = { 0x8D5, 0x2A7 } },
      { key = "old_sea_map", name = "OLD SEA MAP", item = 376,
        flags = { 0x8D6, 0x2A9 } },
    },
  }

  local function archive(session)
    if type(session) ~= "table" then return nil end
    session.modData = type(session.modData) == "table" and session.modData or {}
    local state = session.modData[SAVE_KEY]
    if type(state) ~= "table" then
      state = { pokemon = {}, tickets = {} }
      session.modData[SAVE_KEY] = state
    end
    state.pokemon = type(state.pokemon) == "table" and state.pokemon or {}
    state.tickets = type(state.tickets) == "table" and state.tickets or {}
    return state
  end

  local function say(session, text, done)
    Message.show(text, { session = session, done = done })
  end

  local showRoot, showPokemon, showTickets

  showRoot = function(session)
    say(session, "The EVENT ARCHIVE is open.\nWhat would you like?", function()
      Choice.multi({ "POKEMON", "TICKETS", "CANCEL" }, 0, function(selected)
        if selected == 0 then
          showPokemon(session)
        elseif selected == 1 then
          showTickets(session)
        end
      end)
    end)
  end

  local function claimPokemon(session, entry)
    local state = archive(session)
    if not state then return end
    if state.pokemon[entry.key] then
      say(session, "This event gift was already\nreceived.")
      return
    end

    local species = Pokemon.speciesFromNational(entry.national)
    if not species then
      say(session, "This POKEMON is unavailable\nin the loaded species data.")
      return
    end

    local result = MysteryGift.deliverGift(session, {
      gift = {
        kind = "mon",
        species = species,
        level = entry.level,
        otName = entry.otName,
        otId = entry.otId,
        moves = entry.moves,
      },
    })
    if result == MysteryGift.DELIVER_GIVEN then
      state.pokemon[entry.key] = true
      say(session, entry.name .. " joined your party!")
    elseif result == MysteryGift.DELIVER_PARTY_FULL then
      say(session, "Your party is full. Make room\nand try again.")
    else
      say(session, "The event gift could not be delivered.")
    end
  end

  showPokemon = function(session)
    local labels = {}
    for _, entry in ipairs(POKEMON) do labels[#labels + 1] = entry.name end
    labels[#labels + 1] = "BACK"
    say(session, "Choose an event POKEMON.\nEach gift is one-time.", function()
      Choice.multi(labels, 0, function(selected)
        local entry = POKEMON[selected + 1]
        if entry then
          claimPokemon(session, entry)
        elseif selected ~= 127 then
          showRoot(session)
        end
      end, { left = 14, top = 4, maxRight = 30 })
    end)
  end

  local function claimTicket(session, ticket)
    local state = archive(session)
    if not state then return end
    if state.tickets[ticket.key] then
      say(session, "You already received the\n" .. ticket.name .. ".")
      return
    end

    session.bag = session.bag or Bag.new()
    local alreadyHave = Bag.has(session.bag, ticket.item, 1)
    if not alreadyHave and not Bag.canAdd(session.bag, ticket.item, 1) then
      say(session, "There is no room in your bag\nfor the " .. ticket.name .. ".")
      return
    end
    if not alreadyHave and not Bag.add(session.bag, ticket.item, 1) then
      say(session, "The " .. ticket.name .. " could not\nbe added to your bag.")
      return
    end

    for _, flag in ipairs(ticket.flags) do
      MysteryGift.setFlag(session, flag, true)
    end
    state.tickets[ticket.key] = true
    if alreadyHave then
      say(session, "Your " .. ticket.name .. " is ready\nto use.")
    else
      say(session, "You received the\n" .. ticket.name .. "!")
    end
  end

  showTickets = function(session)
    local tickets = TICKETS[version] or {}
    local labels = {}
    for _, ticket in ipairs(tickets) do labels[#labels + 1] = ticket.name end
    labels[#labels + 1] = "BACK"
    say(session, "Choose an event item.", function()
      Choice.multi(labels, 0, function(selected)
        local ticket = tickets[selected + 1]
        if ticket then
          claimTicket(session, ticket)
        elseif selected ~= 127 then
          showRoot(session)
        end
      end, { left = 12, top = 4, maxRight = 30 })
    end)
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local rows = next(game, items)
    if type(rows) ~= "table" then return rows end
    local hasFieldSave = false
    for _, row in ipairs(rows) do
      if row.id == "save" then hasFieldSave = true end
      if row.id == "1025dex_events" then return rows end
    end
    if not hasFieldSave then return rows end

    rows[#rows + 1] = {
      id = "1025dex_events",
      label = "EVENTS",
      onSelect = function(_, session)
        StartMenu.close(true)
        showRoot(session)
      end,
    }
    return rows
  end)

  mod.log:info("Event Archive ready: eight one-time species gifts and version-specific tickets.")
end
