--!nonstrict
-- Audio Outputs backend service for Noctalia Shell.
-- Provides robust audio output & input management, Bluetooth device handoff,
-- combined output groups, and ALSA Card Profile (ACP) HDMI/DP TV & monitor switching.

local SNAPSHOT_KEY = "audio_outputs_snapshot"
local COMMAND_KEY = "audio_outputs_command"
local RESULT_KEY = "audio_outputs_result"
local PREFERENCES_VERSION = 1
local REFRESH_INTERVAL_MS = 3000
local BLUETOOTH_CONNECT_RETRIES = 16
local BLUETOOTH_CONNECT_RETRY_SECONDS = 0.25
local GROUP_SINK_PREFIX = "noctalia_group_"
local GROUP_DESCRIPTION = "Noctalia_Output_Group"

local dataDir = noctalia and noctalia.pluginDataDir and noctalia.pluginDataDir() or nil
local preferencesPath = dataDir and (dataDir .. "/preferences.json") or nil

local preferences = {
  version = PREFERENCES_VERSION,
  aliases = {},
  hiddenOutputs = {},
  hiddenInputs = {},
  slots = {},
  knownBluetoothInputs = {},
  icons = {},
  knownDevices = {},
}

local snapshot = {
  available = false,
  bluetoothAvailable = false,
  loading = true,
  busy = false,
  scanning = false,
  outputs = {},
  inputs = {},
  bluetooth = {},
  defaultOutputId = "",
  defaultInputId = "",
  outputVolume = 0,
  inputVolume = 0,
  outputMuted = false,
  inputMuted = false,
  error = "",
  updatedAt = 0,
  revision = 0,
}

local refreshPending = false
local refreshAgain = false
local actionBusy = false
local scanning = false
local preferencesDirty = false
local volumeOperations = {
  output = { running = false, pending = nil, desiredValue = nil },
  input = { running = false, pending = nil, desiredValue = nil },
}
local volumeRefreshes = {
  output = { running = false, again = false },
  input = { running = false, again = false },
}
local audioEventRevisions = { output = 0, input = 0 }
local combineSinkOption = "sinks"
local groupNameCounter = 0

local refreshAll
local setOutput
local setInput
local connectBluetooth
local assignSlot

local function trim(value)
  return noctalia and noctalia.string and noctalia.string.trim(tostring(value or ""))
    or tostring(value or ""):match("^%s*(.-)%s*$")
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function shellCommand(args)
  local quoted = {}
  for _, value in ipairs(args) do
    table.insert(quoted, shellQuote(value))
  end
  return table.concat(quoted, " ")
end

local function runCommand(args, callback, timeoutMs)
  if not noctalia or not noctalia.runAsync then
    if type(callback) == "function" then
      callback({ exitCode = -1, stdout = "", stderr = "noctalia.runAsync unavailable" })
    end
    return false
  end
  local started = noctalia.runAsync(shellCommand(args), callback, timeoutMs or 15000)
  if not started and type(callback) == "function" then
    callback({
      exitCode = -1,
      stdout = "",
      stderr = noctalia.tr and noctalia.tr("errors.command_start") or "Command failed to start",
      timedOut = false,
      stdoutTruncated = false,
      stderrTruncated = false,
    })
  end
  return started
end

local function runPactl(args, callback, timeoutMs)
  local command = { "env", "LC_ALL=C", "pactl" }
  for _, value in ipairs(args) do table.insert(command, value) end
  return runCommand(command, callback, timeoutMs)
end

local function runBluetoothctl(args, callback, timeoutMs)
  local command = { "bluetoothctl" }
  for _, value in ipairs(args) do table.insert(command, value) end
  return runCommand(command, callback, timeoutMs or 30000)
end

local function decodeJson(value)
  if not noctalia or not noctalia.json or not noctalia.json.decode then return nil end
  local str = tostring(value or "")
  if str == "" then return nil end
  local ok, decoded = pcall(noctalia.json.decode, str)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function normalizeMap(value)
  return type(value) == "table" and value or {}
end

local function setPreference(map, key, value)
  if map[key] == value then return false end
  map[key] = value
  preferencesDirty = true
  return true
end

local function validIconStyle(value)
  value = tostring(value or "automatic")
  if value == "speaker" or value == "over_ear" or value == "tws" or value == "wired" then return value end
  return "automatic"
end

local function loadPreferences()
  if preferencesPath == nil or not noctalia or not noctalia.readFile then return end
  local raw = noctalia.readFile(preferencesPath)
  if raw == nil then return end
  local decoded = decodeJson(raw)
  if decoded == nil then return end
  preferences.version = PREFERENCES_VERSION
  preferences.aliases = normalizeMap(decoded.aliases)
  preferences.hiddenOutputs = normalizeMap(decoded.hiddenOutputs)
  preferences.hiddenInputs = normalizeMap(decoded.hiddenInputs)
  preferences.slots = normalizeMap(decoded.slots)
  preferences.knownBluetoothInputs = normalizeMap(decoded.knownBluetoothInputs)
  preferences.icons = normalizeMap(decoded.icons)
  preferences.knownDevices = normalizeMap(decoded.knownDevices)
end

local function savePreferences()
  if not preferencesDirty then return true end
  if preferencesPath == nil or not noctalia or not noctalia.writeFile or not noctalia.json then return false end
  local encoded, encodeError = noctalia.json.encode(preferences, true)
  if encoded == nil then
    return false
  end
  local ok = noctalia.writeFile(preferencesPath, encoded)
  if ok then
    preferencesDirty = false
  end
  return ok == true
end

local function bluetoothOutputId(address)
  return "bluetooth:" .. address:upper() .. ":output"
end

local function bluetoothInputId(address)
  return "bluetooth:" .. address:upper() .. ":input"
end

local function bluetoothAddressFromId(id)
  return tostring(id or ""):match("^bluetooth:([%x:]+):")
end

local function displayName(id, fallback)
  local alias = trim(preferences.aliases[id])
  return alias ~= "" and alias or fallback
end

local function resolvedDeviceIcon(id, automaticIcon)
  local style = validIconStyle(preferences.icons[id])
  local glyphs = {
    speaker = "device-speaker",
    over_ear = "headphones",
    tws = "device-airpods",
    wired = "headset",
  }
  return glyphs[style] or automaticIcon, style
end

local function firstVolumePercent(volume)
  if type(volume) ~= "table" then return 0 end
  for _, channel in pairs(volume) do
    if type(channel) == "table" then
      local percent = tostring(channel.value_percent or ""):match("(%d+)%%")
      if percent ~= nil then return tonumber(percent) or 0 end
      if channel.value and tonumber(channel.value) then
        return math.floor((tonumber(channel.value) / 65536) * 100 + 0.5)
      end
    end
  end
  return 0
end

local function parseCurrentVolume(output)
  local decoded = decodeJson(output)
  if type(decoded) == "table" and type(decoded.volume) == "table" then
    return firstVolumePercent(decoded.volume)
  end
  return tonumber(tostring(output or ""):match("(%d+)%%"))
