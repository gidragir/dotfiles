-- Modern test suite for gidragir/audio-outputs service and parser
local json = require("tests.json")

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local sinksJson = readFile("tests/fixtures/sinks.json")
local cardsJson = readFile("tests/fixtures/cards.json")
assert(sinksJson, "sinks.json must exist")
assert(cardsJson, "cards.json must exist")

-- Mock pactl responses
local infoResponse = {
  ServerName = "PulseAudio (on PipeWire 1.6.0)",
  DefaultSinkName = "alsa_output.pci-0000_00_1f.3.analog-stereo",
  DefaultSourceName = "alsa_input.pci-0000_00_1f.3.analog-stereo",
}

-- Mock noctalia environment
local stateStore = {}
local launchedCommands = {}
_G.noctalia = {
  state = {
    get = function(k) return stateStore[k] end,
    set = function(k, v) stateStore[k] = v end,
    watch = function(k, cb) end,
  },
  json = json,
  string = {
    trim = function(s) return tostring(s or ""):match("^%s*(.-)%s*$") end,
  },
  tr = function(k, params)
    local s = tostring(k)
    if type(params) == "table" then
      for pk, pv in pairs(params) do
        s = s .. " [" .. pk .. "=" .. tostring(pv) .. "]"
      end
    end
    return s
  end,
  commandExists = function(c) return true end,
  runAsync = function(cmd, cb)
    table.insert(launchedCommands, cmd)
    if type(cb) == "function" then
      if cmd:find("info") then
        cb({ exitCode = 0, stdout = json.encode(infoResponse), stderr = "" })
      elseif cmd:find("short") and cmd:find("modules") then
        cb({ exitCode = 0, stdout = "", stderr = "" })
      elseif cmd:find("sinks") then
        cb({ exitCode = 0, stdout = sinksJson, stderr = "" })
      elseif cmd:find("sources") then
        cb({ exitCode = 0, stdout = "[]", stderr = "" })
      elseif cmd:find("cards") then
        cb({ exitCode = 0, stdout = cardsJson, stderr = "" })
      elseif cmd:find("devices") then
        cb({ exitCode = 0, stdout = "Device 00:11:22:33:44:55 Redmi Buds 5\n", stderr = "" })
      elseif cmd:find("bluetoothctl") and cmd:find("info") then
        cb({ exitCode = 0, stdout = "Alias: Redmi Buds 5\nConnected: no\nPaired: yes\nUUID: 0000110b-0000-1000-8000-00805f9b34fb (Audio Sink)\n", stderr = "" })
      else
        cb({ exitCode = 0, stdout = "", stderr = "" })
      end
    end
    return true
  end,
  runStream = function(cmd, onLine) return true end,
  setUpdateInterval = function(ms) end,
  pluginDataDir = function() return "/tmp" end,
  readFile = function(p)
    return json.encode({
      version = 1,
      knownDevices = {
        ["alsa_card.pci-0000_01_00.1:hdmi-output-1"] = { name = "Panasonic-TV" }
      }
    })
  end,
  writeFile = function(p, c) return true end,
  getConfig = function(k) return true end,
}

print("Running modern audio-outputs tests...")

-- Test 1: Sinks and Cards fixtures decoding
local sinks = json.decode(sinksJson)
local cards = json.decode(cardsJson)
assert(type(sinks) == "table" and #sinks > 0, "sinks must be non-empty table")
assert(type(cards) == "table" and #cards > 0, "cards must be non-empty table")
print("  ✓ Decoded fixtures successfully (" .. #sinks .. " sinks, " .. #cards .. " cards)")

-- Test 2: Execute service script
dofile("service.luau")
assert(_G.onIpc ~= nil, "onIpc must be defined by service")
assert(_G.update ~= nil, "update must be defined by service")
print("  ✓ service.luau loaded without runtime errors")

-- Test 3: Snapshot published
local snap = _G.noctalia.state.get("audio_outputs_snapshot")
assert(type(snap) == "table", "snapshot must be a table")
assert(snap.available == true, "snapshot must be available")
assert(type(snap.outputs) == "table" and #snap.outputs > 0, "outputs must not be empty")
print("  ✓ Snapshot published to noctalia.state with " .. #snap.outputs .. " outputs (revision " .. tostring(snap.revision) .. ")")

-- Verify HDMI/TV profiles were synthesized
local foundProfile = false
for _, out in ipairs(snap.outputs) do
  if out.kind == "profile" then
    foundProfile = true
    break
  end
end
assert(foundProfile, "Snapshot outputs must contain synthesized ACP GPU card profiles")
print("  ✓ ACP GPU card profiles successfully synthesized into output list")

-- Test 4: IPC command dispatch
_G.onIpc("volume-up")
_G.onIpc("cycle-output")
_G.onIpc("cycle-input")
print("  ✓ IPC events handled without errors")

print("\nAll modern audio-outputs unit tests passed!")
