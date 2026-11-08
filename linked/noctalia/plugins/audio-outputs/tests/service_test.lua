-- tests/service_test.lua
-- Integration unit tests for backend service daemon (service.luau)

package.path = package.path .. ";./?.luau;./lib/?.luau;./tests/?.lua"

local json = require("tests.json")

-- Helper to read file
local function readFile(path)
  local f = assert(io.open(path, "rb"), "could not open " .. path)
  local content = f:read("*a")
  f:close()
  return content
end

-- ============================================================================
-- Mock Noctalia Runtime Factory
-- ============================================================================
local function createMockNoctalia(initialSinks, initialCards, defaultSinkName, initialSinkInputs)
  local stateStorage = {}
  local stateWatchers = {}
  local executedCommands = {}
  local pendingAsyncCalls = {}
  local pendingSleepCalls = {}
  local streamCallbacks = {}
  local notifications = {}
  local updateIntervalMs = 0
  local configStorage = {
    show_notification_on_switch = true,
    show_disconnected = true,
    show_percentage = true,
  }

  local currentSinks = json.decode(json.encode(initialSinks))
  local currentCards = json.decode(json.encode(initialCards))
  local currentDefaultSink = defaultSinkName
  local currentSinkInputs = json.decode(json.encode(initialSinkInputs or {}))

  local mock = {}

  mock.state = {
    get = function(key)
      return stateStorage[key]
    end,
    set = function(key, val)
      stateStorage[key] = val
      if stateWatchers[key] then
        for _, cb in ipairs(stateWatchers[key]) do
          cb(val)
        end
      end
    end,
    watch = function(key, cb)
      stateWatchers[key] = stateWatchers[key] or {}
      table.insert(stateWatchers[key], cb)
    end,
  }

  mock.pluginDataDir = function()
    return "/tmp/noctalia_test_audio_outputs"
  end

  mock.pluginDir = function()
    return "."
  end

  mock.setUpdateInterval = function(ms)
    updateIntervalMs = ms
  end

  mock.getUpdateInterval = function()
    return updateIntervalMs
  end

  mock.commandExists = function(cmd)
    return cmd == "pactl"
  end

  mock.getConfig = function(key)
    return configStorage[key]
  end

  mock.setConfig = function(key, val)
    configStorage[key] = val
  end

  mock.tr = function(key, params)
    if type(params) == "table" and params.output then
      return string.format("Switched to %s", params.output)
    end
    return key
  end

  mock.notify = function(titleOrOpts, message, icon)
    table.insert(notifications, {
      title = type(titleOrOpts) == "table" and titleOrOpts.title or titleOrOpts,
      message = type(titleOrOpts) == "table" and titleOrOpts.message or message,
      icon = type(titleOrOpts) == "table" and titleOrOpts.icon or icon,
    })
  end

  mock.string = {
    interpolate = function(str, tbl)
      return (str:gsub("{(%w+)}", tbl))
    end,
  }

  mock.json = json

  -- Command interceptor for pactl
  mock.runAsync = function(cmd, cb)
    table.insert(executedCommands, cmd)

    -- Return responses based on command pattern
    local function dispatchResult()
      if cmd:find("pactl %-f json list sinks") then
        cb({ exitCode = 0, stdout = json.encode(currentSinks), stderr = "" })
      elseif cmd:find("pactl %-f json list cards") then
        cb({ exitCode = 0, stdout = json.encode(currentCards), stderr = "" })
      elseif cmd:find("pactl %-f json list sink%-inputs") then
        cb({ exitCode = 0, stdout = json.encode(currentSinkInputs), stderr = "" })
      elseif cmd:find("pactl get%-default%-sink") then
        cb({ exitCode = 0, stdout = currentDefaultSink .. "\n", stderr = "" })
      elseif cmd:find("pactl set%-default%-sink") then
        local target = cmd:match("pactl set%-default%-sink%s+['\"]?([^'\"]+)")
        if target then currentDefaultSink = target end
        cb({ exitCode = 0, stdout = "", stderr = "" })
      elseif cmd:find("pactl set%-card%-profile") then
        local card, profile = cmd:match("pactl set%-card%-profile%s+['\"]?([^'%s]+)['\"]?%s+['\"]?([^'%s]+)")
        if card and profile then
          for _, c in ipairs(currentCards) do
            if c.name == card then
              c.active_profile = profile
            end
          end
        end
        cb({ exitCode = 0, stdout = "", stderr = "" })
      elseif cmd:find("pactl move%-sink%-input") then
        cb({ exitCode = 0, stdout = "", stderr = "" })
      elseif cmd:find("pactl set%-sink%-volume") then
        local target, vol = cmd:match("pactl set%-sink%-volume%s+['\"]?([^'%s]+)['\"]?%s+(%d+)%%")
        if target and vol then
          for _, s in ipairs(currentSinks) do
            if s.name == target then
              s.volume = s.volume or {}
              for _, ch in pairs(s.volume) do
                if type(ch) == "table" then
                  ch.value_percent = vol .. "%"
                end
              end
            end
          end
        end
        cb({ exitCode = 0, stdout = "", stderr = "" })
      elseif cmd:find("pactl set%-sink%-mute") then
        local target, mode = cmd:match("pactl set%-sink%-mute%s+['\"]?([^'%s]+)['\"]?%s+([%w]+)")
        if target then
          for _, s in ipairs(currentSinks) do
            if s.name == target then
              if mode == "toggle" then
                s.mute = not s.mute
              elseif mode == "1" or mode == "true" or mode == "yes" then
                s.mute = true
              elseif mode == "0" or mode == "false" or mode == "no" then
                s.mute = false
              end
            end
          end
        end
        cb({ exitCode = 0, stdout = "", stderr = "" })
      elseif cmd:find("^sleep") then
        table.insert(pendingSleepCalls, cb)
        return
      else
        cb({ exitCode = 0, stdout = "", stderr = "" })
      end
    end

    -- Queue or execute immediately
    if mock.manualAsync then
      table.insert(pendingAsyncCalls, { cmd = cmd, cb = cb, dispatch = dispatchResult })
    else
      dispatchResult()
    end
  end

  mock.runStream = function(cmd, onLine, onExit)
    table.insert(executedCommands, cmd)
    local stream = { onLine = onLine, onExit = onExit, closed = false }
    table.insert(streamCallbacks, stream)
    return {
      close = function()
        stream.closed = true
      end,
    }
  end

  -- Helpers for test harness
  mock.getExecutedCommands = function()
    return executedCommands
  end

  mock.clearCommands = function()
    executedCommands = {}
  end

  mock.getNotifications = function()
    return notifications
  end

  mock.simulateStreamLine = function(line)
    for _, s in ipairs(streamCallbacks) do
      if not s.closed and s.onLine then
        s.onLine(line)
      end
    end
  end

  mock.simulateStreamExit = function(exitCode)
    for _, s in ipairs(streamCallbacks) do
      if not s.closed and s.onExit then
        s.onExit(exitCode or 0)
      end
    end
  end

  mock.getStreams = function()
    return streamCallbacks
  end

  mock.setSinks = function(sinks)
    currentSinks = json.decode(json.encode(sinks))
  end

  mock.setCards = function(cards)
    currentCards = json.decode(json.encode(cards))
  end

  mock.setDefaultSink = function(sink)
    currentDefaultSink = sink
  end

  mock.flushPendingAsync = function(filterPattern)
    local toDispatch = {}
    local remaining = {}
    for _, item in ipairs(pendingAsyncCalls) do
      if not filterPattern or item.cmd:find(filterPattern) then
        table.insert(toDispatch, item)
      else
        table.insert(remaining, item)
      end
    end
    pendingAsyncCalls = remaining
    for _, item in ipairs(toDispatch) do
      item.dispatch()
    end
  end

  mock.pendingCount = function()
    return #pendingAsyncCalls
  end

  mock.triggerTimeout = function()
    local cbs = pendingSleepCalls
    pendingSleepCalls = {}
    for _, cb in ipairs(cbs) do
      cb({ exitCode = 0, stdout = "", stderr = "" })
    end
  end

  return mock