end

local function parseCurrentMute(output)
  local decoded = decodeJson(output)
  if type(decoded) == "table" and type(decoded.mute) == "boolean" then
    return decoded.mute
  end
  local value = tostring(output or ""):match("Mute:%s*(%a+)")
  if value == "yes" then return true end
  if value == "no" then return false end
  return nil
end

local function propertiesOf(item)
  return type(item.properties) == "table" and item.properties or {}
end

local function inputPortText(value)
  return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function parseInputPorts(item)
  local activeValue = type(item.active_port) == "table" and item.active_port.name or item.active_port
  local activeName = inputPortText(activeValue)
  local ports = {}
  for _, port in ipairs(type(item.ports) == "table" and item.ports or {}) do
    if type(port) == "table" then
      local name = inputPortText(port.name)
      if name ~= "" then
        local description = inputPortText(port.description)
        local availability = inputPortText(port.availability):lower()
        ports[#ports + 1] = {
          name = name,
          description = description ~= "" and description or name,
          available = availability ~= "not available",
          active = name == activeName,
        }
      end
    end
  end
  return ports, activeName
end

local function bluetoothAddress(properties)
  local value = trim(properties["api.bluez5.address"])
  if value == "" and properties["device.bus"] == "bluetooth" then
    value = trim(properties["device.string"])
  end
  return value:upper()
end

local function detectGpuMonitorIcon(name)
  local text = string.lower(tostring(name or ""))
  if text:find("%f[%a]tv%f[%A]") or text:find("television") or text:find("panasonic") then
    return "device-tv"
  end
  return "video-display"
end

local function makeOutput(item, defaultName, group)
  local properties = propertiesOf(item)
  local address = bluetoothAddress(properties)
  local isBluetooth = address ~= ""
  local stableId = isBluetooth and bluetoothOutputId(address) or tostring(item.name or "")
  local fallback = tostring(properties["device.alias"] or item.description or item.name or stableId)
  if group ~= nil then fallback = noctalia.tr("device.output_group") end
  local defaultIcon = group ~= nil and "link" or (isBluetooth and "headphones" or "device-speaker")
  local icon, iconStyle = resolvedDeviceIcon(stableId, defaultIcon)
  return {
    id = stableId,
    targetName = tostring(item.name or ""),
    name = displayName(stableId, fallback),
    description = tostring(item.description or item.name or ""),
    active = tostring(item.name or "") == defaultName,
    available = true,
    bluetooth = isBluetooth,
    address = address,
    hidden = preferences.hiddenOutputs[stableId] == true,
    slot = isBluetooth and tonumber(preferences.slots[address]) or nil,
    volume = firstVolumePercent(item.volume),
    muted = item.mute == true,
    icon = icon,
    iconStyle = iconStyle,
    group = group ~= nil,
    groupModuleId = group and group.moduleId or nil,
    groupMembers = group and group.members or nil,
    kind = "sink",
  }
end

local function makeInput(item, defaultName)
  local properties = propertiesOf(item)
  if tostring(properties["device.class"] or "") == "monitor" or tostring(item.name or ""):match("%.monitor$") then
    return nil
  end
  local address = bluetoothAddress(properties)
  local isBluetooth = address ~= ""
  local stableId = isBluetooth and bluetoothInputId(address) or tostring(item.name or "")
  local fallback = tostring(properties["device.alias"] or item.description or item.name or stableId)
  if isBluetooth then setPreference(preferences.knownBluetoothInputs, address, fallback) end
  local ports, activePortName = parseInputPorts(item)
  local activePortDescription = ""
  for _, port in ipairs(ports) do
    if port.active then activePortDescription = port.description break end
  end
  local portLooksLikeHeadset = (activePortName .. " " .. activePortDescription):lower():find("headset", 1, true) ~= nil
  local icon, iconStyle = resolvedDeviceIcon(
    stableId,
    isBluetooth and "headset" or (portLooksLikeHeadset and "headset" or "microphone")
  )
  return {
    id = stableId,
    targetName = tostring(item.name or ""),
    name = displayName(stableId, fallback),
    description = tostring(item.description or item.name or ""),
    active = tostring(item.name or "") == defaultName,
    available = true,
    bluetooth = isBluetooth,
    address = address,
    hidden = preferences.hiddenInputs[stableId] == true,
    slot = isBluetooth and tonumber(preferences.slots[address]) or nil,
    volume = firstVolumePercent(item.volume),
    muted = item.mute == true,
    icon = icon,
    iconStyle = iconStyle,
    ports = ports,
    activePort = activePortName,
    activePortDescription = activePortDescription,
  }
end

local function sortDevices(devices)
  table.sort(devices, function(a, b)
    if a.active ~= b.active then return a.active end
    if a.available ~= b.available then return a.available end
    return tostring(a.name):lower() < tostring(b.name):lower()
  end)
end

local function parseInfo(output)
  local decoded = decodeJson(output)
  if type(decoded) ~= "table" then return nil end
  return {
    serverName = tostring(decoded.server_name or decoded.ServerName or ""),
    defaultSink = tostring(decoded.default_sink_name or decoded.DefaultSinkName or ""),
    defaultSource = tostring(decoded.default_source_name or decoded.DefaultSourceName or ""),
  }
end

local function parseOutputGroups(output)
  local groups = {}
  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    local moduleId, moduleName, rawArguments = line:match("^(%d+)%s+([%w%-_]+)%s*(.*)$")
    if moduleId ~= nil and moduleName == "module-combine-sink" then
      local sinkName = rawArguments:match("sink_name=([^%s]+)")
      local isNoctaliaGroup = sinkName ~= nil and sinkName:find(GROUP_SINK_PREFIX, 1, true) == 1
      if isNoctaliaGroup then
        local membersRaw = rawArguments:match("slaves=([^%s]+)") or rawArguments:match("sinks=([^%s]+)")
        local members = {}
        for member in tostring(membersRaw or ""):gmatch("[^,]+") do
          table.insert(members, member)
        end
        groups[sinkName] = {
          moduleId = tonumber(moduleId),
          sinkName = sinkName,
          members = members,
        }
      end
    end
  end
  return groups
end

local function matchSinkForProfile(cardName, profileName, sinks)
  if type(sinks) ~= "table" or not profileName then return nil end
  local cleanProfile = profileName:gsub("%+.*$", ""):gsub("^output:", "")
  local escapedClean = cleanProfile:gsub("%-", "%%-")
  local suffixPattern = "%." .. escapedClean .. "$"

  for _, sink in ipairs(sinks) do
    local props = propertiesOf(sink)
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
    if cardMatch and profMatch then return sink end
  end
  return nil
end

