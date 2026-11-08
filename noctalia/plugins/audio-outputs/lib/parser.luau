--!nonstrict
-- lib/parser.luau
-- Pure parsing and data model synthesis engine for audio-outputs plugin.
-- Compatible with Luau and Lua 5.5.

local parser = {}

--- Parse ALSA ELD (/proc/asound/card*/eld#*) content to extract monitor_name
function parser.parseEld(eldContent)
  if type(eldContent) ~= "string" or eldContent == "" then
    return nil
  end

  local line = eldContent:match("[^\r\n]*monitor_name%s+([^\r\n]+)")
  if line then
    local name = line:match("^%s*(.-)%s*$")
    if name and name ~= "" then
      return name
    end
  end
  return nil
end

--- Detect appropriate icon glyph for an output item
function parser.detectIcon(item)
  if type(item) ~= "table" then
    return "audio-card-analog"
  end

  local text = string.lower(table.concat({
    item.displayName or "",
    item.rawDescription or "",
    item.portName or "",
    item.sinkName or "",
    item.profileName or "",
  }, " "))

  if text:find("%f[%a]tv%f[%A]") or text:find("television") then
    return "device-tv"
  elseif text:find("headphone") or text:find("headset") then
    return "audio-headphones"
  elseif text:find("usb") then
    return "usb"
  elseif text:find("speaker") or text:find("lineout") or text:find("line%-out") then
    return "audio-speakers"
  elseif text:find("hdmi") or text:find("displayport") or text:find("video%-display") or text:find("ultrawide") or text:find("monitor") then
    return "video-display"
  end

  return "audio-card-analog"
end

--- Helper to safely find a port in a card (supports dictionary or array)
local function getCardPort(card, portName)
  if not card or not card.ports or not portName then
    return nil
  end
  if card.ports[portName] then
    local p = card.ports[portName]
    p.name = p.name or portName
    return p
  end
  if #card.ports > 0 then
    for _, p in ipairs(card.ports) do
      if p.name == portName then
        return p
      end
    end
  end
  return nil
end

--- Find HDMI monitor name from card port properties or ELD data fallback
function parser.findHdmiMonitorName(card, portName, eldData)
  local port = getCardPort(card, portName)
  if port and port.properties and type(port.properties) == "table" then
    local prodName = port.properties["device.product.name"]
    if prodName and prodName ~= "" and not prodName:find("^HDMI") and not prodName:find("^DisplayPort") then
      return prodName
    end
  end

  if eldData and type(eldData) == "table" then
    local raw = eldData[portName]
    if not raw and card and card.name then
      raw = eldData[card.name .. ":" .. portName]
    end
    if type(raw) == "string" then
      local parsed = parser.parseEld(raw)
      if parsed then
        return parsed
      end
      if raw ~= "" and not raw:find("\n") then
        return raw
      end
    end
  end

  return nil
end

--- Check if an active sink matches a card and profile
function parser.matchSinkForProfile(cardName, profileName, sinks)
  if type(sinks) ~= "table" or not profileName then
    return nil
  end

  local cleanProfile = profileName:gsub("%+.*$", ""):gsub("^output:", "")
  local escapedClean = cleanProfile:gsub("%-", "%%-")
  local suffixPattern = "%." .. escapedClean .. "$"

  for _, sink in ipairs(sinks) do
    local props = sink.properties or {}
    local sinkCard = props["device.name"] or props["alsa.card_name"] or props["alsa.card"]
    local sinkProfile = props["device.profile.name"] or ""

    local cardMatch = (not cardName or cardName == "" or sinkCard == cardName)
    local profMatch = false
    if sinkProfile ~= "" and (sinkProfile == profileName or sinkProfile == cleanProfile) then
      profMatch = true
    elseif cleanProfile ~= "" and sink.name then
      if sink.name == cleanProfile or sink.name:match(suffixPattern) ~= nil then
        profMatch = true
      end
    end

    if cardMatch and profMatch then
      return sink
    end
  end

  return nil
end

--- Extract first volume percentage from pactl sink volume table
local function extractVolumePercent(volume)
  if type(volume) == "table" then
    for _, channel in pairs(volume) do
      if type(channel) == "table" then
        local percent = tostring(channel.value_percent or ""):match("(%d+)%%")
        if percent then
          return tonumber(percent) or 0
        end
        if channel.value and tonumber(channel.value) then
          return math.floor((tonumber(channel.value) / 65536) * 100 + 0.5)
        end
      end
    end
  elseif type(volume) == "number" then
    return volume
  end
  return nil
end

--- Clean and synthesize sink display name
local function determineSinkDisplayName(sink, card, portName, eldData, known)
  local props = sink.properties or {}

  -- 1. Check HDMI monitor name
  local monName = parser.findHdmiMonitorName(card, portName, eldData)
  if monName and monName ~= "" then
    return monName
  end

  -- 2. Check alsa.name or node.nick (e.g. "LG ULTRAWIDE", "USB Audio")
  local alsaName = props["alsa.name"]
  if alsaName and alsaName ~= "" and not alsaName:find("Generic") and not alsaName:find("ALC%d+") then
    return alsaName
  end

  local nick = props["node.nick"]
  if nick and nick ~= "" and not nick:find("ALC%d+") then
    return nick
  end

  -- 3. Check knownDevices name before falling back to generic device.description
  local knownName = nil
  if type(known) == "string" and known ~= "" then
    knownName = known
  elseif type(known) == "table" then
    if known.name then
      knownName = known.name
    elseif card and card.name and portName and known[card.name .. ":" .. portName] then
      local entry = known[card.name .. ":" .. portName]
      knownName = type(entry) == "table" and entry.name or entry
    elseif portName and known[portName] then
      local entry = known[portName]
      knownName = type(entry) == "table" and entry.name or entry
    end
  end

  if knownName and knownName ~= "" then
    return knownName
  end

  -- 4. Check device description
  local devDesc = props["device.description"]
  if devDesc and devDesc ~= "" then
    return devDesc
  end

  -- 5. Fallback to sink description or sink name
  return sink.description or sink.name
end

--- Build normalized and sorted outputs list from sinks, cards, and preferences
function parser.buildOutputs(sinks, cards, defaultSinkName, preferences, eldData, includeHidden)
  sinks = sinks or {}
  cards = cards or {}
  preferences = preferences or {}
  local knownDevices = preferences.knownDevices or {}
  local aliases = preferences.aliases or {}
  local icons = preferences.icons or {}
  local hiddenOutputs = preferences.hiddenOutputs or {}
  local showDisconnected = (preferences.show_disconnected ~= false)

  local cardMap = {}
  for _, c in ipairs(cards) do
    if c.name then
      cardMap[c.name] = c
    end
  end

  local outputs = {}

  -- 1. Process active sinks
  for _, sink in ipairs(sinks) do
    local sinkName = sink.name
    local id = "sink:" .. sinkName
    local isHidden = (hiddenOutputs[id] == true)

    if not isHidden or includeHidden then
      local props = sink.properties or {}
      local cardName = props["device.name"] or props["alsa.card_name"] or ""
      local card = cardMap[cardName]
      local profileName = props["device.profile.name"] or ""
      if card and card.active_profile and card.active_profile ~= "" then
        if profileName == "" or card.active_profile:find(profileName, 1, true) then
          profileName = card.active_profile
        elseif not profileName:find("^output:") and not profileName:find("^input:") then
          profileName = "output:" .. profileName
        end
      elseif profileName ~= "" and not profileName:find("^output:") and not profileName:find("^input:") then
        profileName = "output:" .. profileName
      end

      local portName = (type(sink.active_port) == "table" and sink.active_port.name) or sink.active_port

      local isDefault = (sinkName == defaultSinkName)
      local rawDescription = sink.description or props["device.description"] or sinkName

      local known = nil
      if cardName ~= "" and portName then
        known = knownDevices[cardName .. ":" .. portName]
      end
      if not known and portName then
        known = knownDevices[portName]
      end
      local knownName = nil
      if type(known) == "table" and known.name then
        knownName = known.name
      elseif type(known) == "string" then
        knownName = known
      end

      local displayName = aliases[id] or aliases[sinkName] or (portName and aliases[portName])
      if not displayName then
        displayName = determineSinkDisplayName(sink, card, portName, eldData, knownName or known)
      end

      local volume = extractVolumePercent(sink.volume) or 100
      local muted = (sink.mute == true)
      local available = true

      if sink.ports and portName then
        for _, p in ipairs(sink.ports) do
          if p.name == portName and p.availability == "not available" then
            available = false
            break
          end
        end
      end

      local icon = icons[id] or parser.detectIcon({
        displayName = displayName,
        rawDescription = rawDescription,
        portName = portName,
        sinkName = sinkName,
        profileName = profileName,
      })

      table.insert(outputs, {
        id = id,
        kind = "sink",
        sinkName = sinkName,
        cardName = cardName,
        profileName = profileName,
        portName = portName,
        displayName = displayName,
        rawDescription = rawDescription,
        available = available,
        isDefault = isDefault,
        volume = volume,
        muted = muted,
        icon = icon,
        hidden = isHidden,
      })
    end
  end

  -- 2. Process inactive card profiles
  for _, card in ipairs(cards) do
    local cardName = card.name or ""
    local profileList = {}

    if type(card.profiles) == "table" then
      if #card.profiles > 0 then
        profileList = card.profiles
      else
        for profName, profData in pairs(card.profiles) do
          local item = { name = profName }
          for k, v in pairs(profData) do
            item[k] = v
          end
          table.insert(profileList, item)
        end
      end
    end

    -- Build set of existing stereo profile names on this card to filter duplicate surround profiles
    local stereoProfiles = {}
    for _, prof in ipairs(profileList) do
      local pName = prof.name or ""
      if not pName:find("surround") then
        stereoProfiles[pName] = true
      end
    end

    for _, prof in ipairs(profileList) do
      local profName = prof.name or ""
      local skip = false

      -- Skip "off", "pro-audio", or zero-sink profiles
      if profName == "off" or profName == "pro-audio" or (prof.sinks and prof.sinks == 0) then
        skip = true
      end

      -- Skip if this profile already has an active sink
      if not skip and parser.matchSinkForProfile(cardName, profName, sinks) then
        skip = true
      end

      -- Skip duplicate surround profiles if equivalent stereo profile exists
      if not skip and profName:find("surround") then
        local stereoEquivalent = profName:gsub("surround[%-%d]*", "stereo")
        local stereoEquivalentFixed = stereoEquivalent:gsub("stereoextra", "stereo-extra")
        if stereoProfiles[stereoEquivalent] or stereoProfiles[stereoEquivalentFixed] or stereoProfiles[stereoEquivalentFixed:gsub("%-ac3", "")] then
          skip = true
        end
      end

      if not skip then
        -- Find associated port for this profile
        local portName = nil
        local portObj = nil

        if type(card.ports) == "table" then
          if #card.ports > 0 then
            for _, pt in ipairs(card.ports) do
              if pt.profiles and type(pt.profiles) == "table" then
                for _, pp in ipairs(pt.profiles) do
                  if pp == profName then
                    portName = pt.name
                    portObj = pt
                    break
                  end
                end
              end
              if portName then break end
            end
          else
            for ptName, ptData in pairs(card.ports) do
              if ptData.profiles and type(ptData.profiles) == "table" then
                for _, pp in ipairs(ptData.profiles) do
                  if pp == profName then
                    portName = ptName
                    portObj = ptData
                    portObj.name = ptName
                    break
                  end
                end
              end
              if portName then break end
            end
          end
        end

        local id = "profile:" .. cardName .. ":" .. profName
        local isHidden = (hiddenOutputs[id] == true)

        if not isHidden or includeHidden then
          -- Lookup alias
          local alias = aliases[id] or (portName and aliases[portName])

          -- Lookup knownDevices
          local known = nil
          if portName then
            known = knownDevices[cardName .. ":" .. portName] or knownDevices[portName]
          end
          if not known then
            known = knownDevices[cardName .. ":" .. profName] or knownDevices[profName]
          end

          local knownName = nil
          if type(known) == "table" and known.name then
            knownName = known.name
          elseif type(known) == "string" then
            knownName = known
          end

          -- Lookup monitor name
          local monName = parser.findHdmiMonitorName(card, portName, eldData)

          -- Determine physical availability
          local isAvailable = (prof.available == true)
          if portObj and portObj.availability then
            if portObj.availability == "available" then
              isAvailable = true
            elseif portObj.availability == "not available" then
              isAvailable = false
            end
          end

          local isDisplayPort = false
          if portName then
            local pLower = string.lower(portName)
            if pLower:find("^hdmi") or pLower:find("^dp%f[%A]") or pLower:find("^displayport") then
              isDisplayPort = true
            end
          end
          if not isDisplayPort and profName then
            local profLower = string.lower(profName)
            if profLower:find("hdmi") or profLower:find("displayport") or profLower:find("%f[%a]dp%f[%A]") then
              isDisplayPort = true
            end
          end
          if not isDisplayPort and portObj and portObj.type then
            if portObj.type == "DisplayPort" or portObj.type == "HDMI" then
              isDisplayPort = true
            end
          end

          -- Filter out unused ports with no device and no alias
          if isDisplayPort then
            if not isAvailable and not monName and not knownName and not alias then
              skip = true
            end
          else
            -- Non-HDMI/DP inactive profiles: only include if known or aliased
            if not knownName and not alias then
              skip = true
            end
          end

          -- Filter out disconnected if preference forbids
          if not showDisconnected and not isAvailable then
            skip = true
          end

          if not skip then
            local displayName = alias or monName or knownName or prof.description or profName
            local rawDescription = prof.description or profName
            local icon = icons[id] or parser.detectIcon({
              displayName = displayName,
              rawDescription = rawDescription,
              portName = portName,
              profileName = profName,
            })

            table.insert(outputs, {
              id = id,
              kind = "profile",
              sinkName = nil,
              cardName = cardName,
              profileName = profName,
              portName = portName,
              displayName = displayName,
              rawDescription = rawDescription,
              available = isAvailable,
              isDefault = false,
              volume = nil,
              muted = false,
              icon = icon,
              hidden = isHidden,
            })
          end
        end
      end
    end
  end

  -- 3. Sort outputs:
  -- Active default sink first, then available sinks, then available profiles, then disconnected known devices
  table.sort(outputs, function(a, b)
    local function getRank(item)
      if item.isDefault then
        return 1
      elseif item.kind == "sink" and item.available then
        return 2
      elseif item.kind == "profile" and item.available then
        return 3
      else
        return 4
      end
    end

    local rankA = getRank(a)
    local rankB = getRank(b)
    if rankA ~= rankB then
      return rankA < rankB
    end

    return (a.displayName or "") < (b.displayName or "")
  end)

  return outputs
end

return parser