end

-- Load fixtures
local rawSinks = json.decode(readFile("tests/fixtures/sinks.json"))
local rawCards = json.decode(readFile("tests/fixtures/cards.json"))
local defaultSink = "alsa_output.pci-0000_01_00.1.hdmi-stereo"
local dummyInputs = {
  { index = 1, sink = 42, media = { name = "Firefox" } },
  { index = 2, sink = 42, media = { name = "Spotify" } },
}

print("Running service unit tests...")

-- ============================================================================
-- Scenario 1: Initial refresh publishes valid snapshot in audio_outputs_snapshot
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock

  -- Load service
  dofile("service.luau")

  local snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot ~= nil, "Scenario 1: snapshot must not be nil after service load")
  assert(snapshot.available == true, "Scenario 1: snapshot.available must be true")
  assert(type(snapshot.outputs) == "table", "Scenario 1: snapshot.outputs must be table")
  assert(#snapshot.outputs > 0, "Scenario 1: snapshot.outputs must contain outputs")
  assert(snapshot.defaultOutputId ~= nil, "Scenario 1: defaultOutputId must be set")
  assert(snapshot.defaultOutputId == "sink:" .. defaultSink, "Scenario 1: defaultOutputId must match default sink")
  assert(type(snapshot.outputVolume) == "number", "Scenario 1: outputVolume must be a number")
  assert(type(snapshot.outputMuted) == "boolean", "Scenario 1: outputMuted must be boolean")
  assert(snapshot.busy == false, "Scenario 1: initial busy state must be false")
  assert(mock.getUpdateInterval() == 3000, "Scenario 1: update interval must be 3000 ms")

  print("  ✓ Scenario 1: Initial refresh publishes valid snapshot")
end

-- ============================================================================
-- Scenario 2: Switching kind == 'sink' calls pactl set-default-sink & move-sink-input
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  mock.clearCommands()

  local targetSinkId = "sink:alsa_output.usb-ASUSTekcomputer.Inc_USB_Audio_201701110001-00.analog-stereo"
  _G.onIpc("service", "set-output " .. targetSinkId)

  local cmds = mock.getExecutedCommands()
  local foundSetDefault = false
  local movedInputs = 0

  for _, cmd in ipairs(cmds) do
    if cmd:find("pactl set%-default%-sink 'alsa_output.usb%-ASUSTekcomputer.Inc_USB_Audio_201701110001%-00.analog%-stereo'") then
      foundSetDefault = true
    end
    if cmd:find("pactl move%-sink%-input %d+ 'alsa_output.usb%-ASUSTekcomputer.Inc_USB_Audio_201701110001%-00.analog%-stereo'") then
      movedInputs = movedInputs + 1
    end
  end

  assert(foundSetDefault, "Scenario 2: must execute pactl set-default-sink for target sink")
  assert(movedInputs == 2, "Scenario 2: must move all active sink-inputs (expected 2, got " .. movedInputs .. ")")

  local snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.defaultOutputId == targetSinkId, "Scenario 2: snapshot defaultOutputId should be updated")

  print("  ✓ Scenario 2: Switch to active sink moves inputs and updates default")