local function synthesizeCardProfiles(cards, sinks, defaultSinkName)
  local profileOutputs = {}
  local showDisconnected = true
  if noctalia and noctalia.getConfig then
    local cfg = noctalia.getConfig("show_disconnected")
    if cfg ~= nil then showDisconnected = cfg end
  end

  for _, card in ipairs(type(cards) == "table" and cards or {}) do
    local cardName = tostring(card.name or "")
    local profileList = {}
    if type(card.profiles) == "table" then
      if #card.profiles > 0 then
        profileList = card.profiles
      else
        for profName, profData in pairs(card.profiles) do
          local item = { name = profName }
          for k, v in pairs(profData) do item[k] = v end
          table.insert(profileList, item)
        end
      end
    end

    local stereoProfiles = {}
    for _, prof in ipairs(profileList) do
      local pName = tostring(prof.name or "")
      if not pName:find("surround") then stereoProfiles[pName] = true end
    end

    for _, prof in ipairs(profileList) do
      local profName = tostring(prof.name or "")
      local skip = false

      if profName == "off" or profName == "pro-audio" or (prof.sinks and prof.sinks == 0) then
        skip = true
      end

      -- If an active sink already exists for this profile, skip
      if not skip and matchSinkForProfile(cardName, profName, sinks) ~= nil then
        skip = true
      end

      -- Deduplicate surround profiles if stereo equivalent exists
      if not skip and profName:find("surround") then
        local stereoEquiv = profName:gsub("surround[%-%d]*", "stereo"):gsub("stereoextra", "stereo-extra")
        if stereoProfiles[stereoEquiv] or stereoProfiles[stereoEquiv:gsub("%-ac3", "")] then
          skip = true
        end
      end

      if not skip then
        local portName = nil
        local portObj = nil
        if type(card.ports) == "table" then
          if #card.ports > 0 then
            for _, pt in ipairs(card.ports) do
              if type(pt.profiles) == "table" then
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
              if type(ptData.profiles) == "table" then
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

        local stableId = "profile:" .. cardName .. ":" .. profName
        local isHidden = preferences.hiddenOutputs[stableId] == true

        local isAvailable = (prof.available == true)
        local monitorName = nil
        if portObj and type(portObj.properties) == "table" then
          local pName = portObj.properties["device.product.name"]
          if pName and pName ~= "" and not pName:find("^HDMI") and not pName:find("^DisplayPort") then
            monitorName = pName
          end
        end

        if portObj and portObj.availability then
          if portObj.availability == "available" then
            isAvailable = true
          elseif portObj.availability == "not available" then
            isAvailable = false
          end
        end

        -- Cache discovered monitor name in preferences
        if monitorName and portName then
          local kKey = cardName .. ":" .. portName
          if not preferences.knownDevices[kKey] or preferences.knownDevices[kKey].name ~= monitorName then
            preferences.knownDevices[kKey] = { name = monitorName, lastSeen = os.time() }
            preferencesDirty = true
          end
        elseif portName and preferences.knownDevices[cardName .. ":" .. portName] then
          monitorName = preferences.knownDevices[cardName .. ":" .. portName].name
        end

        local isDisplayPort = false
        if portName and (portName:find("hdmi") or portName:find("displayport") or portName:find("dp")) then
          isDisplayPort = true
        end
        if not isDisplayPort and (profName:find("hdmi") or profName:find("displayport")) then
          isDisplayPort = true
        end

        -- Only show meaningful profiles
        if isDisplayPort then
          if not isAvailable and not monitorName and not preferences.aliases[stableId] then
            skip = true
          end
        else
          if not monitorName and not preferences.aliases[stableId] then
            skip = true
          end
        end

        if not showDisconnected and not isAvailable then
          skip = true
        end

        if not skip then
          local fallbackName = monitorName or prof.description or profName
          local defaultIcon = detectGpuMonitorIcon(fallbackName)
          local icon, iconStyle = resolvedDeviceIcon(stableId, defaultIcon)

          table.insert(profileOutputs, {
            id = stableId,
            targetName = stableId,
            cardName = cardName,
            profileName = profName,
            portName = portName,
            name = displayName(stableId, fallbackName),
            description = tostring(prof.description or profName),
            active = false,
            available = isAvailable,
            bluetooth = false,
            hidden = isHidden,
            slot = nil,
            volume = nil,
            muted = false,
            icon = icon,
            iconStyle = iconStyle,
            group = false,
            kind = "profile",
          })
        end
      end
    end
  end

  return profileOutputs
end

local function parseOutputs(output, defaultName, groups)
  local decoded = decodeJson(output)
  local outputs = {}
  if type(decoded) == "table" then
    for _, item in ipairs(decoded) do
      local group = groups and groups[tostring(item.name or "")] or nil
      table.insert(outputs, makeOutput(item, defaultName, group))
    end
  end
  return outputs
end

local function parseInputs(output, defaultName)
  local decoded = decodeJson(output)
  local inputs = {}
  if type(decoded) == "table" then
    for _, item in ipairs(decoded) do
      local parsed = makeInput(item, defaultName)
      if parsed ~= nil then table.insert(inputs, parsed) end
    end
  end
  return inputs
end

local function parseBluetoothDeviceLines(output)
  local devices = {}
  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    local address, name = line:match("^Device%s+([%x:]+)%s*(.*)$")
    if address ~= nil then
      table.insert(devices, { address = address:upper(), name = trim(name) })
    end
  end
  return devices
end

local function isAudioBluetoothDevice(output)
  local hasAudioUuid = false
  local isPaired = false
  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    local uuid = line:match("UUID:%s*(.-)%s*%(")
    if uuid ~= nil then
      local lower = uuid:lower()
      if lower:find("audio sink") or lower:find("audio source") or lower:find("a2dp") or lower:find("handsfree") or lower:find("headset") then
        hasAudioUuid = true
      end
    end
    if line:match("Paired:%s*yes") then isPaired = true end
  end
  return isPaired and hasAudioUuid
end

local function parseBluetoothDeviceDetails(address, output)
  local name = nil
  local icon = "headphones"
  local connected = false
  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    local alias = line:match("^%s*Alias:%s*(.*)$")
    if alias ~= nil and trim(alias) ~= "" then name = trim(alias) end
    local connectedValue = line:match("^%s*Connected:%s*(%a+)")
    if connectedValue ~= nil then connected = connectedValue == "yes" end
    local iconValue = line:match("^%s*Icon:%s*(.*)$")
    if iconValue ~= nil and trim(iconValue) ~= "" then
      local iconLower = trim(iconValue):lower()
      if iconLower:find("audio%-card") then
        icon = "device-speaker"
      elseif iconLower:find("audio%-headset") or iconLower:find("headset") then
        icon = "headset"
      else
        icon = "headphones"
      end
    end
  end
  return {
    address = address:upper(),
    name = name or address:upper(),
    icon = icon,
    connected = connected,
  }
end

local function findOutputById(id)
  for _, output in ipairs(type(snapshot.outputs) == "table" and snapshot.outputs or {}) do
    if output.id == id then return output end
  end
  return nil
end

local function findInputById(id)
  for _, input in ipairs(type(snapshot.inputs) == "table" and snapshot.inputs or {}) do
    if input.id == id then return input end
  end
  return nil
end

local function findAddressBySlot(slot)
  local requested = tonumber(slot)
  if requested == nil then return nil end
  for address, value in pairs(preferences.slots) do
    if tonumber(value) == requested then return address end
  end
  return nil
end

local function publishSnapshot()
  snapshot.busy = actionBusy
  snapshot.scanning = scanning
  snapshot.revision = snapshot.revision + 1
  if noctalia and noctalia.state and noctalia.state.set then
    noctalia.state.set(SNAPSHOT_KEY, snapshot)
  end
end

local function notifyResult(success, message, icon)
  if not noctalia or not noctalia.notify or trim(message) == "" then return end
  local title = noctalia.tr and noctalia.tr("panel.title") or "Audio Switcher"
  noctalia.notify(title, message, icon or (success and "volume" or "dialog-warning"))
end

local function resultMessage(command, success, message)
  if not noctalia or not noctalia.state or not noctalia.state.set then return end
  local commandTable = type(command) == "table" and command or {}
  noctalia.state.set(RESULT_KEY, {
    requestId = commandTable.requestId or ("cmd-" .. tostring(os.time())),
    action = commandTable.action or "unknown",
    success = success == true,
    message = message or "",
    timestamp = os.time(),
  })
end

local function finishAction(command, success, message, notify)
  actionBusy = false
  publishSnapshot()
  resultMessage(command, success, message)
  if notify and trim(message) ~= "" then notifyResult(success, message) end
  refreshAll()
end

local function launchOrFail(args, callback, timeoutMs)
  local started = runPactl(args, callback, timeoutMs)
  if not started then
    callback({
      exitCode = -1,
      stdout = "",
      stderr = noctalia.tr and noctalia.tr("errors.command_start") or "Command failed",
      timedOut = false,
      stdoutTruncated = false,
      stderrTruncated = false,
    })
  end
end

local function updateActiveDeviceVolume(kind, volume, muted)
  local devices = kind == "output" and snapshot.outputs or snapshot.inputs
  for _, device in ipairs(type(devices) == "table" and devices or {}) do
    if device.active then
      device.volume = volume
      device.muted = muted
      break
    end
  end
end

local function reconcileVolumeDisplay(kind, sourceVolume)
  local state = volumeOperations[kind]
  if state.desiredValue ~= nil then return state.desiredValue end
  return sourceVolume
end

local function refreshCurrentVolume(kind)
  local target = kind == "output" and "@DEFAULT_SINK@" or "@DEFAULT_SOURCE@"
  local volumeCommand = kind == "output" and "get-sink-volume" or "get-source-volume"
  local muteCommand = kind == "output" and "get-sink-mute" or "get-source-mute"
  local state = volumeRefreshes[kind]
  if state.running then
    state.again = true
    return
  end
  state.running = true
  runPactl({ "-f", "json", volumeCommand, target }, function(volumeResult)
    if volumeResult.exitCode ~= 0 then
      state.running = false
      if state.again then
        state.again = false
        refreshCurrentVolume(kind)
      end
      return
    end
    runPactl({ "-f", "json", muteCommand, target }, function(muteResult)
      state.running = false
      local volume = parseCurrentVolume(volumeResult.stdout)
      local muted = parseCurrentMute(muteResult.stdout)
      if volume ~= nil then
        if kind == "output" then
          snapshot.outputVolume = reconcileVolumeDisplay("output", volume)
        else
          snapshot.inputVolume = reconcileVolumeDisplay("input", volume)
        end
      end
      if muted ~= nil then
        if kind == "output" then snapshot.outputMuted = muted else snapshot.inputMuted = muted end
      end
      local currentVolume = kind == "output" and snapshot.outputVolume or snapshot.inputVolume
      local currentMuted = kind == "output" and snapshot.outputMuted or snapshot.inputMuted
      updateActiveDeviceVolume(kind, currentVolume, currentMuted)
      publishSnapshot()
      if state.again then
        state.again = false
        refreshCurrentVolume(kind)
      end
    end)
  end)
end

local function loadAudio(callback)
  local outputEventRevision = audioEventRevisions.output
  local inputEventRevision = audioEventRevisions.input
  runPactl({ "-f", "json", "info" }, function(infoResult)
    if infoResult.exitCode ~= 0 then
      callback(false, trim(infoResult.stderr))
      return
    end
    local info = parseInfo(infoResult.stdout)
    if info == nil then
      callback(false, noctalia.tr and noctalia.tr("errors.invalid_audio_data") or "Invalid audio data")
      return
    end
    combineSinkOption = info.serverName:find("PipeWire", 1, true) ~= nil and "sinks" or "slaves"
    runPactl({ "list", "short", "modules" }, function(moduleResult)
      local groups = moduleResult.exitCode == 0 and parseOutputGroups(moduleResult.stdout) or {}
      runPactl({ "-f", "json", "list", "sinks" }, function(sinkResult)
        if sinkResult.exitCode ~= 0 then
          callback(false, trim(sinkResult.stderr))
          return
        end
        runPactl({ "-f", "json", "list", "sources" }, function(sourceResult)
          if sourceResult.exitCode ~= 0 then
            callback(false, trim(sourceResult.stderr))
            return
          end
          runPactl({ "-f", "json", "list", "cards" }, function(cardResult)
            local cards = cardResult.exitCode == 0 and decodeJson(cardResult.stdout) or {}
            local sinks = decodeJson(sinkResult.stdout) or {}

            local currentOutputVolume = snapshot.outputVolume
            local currentInputVolume = snapshot.inputVolume
            local currentOutputMuted = snapshot.outputMuted
            local currentInputMuted = snapshot.inputMuted

            local standardOutputs = parseOutputs(sinkResult.stdout, info.defaultSink, groups)
            local profileOutputs = synthesizeCardProfiles(cards, sinks, info.defaultSink)

            -- Merge standard outputs and card profile outputs
            local allOutputs = {}
            for _, out in ipairs(standardOutputs) do table.insert(allOutputs, out) end
            for _, prof in ipairs(profileOutputs) do table.insert(allOutputs, prof) end

            snapshot.outputs = allOutputs
            snapshot.inputs = parseInputs(sourceResult.stdout, info.defaultSource)
            snapshot.defaultOutputId = ""
            snapshot.defaultInputId = ""
            snapshot.outputVolume = 0
            snapshot.inputVolume = 0
            snapshot.outputMuted = false
            snapshot.inputMuted = false

            for _, output in ipairs(snapshot.outputs) do
              if output.active then
                snapshot.defaultOutputId = output.id
                snapshot.outputVolume = output.volume or 0
                snapshot.outputMuted = output.muted
                break
              end
            end
            for _, input in ipairs(snapshot.inputs) do
              if input.active then
                snapshot.defaultInputId = input.id
                snapshot.inputVolume = input.volume or 0
                snapshot.inputMuted = input.muted
                break
              end
            end

            if audioEventRevisions.output ~= outputEventRevision then
              snapshot.outputVolume = currentOutputVolume
              snapshot.outputMuted = currentOutputMuted
            else
              snapshot.outputVolume = reconcileVolumeDisplay("output", snapshot.outputVolume)
            end
            if audioEventRevisions.input ~= inputEventRevision then
              snapshot.inputVolume = currentInputVolume
              snapshot.inputMuted = currentInputMuted
            else
              snapshot.inputVolume = reconcileVolumeDisplay("input", snapshot.inputVolume)
            end

            updateActiveDeviceVolume("output", snapshot.outputVolume, snapshot.outputMuted)
            updateActiveDeviceVolume("input", snapshot.inputVolume, snapshot.inputMuted)
            callback(true, "")
          end)
        end)
      end)
    end)
  end)