end

-- ============================================================================
-- Scenario 3: Switching kind == 'profile' triggers set-card-profile, detects sink, commits default
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  mock.clearCommands()

  local targetProfileId = "profile:alsa_card.pci-0000_01_00.1:output:hdmi-stereo-extra1"
  _G.onIpc("service", "set-output " .. targetProfileId)

  local cmds = mock.getExecutedCommands()
  local foundSetProfile = false
  for _, cmd in ipairs(cmds) do
    if cmd:find("pactl set%-card%-profile 'alsa_card.pci%-0000_01_00.1' 'output:hdmi%-stereo%-extra1'") then
      foundSetProfile = true
    end
  end
  assert(foundSetProfile, "Scenario 3: must trigger pactl set-card-profile")

  -- Now simulate that PipeWire spawned the new TV sink
  local tvSink = {
    name = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1",
    active_port = "hdmi-output-1",
    description = "Panasonic-TV",
    mute = false,
    volume = { ["front-left"] = { value_percent = "100%" } },
    properties = {
      ["device.name"] = "alsa_card.pci-0000_01_00.1",
      ["device.profile.name"] = "hdmi-stereo-extra1",
      ["alsa.name"] = "Panasonic-TV",
    },
  }
  local newSinksList = { tvSink, rawSinks[2], rawSinks[3] }
  mock.setSinks(newSinksList)

  -- Send subscribe event to trigger sink detection
  mock.simulateStreamLine("Event 'new' on sink #99")

  -- Verify pactl set-default-sink and move-sink-input were called for the new TV sink
  local afterCmds = mock.getExecutedCommands()
  local foundTvSetDefault = false
  local tvMovedInputs = 0
  for _, cmd in ipairs(afterCmds) do
    if cmd:find("pactl set%-default%-sink 'alsa_output.pci%-0000_01_00.1.hdmi%-stereo%-extra1'") then
      foundTvSetDefault = true
    end
    if cmd:find("pactl move%-sink%-input %d+ 'alsa_output.pci%-0000_01_00.1.hdmi%-stereo%-extra1'") then
      tvMovedInputs = tvMovedInputs + 1
    end
  end

  assert(foundTvSetDefault, "Scenario 3: must commit pactl set-default-sink for newly spawned TV sink")
  assert(tvMovedInputs == 2, "Scenario 3: must move sink inputs to newly spawned TV sink")

  print("  ✓ Scenario 3: Switch to profile awaits sink, commits default, moves streams")