end

local function loadBluetooth(callback)
  if not noctalia or not noctalia.commandExists or not noctalia.commandExists("bluetoothctl") then
    snapshot.bluetoothAvailable = false
    snapshot.bluetooth = {}
    callback()
    return
  end
  runBluetoothctl({ "devices" }, function(listResult)
    if listResult.exitCode ~= 0 then
      snapshot.bluetoothAvailable = false
      snapshot.bluetooth = {}
      callback()
      return
    end
    snapshot.bluetoothAvailable = true
    local seeds = parseBluetoothDeviceLines(listResult.stdout)
    local devices = {}
    local index = 1
    local function nextDevice()
      local seed = seeds[index]
      if seed == nil then
        local audioDevices = {}
        local checked = 1
        local function checkAudioDevice()
          local candidate = devices[checked]
          if candidate == nil then
            snapshot.bluetooth = audioDevices
            callback()
            return
          end
          runBluetoothctl({ "info", candidate.address }, function(infoResult)
            if infoResult.exitCode == 0 and isAudioBluetoothDevice(infoResult.stdout) then
              table.insert(audioDevices, candidate)
            end
            checked = checked + 1
            checkAudioDevice()
          end)
        end
        checkAudioDevice()
        return
      end
      runBluetoothctl({ "info", seed.address }, function(infoResult)
        if infoResult.exitCode == 0 then
          table.insert(devices, parseBluetoothDeviceDetails(seed.address, infoResult.stdout))
        end
        index = index + 1
        nextDevice()
      end)
    end
    nextDevice()
  end)
end

local function mergeDisconnectedBluetoothOutputs()
  local existingByAddress = {}
  for _, output in ipairs(snapshot.outputs) do
    if output.address and output.address ~= "" then existingByAddress[output.address] = true end
  end
  for _, device in ipairs(snapshot.bluetooth) do
    if not device.connected and not existingByAddress[device.address] then
      local stableId = bluetoothOutputId(device.address)
      local icon, iconStyle = resolvedDeviceIcon(stableId, device.icon or "headphones")
      table.insert(snapshot.outputs, {
        id = stableId,
        targetName = "",
        name = displayName(stableId, device.name),
        description = device.address,
        active = false,
        available = false,
        bluetooth = true,
        address = device.address,
        hidden = preferences.hiddenOutputs[stableId] == true,
        slot = tonumber(preferences.slots[device.address]) or nil,
        volume = 0,
        muted = false,
        icon = icon,
        iconStyle = iconStyle,
        group = false,
        kind = "sink",
      })
    end
  end
  sortDevices(snapshot.outputs)
  sortDevices(snapshot.inputs)
end

refreshAll = function()
  if refreshPending then
    refreshAgain = true
    return
  end
  refreshPending = true
  refreshAgain = false
  loadAudio(function(audioOk, audioError)
    snapshot.available = audioOk
    snapshot.error = audioOk and "" or (trim(audioError) ~= "" and audioError or (noctalia.tr and noctalia.tr("errors.audio_unavailable") or "Audio unavailable"))
    loadBluetooth(function()
      mergeDisconnectedBluetoothOutputs()
      snapshot.loading = false
      snapshot.updatedAt = os.time()
      refreshPending = false
      savePreferences()
      publishSnapshot()
      if refreshAgain then refreshAll() end
    end)
  end)
end

local function moveStreams(kind, targetName, callback)
  local listKind = kind == "output" and "sink-inputs" or "source-outputs"
  local moveCommand = kind == "output" and "move-sink-input" or "move-source-output"
  runPactl({ "-f", "json", "list", listKind }, function(result)
    local streams = result.exitCode == 0 and decodeJson(result.stdout) or nil
    if type(streams) ~= "table" or #streams == 0 then
      callback()
      return
    end
    local pending = 0
    for _, stream in ipairs(streams) do
      local index = tonumber(stream.index)
      if index ~= nil then
        pending = pending + 1
        runPactl({ moveCommand, tostring(index), targetName }, function()
          pending = pending - 1
          if pending == 0 then callback() end
        end)
      end
    end
    if pending == 0 then callback() end
  end)
end

local function setDefaultTarget(command, kind, device)
  local setCommand = kind == "output" and "set-default-sink" or "set-default-source"
  if device == nil or trim(device.targetName) == "" then
    finishAction(command, false, noctalia.tr and noctalia.tr("errors.device_unavailable") or "Device unavailable")
    return
  end
  actionBusy = true
  publishSnapshot()
  launchOrFail({ setCommand, device.targetName }, function(result)
    if result.exitCode ~= 0 then
      finishAction(command, false, trim(result.stderr) ~= "" and trim(result.stderr) or (noctalia.tr and noctalia.tr("errors.switch_failed") or "Switch failed"))
      return
    end
    moveStreams(kind, device.targetName, function()
      local messageKey = kind == "output" and "notifications.output_selected" or "notifications.input_selected"
      local fallbackMsg = kind == "output" and "Output switched" or "Input switched"
      finishAction(command, true, noctalia.tr and noctalia.tr(messageKey, { device = device.name }) or fallbackMsg, noctalia.getConfig and noctalia.getConfig("show_notification_on_switch"))
    end)
  end)
end