end

-- ============================================================================
-- Scenario 4: Timeout 3.5s triggers FSM rollback to previous profile and sink
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  mock.clearCommands()

  local targetProfileId = "profile:alsa_card.pci-0000_01_00.1:output:hdmi-stereo-extra1"
  _G.onIpc("service", "set-output " .. targetProfileId)

  -- Simulate timeout by triggering internal timeout callback or sleep 3.5 finish
  -- Without new sink spawned, trigger the timeout event
  _G._triggerProfileTimeoutForTest()

  local cmds = mock.getExecutedCommands()
  local foundRollbackProfile = false
  local foundRestoreSink = false

  for _, cmd in ipairs(cmds) do
    if cmd:find("pactl set%-card%-profile 'alsa_card.pci%-0000_01_00.1' 'output:hdmi%-stereo'") then
      foundRollbackProfile = true
    end
    if cmd:find("pactl set%-default%-sink 'alsa_output.pci%-0000_01_00.1.hdmi%-stereo'") then
      foundRestoreSink = true
    end
  end

  assert(foundRollbackProfile, "Scenario 4: must rollback card profile to previous active profile")
  assert(foundRestoreSink, "Scenario 4: must restore previous default sink")

  local snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.busy == false, "Scenario 4: busy flag must be cleared after rollback")
  assert(snapshot.error and snapshot.error:find("timeout"), "Scenario 4: error must record timeout in snapshot")

  print("  ✓ Scenario 4: Timeout 3.5s triggers FSM rollback and error state")
end

-- ============================================================================
-- Scenario 5: Volume debounce batches rapid volume changes
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  mock.clearCommands()
  mock.manualAsync = true -- Enable manual resolution to test debounce under load

  -- Send 5 rapid volume change requests
  _G.onIpc("service", "volume-set 20")
  _G.onIpc("service", "volume-set 40")
  _G.onIpc("service", "volume-set 60")
  _G.onIpc("service", "volume-set 80")
  _G.onIpc("service", "volume-set 100")

  -- First command (20%) should have been dispatched to runAsync
  assert(mock.pendingCount() == 1, "Scenario 5: exactly 1 pactl process should be running while in-flight")
  local firstCmd = mock.getExecutedCommands()[1]
  assert(firstCmd:find("pactl set%-sink%-volume .* 20%%"), "Scenario 5: first command must be 20%")

  -- Complete the first in-flight command
  mock.flushPendingAsync("pactl set%-sink%-volume")

  -- Now debounce should have coalesced 40, 60, 80 and spawned only the final desired value (100%)
  assert(mock.pendingCount() == 1, "Scenario 5: debounced final command should now be in flight")
  local secondCmd = mock.getExecutedCommands()[2]
  assert(secondCmd:find("pactl set%-sink%-volume .* 100%%"), "Scenario 5: debounced second command must be 100%")

  mock.flushPendingAsync("pactl set%-sink%-volume")
  assert(mock.pendingCount() == 0, "Scenario 5: all pending volume commands finished")

  local totalVolumeCalls = 0
  for _, c in ipairs(mock.getExecutedCommands()) do
    if c:find("pactl set%-sink%-volume") then
      totalVolumeCalls = totalVolumeCalls + 1
    end
  end
  assert(totalVolumeCalls == 2, "Scenario 5: expected exactly 2 pactl volume executions, got " .. totalVolumeCalls)

  print("  ✓ Scenario 5: Volume debounce coalesced rapid requests (2 calls vs 5 requests)")
end

-- ============================================================================
-- Scenario 6: cycle-output stably rotates through 3 devices: A -> B -> C -> A
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  local snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot ~= nil, "Scenario 6: snapshot must exist")

  -- Collect the 3 available outputs sorted by ID to know the expected stable order
  local sorted = {}
  for _, o in ipairs(snapshot.outputs) do
    if o.available then
      table.insert(sorted, o)
    end
  end
  table.sort(sorted, function(a, b) return tostring(a.id) < tostring(b.id) end)
  assert(#sorted == 3, "Scenario 6: exactly 3 available outputs expected, found " .. #sorted)

  local devA = sorted[1].id
  local devB = sorted[2].id
  local devC = sorted[3].id

  -- Start by explicitly setting default to devA
  _G.onIpc("service", "set-output " .. devA)
  snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.defaultOutputId == devA, "Scenario 6: initial default must be devA")

  -- 1st cycle: A -> B
  _G.onIpc("service", "cycle-output")
  snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.defaultOutputId == devB, "Scenario 6: cycle 1 must switch from A to B (got " .. tostring(snapshot.defaultOutputId) .. ")")

  -- 2nd cycle: B -> C (using table command format)
  _G.onIpc("service", { type = "cycle-output" })
  snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.defaultOutputId == devC, "Scenario 6: cycle 2 must switch from B to C (got " .. tostring(snapshot.defaultOutputId) .. ")")

  -- 3rd cycle: C -> A (wrap around)
  _G.onIpc("service", "cycle-output")
  snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.defaultOutputId == devA, "Scenario 6: cycle 3 must wrap from C back to A (got " .. tostring(snapshot.defaultOutputId) .. ")")

  -- 4th cycle: A -> B again to confirm no ping-pong
  _G.onIpc("service", "cycle-output")
  snapshot = mock.state.get("audio_outputs_snapshot")
  assert(snapshot.defaultOutputId == devB, "Scenario 6: cycle 4 must switch from A to B again without ping-pong")

  print("  ✓ Scenario 6: cycle-output stably rotates through 3 devices (A -> B -> C -> A)")
end