local function setOutputDevice(command, device)
  if device == nil then
    finishAction(command, false, noctalia.tr and noctalia.tr("errors.device_unavailable") or "Device unavailable")
    return
  end
  if device.kind == "profile" then
    actionBusy = true
    publishSnapshot()
    local cardName = device.cardName
    local profileName = device.profileName
    runPactl({ "set-card-profile", cardName, profileName }, function(result)
      if result.exitCode ~= 0 then
        finishAction(command, false, trim(result.stderr) ~= "" and trim(result.stderr) or (noctalia.tr and noctalia.tr("errors.profile_switch_failed") or "Profile switch failed"))
        return
      end
      -- Await newly spawned sink
      local maxAttempts = 14
      local attempts = 0
      local function checkSink()
        attempts = attempts + 1
        runPactl({ "-f", "json", "list", "sinks" }, function(sinkRes)
          if sinkRes.exitCode == 0 then
            local sinks = decodeJson(sinkRes.stdout)
            if type(sinks) == "table" then
              local matched = matchSinkForProfile(cardName, profileName, sinks)
              if matched and matched.name then
                runPactl({ "set-default-sink", matched.name }, function(_defRes)
                  moveStreams("output", matched.name, function()
                    local notifyKey = "notifications.output_selected"
                    local notifyMsg = noctalia.tr and noctalia.tr(notifyKey, { device = device.name }) or "Output switched"
                    finishAction(command, true, notifyMsg, noctalia.getConfig and noctalia.getConfig("show_notification_on_switch"))
                  end)
                end)
                return
              end
            end
          end
          if attempts >= maxAttempts then
            finishAction(command, false, noctalia.tr and noctalia.tr("errors.sink_spawn_timeout") or "Sink timeout")
          else
            runCommand({ "sleep", "0.25" }, checkSink)
          end
        end)
      end
      checkSink()
    end)
  else
    setDefaultTarget(command, "output", device)
  end
end

setOutput = function(command, id)
  if actionBusy then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.busy") or "Busy")
    return
  end
  local device = findOutputById(id)
  if device == nil then
    finishAction(command, false, noctalia.tr and noctalia.tr("errors.device_not_found") or "Device not found")
    return
  end
  if device.bluetooth and not device.available then
    connectBluetooth(command, device.address)
    return
  end
  setOutputDevice(command, device)
end

setInput = function(command, id, portName)
  if actionBusy then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.busy") or "Busy")
    return
  end
  local device = findInputById(id)
  if device == nil then
    finishAction(command, false, noctalia.tr and noctalia.tr("errors.device_not_found") or "Device not found")
    return
  end
  if portName ~= nil and trim(portName) ~= "" and trim(portName) ~= trim(device.activePort) then
    local matchedPort = nil
    for _, port in ipairs(type(device.ports) == "table" and device.ports or {}) do
      if port.name == portName then
        matchedPort = port
        break
      end
    end
    if matchedPort == nil then
      finishAction(command, false, noctalia.tr and noctalia.tr("errors.input_port_not_found") or "Input port not found")
      return
    end
    if not matchedPort.available then
      finishAction(command, false, noctalia.tr and noctalia.tr("errors.input_port_unavailable") or "Port unavailable")
      return
    end
    actionBusy = true
    publishSnapshot()
    runPactl({ "set-source-port", device.targetName, portName }, function(portResult)
      if portResult.exitCode ~= 0 then
        finishAction(command, false, trim(portResult.stderr) ~= "" and trim(portResult.stderr) or (noctalia.tr and noctalia.tr("errors.input_port_switch_failed") or "Port switch failed"))
        return
      end
      runPactl({ "set-default-source", device.targetName }, function(defaultResult)
        if defaultResult.exitCode ~= 0 then
          finishAction(command, false, trim(defaultResult.stderr) ~= "" and trim(defaultResult.stderr) or (noctalia.tr and noctalia.tr("errors.switch_failed") or "Switch failed"))
          return
        end
        moveStreams("input", device.targetName, function()
          local msg = noctalia.tr and noctalia.tr("notifications.input_port_selected", { port = matchedPort.description }) or "Port switched"
          finishAction(command, true, msg, noctalia.getConfig and noctalia.getConfig("show_notification_on_switch"))
        end)
      end)
    end)
    return
  end
  setDefaultTarget(command, "input", device)
end