-- ============================================================================
-- Scenario 7: Unified dispatcher, mute-toggle, volume steps, set-alias & preferences persistence
-- ============================================================================
do
  -- Ensure test data directory exists
  os.execute("mkdir -p /tmp/noctalia_test_audio_outputs")
  local prefPath = "/tmp/noctalia_test_audio_outputs/preferences.json"
  os.remove(prefPath)

  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  mock.clearCommands()

  -- 1. mute-toggle via string and table
  local initialMuted = mock.state.get("audio_outputs_snapshot").outputMuted
  _G.onIpc("service", "mute-toggle")
  local snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputMuted == not initialMuted, "Scenario 7: mute-toggle string must invert mute state")

  _G.onIpc("service", { type = "mute-toggle" })
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputMuted == initialMuted, "Scenario 7: mute-toggle table must restore mute state")

  -- 2. volume-up and volume-down
  _G.onIpc("service", "volume-set 50")
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputVolume == 50, "Scenario 7: volume-set 50 must set volume to 50")

  _G.onIpc("service", "volume-up")
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputVolume == 55, "Scenario 7: volume-up must increase volume by 5 (got " .. snap.outputVolume .. ")")

  _G.onIpc("service", { type = "volume-up", delta = 10 })
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputVolume == 65, "Scenario 7: volume-up table with delta 10 must increase volume to 65")

  _G.onIpc("service", "volume-down")
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputVolume == 60, "Scenario 7: volume-down must decrease volume by 5")

  _G.onIpc("service", { type = "volume-down", delta = 20 })
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.outputVolume == 40, "Scenario 7: volume-down table with delta 20 must decrease volume to 40")

  -- Check optimistic update of out.volume for active sink in snapshot.outputs
  local foundActiveSinkVolume = false
  for _, o in ipairs(snap.outputs) do
    if o.isDefault then
      assert(o.volume == 40, "Scenario 7: active sink volume in outputs must optimistically match outputVolume")
      foundActiveSinkVolume = true
      break
    end
  end
  assert(foundActiveSinkVolume, "Scenario 7: active default sink must exist in snapshot.outputs")

  -- 3. set-alias, saving and loading preferences.json
  local targetOutId = "sink:" .. defaultSink

  -- 2.1 set-output with leading/trailing whitespace and token parsing
  _G.onIpc("service", "   set-output    " .. targetOutId .. "   ")
  snap = mock.state.get("audio_outputs_snapshot")
  assert(snap.defaultOutputId == targetOutId, "Scenario 7: set-output with leading/trailing whitespace must parse properly")

  _G.onIpc("service", "set-alias " .. targetOutId .. " Studio Monitors")
  snap = mock.state.get("audio_outputs_snapshot")

  local aliasApplied = false
  for _, o in ipairs(snap.outputs) do
    if o.id == targetOutId then
      assert(o.displayName == "Studio Monitors", "Scenario 7: set-alias must update displayName in snapshot")
      aliasApplied = true
      break
    end
  end
  assert(aliasApplied, "Scenario 7: alias must be reflected in snapshot output")

  -- Verify preferences.json was saved to disk
  local f = io.open(prefPath, "r")
  assert(f ~= nil, "Scenario 7: preferences.json must be written to disk")
  local content = f:read("*a")
  f:close()
  local decodedPrefs = json.decode(content)
  assert(decodedPrefs.aliases and decodedPrefs.aliases[targetOutId] == "Studio Monitors", "Scenario 7: preferences.json must contain saved alias")

  -- 4. Reset alias on empty string
  _G.onIpc("service", "set-alias " .. targetOutId .. " ")
  snap = mock.state.get("audio_outputs_snapshot")
  local fReset = io.open(prefPath, "r")
  local resetContent = fReset:read("*a")
  fReset:close()
  local resetPrefs = json.decode(resetContent)
  assert(resetPrefs.aliases[targetOutId] == nil, "Scenario 7: empty alias must remove alias key from preferences")

  -- 5. Test loading preferences on clean service startup
  local testPrefs = {
    version = 1,
    knownDevices = {},
    aliases = { [targetOutId] = "Loaded Studio" },
    hiddenOutputs = {},
    icons = {},
    show_disconnected = true,
  }
  local fWrite = io.open(prefPath, "w")
  fWrite:write(json.encode(testPrefs))
  fWrite:close()

  -- Re-load service and verify alias is loaded from preferences.json
  dofile("service.luau")
  local freshSnap = mock.state.get("audio_outputs_snapshot")
  local foundLoadedAlias = false
  for _, o in ipairs(freshSnap.outputs) do
    if o.id == targetOutId then
      assert(o.displayName == "Loaded Studio", "Scenario 7: newly loaded service must read alias from preferences.json")
      foundLoadedAlias = true
      break
    end
  end
  assert(foundLoadedAlias, "Scenario 7: target output must have loaded alias on startup")

  -- 6. Test state-based command invocation and reset to nil
  local mock2 = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock2
  dofile("service.luau")
  local preCmdMuted = mock2.state.get("audio_outputs_snapshot").outputMuted
  mock2.state.set("audio_outputs_command", { type = "mute-toggle" })
  local postCmdSnap = mock2.state.get("audio_outputs_snapshot")
  assert(postCmdSnap.outputMuted == not preCmdMuted, "Scenario 7: audio_outputs_command must toggle mute state")
  assert(mock2.state.get("audio_outputs_command") == nil, "Scenario 7: audio_outputs_command must be reset to nil after processing")

  print("  ✓ Scenario 7: Unified dispatcher, mute-toggle, volume steps, set-alias & preferences persistence")
end

-- ============================================================================
-- Scenario 8: Stampede Protection: concurrent refresh calls coalesced, pendingCallbacks deferred
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  mock.clearCommands()
  mock.manualAsync = true

  local cb1Called = false
  local cb2Called = false
  local cb3Called = false

  -- Trigger initial refresh with cb1
  _G.refresh(function()
    cb1Called = true
  end)

  -- While first refresh pipeline is in-flight, trigger multiple rapid refreshes
  _G.refresh(function()
    cb2Called = true
  end)
  _G.refresh(function()
    cb3Called = true
  end)

  -- Prior to completing the first refresh pipeline, no callbacks should have fired
  assert(not cb1Called, "Scenario 8: cb1 must not be called before run 1 completes")
  assert(not cb2Called, "Scenario 8: cb2 must not be called before run 2 completes")
  assert(not cb3Called, "Scenario 8: cb3 must not be called before run 2 completes")

  -- Flush first refresh pipeline (sinks -> cards -> get-default-sink)
  assert(mock.pendingCount() == 1, "Scenario 8: exactly 1 command (sinks) in flight for run 1")
  mock.flushPendingAsync("pactl %-f json list sinks")
  assert(mock.pendingCount() == 1, "Scenario 8: exactly 1 command (cards) in flight for run 1")
  mock.flushPendingAsync("pactl %-f json list cards")
  assert(mock.pendingCount() == 1, "Scenario 8: exactly 1 command (get-default-sink) in flight for run 1")
  mock.flushPendingAsync("pactl get%-default%-sink")

  -- Run 1 is finished!
  -- cb1 must have been called, but pendingCallbacks (cb2, cb3) must still be waiting for run 2
  assert(cb1Called == true, "Scenario 8: cb1 must be invoked immediately after run 1 completes")
  assert(cb2Called == false, "Scenario 8: cb2 must NOT be invoked until second run completes")
  assert(cb3Called == false, "Scenario 8: cb3 must NOT be invoked until second run completes")

  -- Flush run 2 (sinks -> cards -> get-default-sink)
  assert(mock.pendingCount() == 1, "Scenario 8: run 2 should have started with list sinks")
  mock.flushPendingAsync("pactl %-f json list sinks")
  mock.flushPendingAsync("pactl %-f json list cards")
  mock.flushPendingAsync("pactl get%-default%-sink")

  -- Run 2 finished: cb2 and cb3 must now be invoked
  assert(cb2Called == true, "Scenario 8: cb2 must be invoked after second run completes")
  assert(cb3Called == true, "Scenario 8: cb3 must be invoked after second run completes")
  assert(mock.pendingCount() == 0, "Scenario 8: all pending async commands should be resolved")

  print("  ✓ Scenario 8: Stampede Protection: coalesces concurrent calls, pendingCallbacks invoked in run 2")
end

-- ============================================================================
-- Scenario 9: Stream Recovery: stream.onExit() clears isStreamActive, update() restarts stream
-- ============================================================================
do
  local mock = createMockNoctalia(rawSinks, rawCards, defaultSink, dummyInputs)
  _G.noctalia = mock
  dofile("service.luau")

  assert(_G.isStreamActive == true, "Scenario 9: stream must be active after startup")
  local streams = mock.getStreams()
  assert(#streams >= 1, "Scenario 9: at least one stream must be registered")

  -- Emulate stream exit / termination
  local initialStream = streams[#streams]
  initialStream.onExit(1)

  assert(_G.isStreamActive == false, "Scenario 9: isStreamActive must be false after stream exit")

  -- Call update() to trigger stream recovery
  mock.clearCommands()
  _G.update()

  local foundRestart = false
  for _, cmd in ipairs(mock.getExecutedCommands()) do
    if cmd == "pactl subscribe" then
      foundRestart = true
      break
    end
  end
  assert(foundRestart, "Scenario 9: update() must restart pactl subscribe stream")
  assert(_G.isStreamActive == true, "Scenario 9: isStreamActive must be restored to true")

  print("  ✓ Scenario 9: Stream Recovery: onExit clears isStreamActive, update() restarts stream")
end

print("\nservice tests: ok")