local function cycleDevices(command, kind)
  local devices = kind == "output" and snapshot.outputs or snapshot.inputs
  local candidates = {}
  local activeIndex = nil
  for _, device in ipairs(type(devices) == "table" and devices or {}) do
    if not device.hidden and device.available then
      table.insert(candidates, device)
      if device.active then activeIndex = #candidates end
    end
  end
  if #candidates == 0 then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.no_visible_devices") or "No visible devices")
    return
  end
  local nextIndex = 1
  if activeIndex ~= nil then
    nextIndex = (activeIndex % #candidates) + 1
  end
  local target = candidates[nextIndex]
  if kind == "output" then
    setOutput(command, target.id)
  else
    setInput(command, target.id)
  end
end

local function uniqueGroupSinkName()
  groupNameCounter = groupNameCounter + 1
  local base = GROUP_SINK_PREFIX .. tostring(os.time()) .. "_" .. tostring(groupNameCounter)
  local candidate = base
  local suffix = 1
  while findOutputById(candidate) ~= nil do
    suffix = suffix + 1
    candidate = base .. "_" .. tostring(suffix)
  end
  return candidate
end

local function createOutputGroup(command)
  if actionBusy then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.busy") or "Busy")
    return
  end
  local selected = {}
  local seen = {}
  for _, id in ipairs(type(command.ids) == "table" and command.ids or {}) do
    local device = findOutputById(tostring(id or ""))
    if device ~= nil and device.available and not device.group and trim(device.targetName) ~= "" and not seen[device.id] then
      seen[device.id] = true
      table.insert(selected, device)
    end
  end
  if #selected < 2 then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.group_requires_two") or "Select 2+ outputs")
    return
  end

  local targetNames = {}
  for _, device in ipairs(selected) do table.insert(targetNames, device.targetName) end
  local sinkName = uniqueGroupSinkName()
  actionBusy = true
  publishSnapshot()
  runPactl({
    "load-module",
    "module-combine-sink",
    "sink_name=" .. sinkName,
    combineSinkOption .. "=" .. table.concat(targetNames, ","),
    "sink_properties=device.description=" .. GROUP_DESCRIPTION,
  }, function(loadResult)
    local moduleId = tonumber(trim(loadResult.stdout))
    if loadResult.exitCode ~= 0 or moduleId == nil then
      local message = trim(loadResult.stderr)
      finishAction(command, false, message ~= "" and message or (noctalia.tr and noctalia.tr("errors.group_create_failed") or "Group creation failed"))
      return
    end
    runPactl({ "set-default-sink", sinkName }, function(defaultResult)
      if defaultResult.exitCode ~= 0 then
        runPactl({ "unload-module", tostring(moduleId) }, function()
          local message = trim(defaultResult.stderr)
          finishAction(command, false, message ~= "" and message or (noctalia.tr and noctalia.tr("errors.group_switch_failed") or "Group switch failed"))
        end)
        return
      end
      moveStreams("output", sinkName, function()
        finishAction(command, true, noctalia.tr and noctalia.tr("notifications.group_created") or "Group created")
      end)
    end)
  end)
end

local function removeOutputGroup(command, id)
  local group = findOutputById(id)
  if group == nil or not group.group or group.groupModuleId == nil then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.group_not_found") or "Group not found")
    return
  end
  actionBusy = true
  publishSnapshot()
  runPactl({ "unload-module", tostring(group.groupModuleId) }, function(result)
    if result.exitCode ~= 0 then
      local message = trim(result.stderr)
      finishAction(command, false, message ~= "" and message or (noctalia.tr and noctalia.tr("errors.group_remove_failed") or "Disband failed"))
      return
    end
    if group.active then
      local fallback = nil
      for _, output in ipairs(snapshot.outputs) do
        if not output.group and output.available and trim(output.targetName) ~= "" and output.id ~= group.id then
          fallback = output
          break
        end
      end
      if fallback ~= nil then
        runPactl({ "set-default-sink", fallback.targetName }, function(_fRes)
          moveStreams("output", fallback.targetName, function()
            finishAction(command, true, noctalia.tr and noctalia.tr("notifications.group_removed") or "Group disbanded")
          end)
        end)
        return
      end
    end
    finishAction(command, true, noctalia.tr and noctalia.tr("notifications.group_removed") or "Group disbanded")
  end)
end

connectBluetooth = function(command, address)
  address = address:upper()
  if actionBusy then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.busy") or "Busy")
    return
  end
  actionBusy = true
  publishSnapshot()
  runBluetoothctl({ "connect", address }, function(result)
    if result.exitCode ~= 0 then
      local message = trim(result.stderr) ~= "" and trim(result.stderr) or trim(result.stdout)
      finishAction(command, false, message ~= "" and message or (noctalia.tr and noctalia.tr("errors.bluetooth_connect_failed") or "Connection failed"))
      return
    end
    local attempts = 0
    local function pollForSink()
      attempts = attempts + 1
      runPactl({ "-f", "json", "list", "sinks" }, function(sinkResult)
        if sinkResult.exitCode == 0 then
          local sinks = decodeJson(sinkResult.stdout)
          if type(sinks) == "table" then
            for _, sink in ipairs(sinks) do
              local props = propertiesOf(sink)
              if bluetoothAddress(props) == address and trim(sink.name) ~= "" then
                runPactl({ "set-default-sink", sink.name }, function(_defRes)
                  moveStreams("output", sink.name, function()
                    local matchedOutput = findOutputById(bluetoothOutputId(address))
                    local name = matchedOutput and matchedOutput.name or address
                    finishAction(command, true, noctalia.tr and noctalia.tr("notifications.output_selected", { device = name }) or "Output switched", noctalia.getConfig and noctalia.getConfig("show_notification_on_switch"))
                  end)
                end)
                return
              end
            end
          end
        end
        if attempts >= BLUETOOTH_CONNECT_RETRIES then
          finishAction(command, false, noctalia.tr and noctalia.tr("errors.bluetooth_audio_timeout") or "Bluetooth sink timeout")
        else
          runCommand({ "sleep", tostring(BLUETOOTH_CONNECT_RETRY_SECONDS) }, pollForSink)
        end
      end)
    end
    pollForSink()
  end)
end

local function disconnectBluetooth(command, address)
  address = address:upper()
  if actionBusy then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.busy") or "Busy")
    return
  end
  actionBusy = true
  publishSnapshot()
  runBluetoothctl({ "disconnect", address }, function(result)
    local ok = result.exitCode == 0
    local message = ok and (noctalia.tr and noctalia.tr("notifications.bluetooth_disconnected") or "Disconnected")
      or (trim(result.stderr) ~= "" and trim(result.stderr) or (noctalia.tr and noctalia.tr("errors.bluetooth_connect_failed") or "Failed"))
    finishAction(command, ok, message, ok)
  end)
end

local function scanBluetooth(command)
  if scanning then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.scan_in_progress") or "Scan in progress")
    return
  end
  scanning = true
  publishSnapshot()
  runBluetoothctl({ "--timeout", "8", "scan", "on" }, function()
    scanning = false
    publishSnapshot()
    refreshAll()
    resultMessage(command, true, noctalia.tr and noctalia.tr("notifications.scan_complete") or "Scan complete")
  end)
end

local function updateAlias(command)
  local id = tostring(command.id or "")
  local alias = trim(command.alias)
  if id == "" then return end
  if alias ~= "" then
    setPreference(preferences.aliases, id, alias)
  else
    if preferences.aliases[id] ~= nil then
      preferences.aliases[id] = nil
      preferencesDirty = true
    end
  end
  savePreferences()
  refreshAll()
  resultMessage(command, true, noctalia.tr and noctalia.tr("notifications.preferences_saved") or "Saved")
end

local function updateHidden(command)
  local id = tostring(command.id or "")
  local kind = command.kind == "input" and "input" or "output"
  local targetMap = kind == "output" and preferences.hiddenOutputs or preferences.hiddenInputs
  local hidden = command.hidden == true
  if id == "" then return end
  setPreference(targetMap, id, hidden)
  savePreferences()
  refreshAll()
  resultMessage(command, true, noctalia.tr and noctalia.tr("notifications.preferences_saved") or "Saved")
end

assignSlot = function(command, address, slot)
  address = address:upper()
  slot = tonumber(slot)
  if slot ~= nil and (slot < 1 or slot > 99 or slot ~= math.floor(slot)) then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.invalid_slot") or "Invalid slot")
    return
  end
  if slot ~= nil then
    local currentOwner = findAddressBySlot(slot)
    if currentOwner ~= nil and currentOwner ~= address then
      resultMessage(command, false, noctalia.tr and noctalia.tr("errors.slot_in_use", { slot = tostring(slot) }) or "Slot in use")
      return
    end
  end
  setPreference(preferences.slots, address, slot)
  savePreferences()
  refreshAll()
  local message = slot ~= nil and (noctalia.tr and noctalia.tr("notifications.slot_saved", { slot = tostring(slot) }) or "Slot saved")
    or (noctalia.tr and noctalia.tr("notifications.preferences_saved") or "Saved")
  resultMessage(command, true, message)
end

local function updateDevice(command)
  local id = tostring(command.id or "")
  if id == "" then return end
  local alias = trim(command.alias)
  if alias ~= "" then
    setPreference(preferences.aliases, id, alias)
  else
    if preferences.aliases[id] ~= nil then
      preferences.aliases[id] = nil
      preferencesDirty = true
    end
  end
  local iconStyle = validIconStyle(command.iconStyle)
  if iconStyle ~= "automatic" then
    setPreference(preferences.icons, id, iconStyle)
  else
    if preferences.icons[id] ~= nil then
      preferences.icons[id] = nil
      preferencesDirty = true
    end
  end
  local address = bluetoothAddressFromId(id)
  local slot = tonumber(command.slot)
  if address ~= nil and command.slot ~= nil then
    if slot ~= nil and (slot < 1 or slot > 99 or slot ~= math.floor(slot)) then
      resultMessage(command, false, noctalia.tr and noctalia.tr("errors.invalid_slot") or "Invalid slot")
      return
    end
    if slot ~= nil then
      local currentOwner = findAddressBySlot(slot)
      if currentOwner ~= nil and currentOwner ~= address then
        resultMessage(command, false, noctalia.tr and noctalia.tr("errors.slot_in_use", { slot = tostring(slot) }) or "Slot in use")
        return
      end
    end
    setPreference(preferences.slots, address, slot)
  end
  savePreferences()
  refreshAll()
  resultMessage(command, true, noctalia.tr and noctalia.tr("notifications.preferences_saved") or "Saved")
end

local function applyNextVolume(kind)
  local state = volumeOperations[kind]
  if state.running then return end
  local nextRequest = state.pending
  if nextRequest == nil then return end
  state.pending = nil
  state.running = true
  local pactlCommand = kind == "output" and "set-sink-volume" or "set-source-volume"
  local target = kind == "output" and "@DEFAULT_SINK@" or "@DEFAULT_SOURCE@"
  launchOrFail({ pactlCommand, target, tostring(nextRequest.value) .. "%" }, function(_result)
    state.running = false
    if state.pending ~= nil then
      applyNextVolume(kind)
    else
      state.desiredValue = nil
      refreshCurrentVolume(kind)
    end
  end)
end

local function setVolume(command, kind)
  local value = tonumber(command.value)
  if value == nil or value < 0 or value > 100 then
    resultMessage(command, false, noctalia.tr and noctalia.tr("errors.invalid_volume") or "Invalid volume")
    return
  end
  value = math.floor(value + 0.5)
  local state = volumeOperations[kind]
  state.pending = { value = value }
  state.desiredValue = value
  if kind == "output" then snapshot.outputVolume = value else snapshot.inputVolume = value end
  updateActiveDeviceVolume(kind, value, kind == "output" and snapshot.outputMuted or snapshot.inputMuted)
  publishSnapshot()
  applyNextVolume(kind)
end

local function toggleMute(command, kind)
  local pactlCommand = kind == "output" and "set-sink-mute" or "set-source-mute"
  local target = kind == "output" and "@DEFAULT_SINK@" or "@DEFAULT_SOURCE@"
  if kind == "output" then
    snapshot.outputMuted = not snapshot.outputMuted
  else
    snapshot.inputMuted = not snapshot.inputMuted
  end
  publishSnapshot()
  launchOrFail({ pactlCommand, target, "toggle" }, function(result)
    local ok = result.exitCode == 0
    if not ok then
      if kind == "output" then
        snapshot.outputMuted = not snapshot.outputMuted
      else
        snapshot.inputMuted = not snapshot.inputMuted
      end
      publishSnapshot()
    end
    refreshCurrentVolume(kind)
  end)
end

local function executeCommand(command)
  if type(command) ~= "table" then return end
  local action = tostring(command.action or command.type or "")
  if action == "refresh" then
    refreshAll()
  elseif action == "set_output" or action == "set-output" then
    setOutput(command, tostring(command.id or command.target or ""))
  elseif action == "set_input" or action == "set-input" then
    setInput(command, tostring(command.id or command.target or ""), command.port)
  elseif action == "cycle_output" or action == "cycle-output" then
    cycleDevices(command, "output")
  elseif action == "cycle_input" or action == "cycle-input" then
    cycleDevices(command, "input")
  elseif action == "create_group" then
    createOutputGroup(command)
  elseif action == "remove_group" then
    removeOutputGroup(command, tostring(command.id or ""))
  elseif action == "connect_bluetooth" then
    connectBluetooth(command, tostring(command.address or ""))
  elseif action == "disconnect_bluetooth" then
    disconnectBluetooth(command, tostring(command.address or ""))
  elseif action == "scan_bluetooth" then
    scanBluetooth(command)
  elseif action == "set_alias" or action == "set-alias" then
    updateAlias(command)
  elseif action == "set_hidden" or action == "toggle-hidden" then
    updateHidden(command)
  elseif action == "set_slot" then
    assignSlot(command, tostring(command.address or ""), command.slot)
  elseif action == "update_device" then
    updateDevice(command)
  elseif action == "set_output_volume" or action == "volume-set" then
    setVolume(command, "output")
  elseif action == "set_input_volume" then
    setVolume(command, "input")
  elseif action == "toggle_output_mute" or action == "mute-toggle" then
    toggleMute(command, "output")
  elseif action == "toggle_input_mute" then
    toggleMute(command, "input")
  elseif action == "volume-up" then
    local delta = tonumber(command.delta) or 5
    local current = snapshot.outputVolume or 50
    setVolume({ value = math.min(100, current + delta) }, "output")
  elseif action == "volume-down" then
    local delta = tonumber(command.delta) or 5
    local current = snapshot.outputVolume or 50
    setVolume({ value = math.max(0, current - delta) }, "output")
  end
end

local function ipcCommand(action, payload)
  return {
    requestId = "ipc-" .. tostring(os.time()),
    action = action,
    payload = payload,
  }
end

function onIpc(event, payload)
  if event == "cycle-output" then
    executeCommand(ipcCommand("cycle_output", payload))
  elseif event == "cycle-input" then
    executeCommand(ipcCommand("cycle_input", payload))
  elseif event == "connect" then
    local command = ipcCommand("connect_bluetooth", payload)
    command.address = findAddressBySlot(payload)
    if command.address == nil then
      local slotErr = noctalia.tr and noctalia.tr("errors.slot_not_found", { slot = tostring(payload or "") }) or "Slot not found"
      resultMessage(command, false, slotErr)
      notifyResult(false, slotErr)
      return
    end
    executeCommand(command)
  elseif event == "refresh" then
    refreshAll()
  elseif event == "volume-up" then
    executeCommand({ action = "volume-up" })
  elseif event == "volume-down" then
    executeCommand({ action = "volume-down" })
  elseif type(event) == "table" then
    executeCommand(event)
  end
end

loadPreferences()

if noctalia and noctalia.state and noctalia.state.watch then
  noctalia.state.watch(COMMAND_KEY, function(command)
    if command then
      if noctalia.state.set then noctalia.state.set(COMMAND_KEY, nil) end
      executeCommand(command)
    end
  end)
end

if noctalia and noctalia.commandExists and noctalia.commandExists("pactl") and noctalia.runStream then
  local streamStarted = noctalia.runStream("LC_ALL=C pactl subscribe", function(line)
    local isChange = tostring(line):find("Event 'change'", 1, true) ~= nil
    if tostring(line):find(" on sink #", 1, true) ~= nil then
      audioEventRevisions.output = audioEventRevisions.output + 1
      if isChange then refreshCurrentVolume("output") else refreshAll() end
    elseif tostring(line):find(" on source #", 1, true) ~= nil then
      audioEventRevisions.input = audioEventRevisions.input + 1
      if isChange then refreshCurrentVolume("input") else refreshAll() end
    elseif tostring(line):find(" on card #", 1, true) ~= nil or tostring(line):find(" on server", 1, true) ~= nil then
      refreshAll()
    end
  end)
  if not streamStarted and noctalia.log then
    noctalia.log("audio-outputs: could not subscribe to pactl events")
  end
end

if noctalia and noctalia.setUpdateInterval then
  noctalia.setUpdateInterval(REFRESH_INTERVAL_MS)
end

function update()
  refreshAll()
end

refreshAll()
