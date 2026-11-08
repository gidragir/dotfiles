-- tests/parser_test.lua
-- Unit tests for lib/parser.luau

package.path = package.path .. ";./?.luau;./lib/?.luau;./tests/?.lua"

local json = require("tests.json")
local parser = dofile("lib/parser.luau")

local function readFile(path)
  local f = assert(io.open(path, "rb"), "could not open " .. path)
  local content = f:read("*a")
  f:close()
  return content
end

-- ============================================================================
-- Test 1: parseEld
-- ============================================================================
do
  local eldValid = [[
monitor_present		1
eld_valid		1
monitor_name		Panasonic-TV
connection_type		HDMI
eld_version		[0x2] CEA-861D or below
edid_version		[0x3] CEA-861-B, C or D
]]
  local name = parser.parseEld(eldValid)
  assert(name == "Panasonic-TV", "parseEld should extract Panasonic-TV, got: " .. tostring(name))

  local eldAlt = "monitor_name   LG ULTRAWIDE\n"
  assert(parser.parseEld(eldAlt) == "LG ULTRAWIDE", "parseEld should handle varying whitespace")

  assert(parser.parseEld("") == nil, "parseEld should return nil for empty string")
  assert(parser.parseEld(nil) == nil, "parseEld should return nil for nil")
  assert(parser.parseEld("no monitor name here") == nil, "parseEld should return nil when key missing")
end

-- ============================================================================
-- Test 2: detectIcon
-- ============================================================================
do
  -- TV
  assert(parser.detectIcon({ displayName = "Panasonic-TV", portName = "hdmi-output-1" }) == "device-tv")
  assert(parser.detectIcon({ rawDescription = "Living Room Television", portName = "hdmi" }) == "device-tv")

  -- Monitor / Display
  assert(parser.detectIcon({ displayName = "LG ULTRAWIDE", portName = "hdmi-output-0" }) == "video-display")
  assert(parser.detectIcon({ rawDescription = "Digital Stereo (HDMI)", portName = "hdmi-output-2" }) == "video-display")

  -- Headphones
  assert(parser.detectIcon({ displayName = "Headphones", portName = "analog-output-headphones" }) == "audio-headphones")
  assert(parser.detectIcon({ rawDescription = "HyperX Cloud Headset", portName = "usb-output" }) == "audio-headphones")

  -- USB Audio
  assert(parser.detectIcon({ displayName = "USB Audio", sinkName = "alsa_output.usb-001" }) == "usb")
  assert(parser.detectIcon({ rawDescription = "ASUS USB DAC", portName = "analog-output" }) == "usb")

  -- Speakers / Line-out
  assert(parser.detectIcon({ displayName = "Built-in Audio", portName = "analog-output-lineout" }) == "audio-speakers")
  assert(parser.detectIcon({ displayName = "Desktop Speakers", rawDescription = "Stereo Speakers" }) == "audio-speakers")
end

-- ============================================================================
-- Test 3: findHdmiMonitorName
-- ============================================================================
do
  local card = {
    name = "alsa_card.pci-0000_01_00.1",
    ports = {
      ["hdmi-output-0"] = {
        name = "hdmi-output-0",
        properties = {
          ["device.product.name"] = "LG ULTRAWIDE",
        },
      },
      ["hdmi-output-1"] = {
        name = "hdmi-output-1",
        properties = {},
      },
    },
  }

  -- From port properties
  local name0 = parser.findHdmiMonitorName(card, "hdmi-output-0", nil)
  assert(name0 == "LG ULTRAWIDE", "should extract monitor name from port properties")

  -- Fallback to eldData
  local eldData = {
    ["hdmi-output-1"] = "monitor_present\t1\nmonitor_name\tPanasonic-TV\n",
  }
  local name1 = parser.findHdmiMonitorName(card, "hdmi-output-1", eldData)
  assert(name1 == "Panasonic-TV", "should extract monitor name from eldData")

  -- Missing
  local nameMissing = parser.findHdmiMonitorName(card, "hdmi-output-2", eldData)
  assert(nameMissing == nil, "should return nil if neither port property nor ELD has it")
end

-- ============================================================================
-- Test 4: matchSinkForProfile
-- ============================================================================
do
  local sinks = {
    {
      name = "alsa_output.pci-0000_01_00.1.hdmi-stereo",
      properties = {
        ["device.name"] = "alsa_card.pci-0000_01_00.1",
        ["device.profile.name"] = "hdmi-stereo",
      },
    },
    {
      name = "alsa_output.usb-01.analog-stereo",
      properties = {
        ["device.name"] = "alsa_card.usb-01",
        ["device.profile.name"] = "analog-stereo",
      },
    },
  }

  local matched = parser.matchSinkForProfile("alsa_card.pci-0000_01_00.1", "output:hdmi-stereo", sinks)
  assert(matched ~= nil, "should match active sink for output:hdmi-stereo")
  assert(matched.name == "alsa_output.pci-0000_01_00.1.hdmi-stereo")

  local inactive = parser.matchSinkForProfile("alsa_card.pci-0000_01_00.1", "output:hdmi-stereo-extra1", sinks)
  assert(inactive == nil, "inactive profile should not match any sink")

  -- Critical: verify hdmi-stereo does NOT match when only hdmi-stereo-extra1 is present in sinks
  local tvSinks = {
    {
      name = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1",
      properties = {
        ["device.name"] = "alsa_card.pci-0000_01_00.1",
        ["device.profile.name"] = "hdmi-stereo-extra1",
      },
    },
  }
  local noFalseMatch = parser.matchSinkForProfile("alsa_card.pci-0000_01_00.1", "output:hdmi-stereo", tvSinks)
  assert(noFalseMatch == nil, "hdmi-stereo must NOT match hdmi-stereo-extra1 sink")
  local tvMatch = parser.matchSinkForProfile("alsa_card.pci-0000_01_00.1", "output:hdmi-stereo-extra1", tvSinks)
  assert(tvMatch ~= nil, "hdmi-stereo-extra1 must match tvSink")
  assert(tvMatch.name == "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1")
end

-- ============================================================================
-- Test 5: Synthetic buildOutputs (surround filter, unused ports filter, sorting)
-- ============================================================================
do
  local synthSinks = {
    {
      name = "alsa_output.card0.hdmi-stereo",
      active_port = "hdmi-output-0",
      description = "AD103 HDMI [LG ULTRAWIDE]",
      mute = false,
      volume = { ["front-left"] = { value_percent = "80%" } },
      properties = {
        ["device.name"] = "alsa_card.card0",
        ["device.profile.name"] = "hdmi-stereo",
        ["alsa.name"] = "LG ULTRAWIDE",
      },
    },
    {
      name = "alsa_output.card1.analog-stereo",
      active_port = "analog-output-lineout",
      description = "Built-in Audio Analog Stereo",
      mute = false,
      volume = { ["front-left"] = { value_percent = "50%" } },
      properties = {
        ["device.name"] = "alsa_card.card1",
        ["device.profile.name"] = "analog-stereo",
      },
    },
  }

  local synthCards = {
    {
      name = "alsa_card.card0",
      active_profile = "output:hdmi-stereo",
      profiles = {
        ["output:hdmi-stereo"] = { description = "HDMI Stereo", sinks = 1, available = true },
        ["output:hdmi-stereo-extra1"] = { description = "HDMI 2 Stereo", sinks = 1, available = false },
        ["output:hdmi-surround-extra1"] = { description = "HDMI 2 Surround 5.1", sinks = 1, available = false },
        ["output:hdmi-surround71-extra1"] = { description = "HDMI 2 Surround 7.1", sinks = 1, available = false },
        ["output:hdmi-stereo-extra2"] = { description = "HDMI 3 Stereo", sinks = 1, available = false },
        ["output:hdmi-stereo-extra3"] = { description = "HDMI 4 Stereo", sinks = 1, available = false },
        ["off"] = { description = "Off", sinks = 0, available = true },
      },
      ports = {
        ["hdmi-output-0"] = {
          name = "hdmi-output-0",
          availability = "available",
          profiles = { "output:hdmi-stereo" },
          properties = { ["device.product.name"] = "LG ULTRAWIDE" },
        },
        ["hdmi-output-1"] = {
          name = "hdmi-output-1",
          availability = "not available",
          profiles = { "output:hdmi-stereo-extra1", "output:hdmi-surround-extra1", "output:hdmi-surround71-extra1" },
          properties = {},
        },
        ["hdmi-output-2"] = {
          name = "hdmi-output-2",
          availability = "not available",
          profiles = { "output:hdmi-stereo-extra2" },
          properties = {},
        },
        ["hdmi-output-3"] = {
          name = "hdmi-output-3",
          availability = "not available",
          profiles = { "output:hdmi-stereo-extra3" },
          properties = {},
        },
      },
    },
    {
      name = "alsa_card.card1",
      active_profile = "output:analog-stereo",
      profiles = {
        ["output:analog-stereo"] = { description = "Analog Stereo", sinks = 1, available = true },
      },
      ports = {
        ["analog-output-lineout"] = {
          name = "analog-output-lineout",
          availability = "available",
          profiles = { "output:analog-stereo" },
        },
      },
    },
  }

  local preferences = {
    knownDevices = {
      ["alsa_card.card0:hdmi-output-1"] = { name = "Panasonic-TV", lastSeen = 1719000000 },
    },
    aliases = {},
    icons = {},
    show_disconnected = true,
  }

  local defaultSink = "alsa_output.card0.hdmi-stereo"
  local outputs = parser.buildOutputs(synthSinks, synthCards, defaultSink, preferences, nil)

  -- Total count should be 3:
  -- 1. Active default sink (LG ULTRAWIDE)
  -- 2. Available sink (Built-in Audio)
  -- 3. Inactive known HDMI profile (Panasonic-TV)
  -- HDMI 3 and HDMI 4 must be filtered out!
  -- Surround profiles must be filtered out!
  assert(#outputs == 3, "expected exactly 3 outputs, got " .. #outputs)

  -- Check sorting:
  -- 1st: default sink (LG ULTRAWIDE)
  assert(outputs[1].kind == "sink")
  assert(outputs[1].isDefault == true)
  assert(outputs[1].displayName == "LG ULTRAWIDE")
  assert(outputs[1].volume == 80)
  assert(outputs[1].icon == "video-display")

  -- 2nd: available non-default sink (Built-in Audio)
  assert(outputs[2].kind == "sink")
  assert(outputs[2].isDefault == false)
  assert(outputs[2].available == true)
  assert(outputs[2].volume == 50)
  assert(outputs[2].icon == "audio-speakers")

  -- 3rd: disconnected known profile (Panasonic-TV)
  assert(outputs[3].kind == "profile")
  assert(outputs[3].isDefault == false)
  assert(outputs[3].available == false)
  assert(outputs[3].displayName == "Panasonic-TV")
  assert(outputs[3].profileName == "output:hdmi-stereo-extra1")
  assert(outputs[3].icon == "device-tv")

  -- Now test alias inclusion for an otherwise unused port (HDMI 3)
  preferences.aliases["profile:alsa_card.card0:output:hdmi-stereo-extra2"] = "Projector"
  local outputsWithAlias = parser.buildOutputs(synthSinks, synthCards, defaultSink, preferences, nil)
  assert(#outputsWithAlias == 4, "HDMI 3 should be included when user alias exists")
  local foundProjector = false
  for _, item in ipairs(outputsWithAlias) do
    if item.displayName == "Projector" then
      foundProjector = true
      assert(item.kind == "profile")
      assert(item.available == false)
    end
  end
  assert(foundProjector, "Projector item must be present")
end

-- ============================================================================
-- Test 6: Real fixtures buildOutputs (sinks.json and cards.json)
-- ============================================================================
do
  local sinksRaw = readFile("tests/fixtures/sinks.json")
  local cardsRaw = readFile("tests/fixtures/cards.json")
  local sinks = json.decode(sinksRaw)
  local cards = json.decode(cardsRaw)

  local defaultSinkName = "alsa_output.pci-0000_01_00.1.hdmi-stereo"
  local preferences = {
    knownDevices = {
      ["alsa_card.pci-0000_01_00.1:hdmi-output-1"] = {
        name = "Panasonic-TV",
        lastSeen = 1719000000,
      },
    },
    aliases = {},
    icons = {},
    show_disconnected = true,
  }

  local outputs = parser.buildOutputs(sinks, cards, defaultSinkName, preferences, nil)

  -- We expect:
  -- - LG ULTRAWIDE sink (default)
  -- - USB Audio sink (available)
  -- - Built-in Audio sink (available)
  -- - Panasonic-TV profile (inactive, disconnected)
  -- Total: 4 outputs
  assert(#outputs == 4, "expected 4 outputs from real fixtures, got: " .. #outputs)

  -- Output 1: Default sink (LG ULTRAWIDE)
  local o1 = outputs[1]
  assert(o1.kind == "sink", "first output must be sink")
  assert(o1.isDefault == true, "first output must be default")
  assert(o1.displayName == "LG ULTRAWIDE", "displayName should be LG ULTRAWIDE, got: " .. tostring(o1.displayName))
  assert(o1.icon == "video-display", "icon should be video-display, got: " .. tostring(o1.icon))
  assert(o1.volume == 100, "LG ULTRAWIDE volume should be 100")

  -- Inactive TV profile check
  local tvItem = nil
  for _, item in ipairs(outputs) do
    if item.profileName == "output:hdmi-stereo-extra1" then
      tvItem = item
      break
    end
  end
  assert(tvItem ~= nil, "Panasonic-TV profile must be present in outputs")
  assert(tvItem.kind == "profile", "tvItem must be kind profile")
  assert(tvItem.displayName == "Panasonic-TV", "tvItem displayName must be Panasonic-TV")
  assert(tvItem.available == false, "tvItem available should be false")
  assert(tvItem.icon == "device-tv", "tvItem icon should be device-tv")
  assert(tvItem.id == "profile:alsa_card.pci-0000_01_00.1:output:hdmi-stereo-extra1")

  -- Verify unused ports HDMI 3 and 4 are filtered out
  for _, item in ipairs(outputs) do
    assert(item.portName ~= "hdmi-output-2", "hdmi-output-2 must be filtered out")
    assert(item.portName ~= "hdmi-output-3", "hdmi-output-3 must be filtered out")
    assert(not (item.profileName or ""):find("surround"), "surround profiles must be filtered out")
  end
end

-- ============================================================================
-- Test 7: Mirrored scenario (TV sink active, Monitor profile inactive)
-- ============================================================================
do
  local synthSinks = {
    {
      name = "alsa_output.card0.hdmi-stereo-extra1",
      active_port = "hdmi-output-1",
      description = "AD103 HDMI [Panasonic-TV]",
      mute = false,
      volume = { ["front-left"] = { value_percent = "60%" } },
      properties = {
        ["device.name"] = "alsa_card.card0",
        ["device.profile.name"] = "hdmi-stereo-extra1",
        ["alsa.name"] = "Panasonic-TV",
      },
    },
    {
      name = "alsa_output.card1.analog-stereo",
      active_port = "analog-output-lineout",
      description = "Built-in Audio Analog Stereo",
      mute = false,
      volume = { ["front-left"] = { value_percent = "50%" } },
      properties = {
        ["device.name"] = "alsa_card.card1",
        ["device.profile.name"] = "analog-stereo",
      },
    },
  }

  local synthCards = {
    {
      name = "alsa_card.card0",
      active_profile = "output:hdmi-stereo-extra1",
      profiles = {
        ["output:hdmi-stereo"] = { description = "HDMI Stereo", sinks = 1, available = false },
        ["output:hdmi-stereo-extra1"] = { description = "HDMI 2 Stereo", sinks = 1, available = true },
        ["output:hdmi-surround-extra1"] = { description = "HDMI 2 Surround 5.1", sinks = 1, available = true },
        ["output:hdmi-stereo-extra2"] = { description = "HDMI 3 Stereo", sinks = 1, available = false },
        ["off"] = { description = "Off", sinks = 0, available = true },
      },
      ports = {
        ["hdmi-output-0"] = {
          name = "hdmi-output-0",
          availability = "available",
          profiles = { "output:hdmi-stereo" },
          properties = { ["device.product.name"] = "LG ULTRAWIDE" },
        },
        ["hdmi-output-1"] = {
          name = "hdmi-output-1",
          availability = "available",
          profiles = { "output:hdmi-stereo-extra1", "output:hdmi-surround-extra1" },
          properties = { ["device.product.name"] = "Panasonic-TV" },
        },
        ["hdmi-output-2"] = {
          name = "hdmi-output-2",
          availability = "not available",
          profiles = { "output:hdmi-stereo-extra2" },
          properties = {},
        },
      },
    },
    {
      name = "alsa_card.card1",
      active_profile = "output:analog-stereo",
      profiles = {
        ["output:analog-stereo"] = { description = "Analog Stereo", sinks = 1, available = true },
      },
      ports = {
        ["analog-output-lineout"] = {
          name = "analog-output-lineout",
          availability = "available",
          profiles = { "output:analog-stereo" },
        },
      },
    },
  }

  local preferences = {
    knownDevices = {},
    aliases = {},
    icons = {},
    show_disconnected = true,
  }

  local defaultSink = "alsa_output.card0.hdmi-stereo-extra1"
  local outputs = parser.buildOutputs(synthSinks, synthCards, defaultSink, preferences, nil)

  -- Check active TV default sink
  local tvSink = outputs[1]
  assert(tvSink.kind == "sink", "first output should be sink")
  assert(tvSink.isDefault == true, "first output should be default")
  assert(tvSink.profileName == "output:hdmi-stereo-extra1", "sink profileName should be normalized to output:hdmi-stereo-extra1")
  assert(tvSink.displayName == "Panasonic-TV", "sink displayName should be Panasonic-TV")
  assert(tvSink.icon == "device-tv", "sink icon should be device-tv")

  -- Check that monitor profile output:hdmi-stereo MUST be present as kind == 'profile'
  local monitorProfile = nil
  for _, item in ipairs(outputs) do
    if item.profileName == "output:hdmi-stereo" then
      monitorProfile = item
      break
    end
  end
  assert(monitorProfile ~= nil, "monitor profile output:hdmi-stereo MUST be present when TV is active sink")
  assert(monitorProfile.kind == "profile", "monitorProfile must have kind == 'profile'")
  assert(monitorProfile.displayName == "LG ULTRAWIDE", "monitorProfile displayName should be LG ULTRAWIDE")
  assert(monitorProfile.icon == "video-display", "monitorProfile icon should be video-display")

  -- Test knownDevices fallback for active sink
  local genericSink = {
    name = "alsa_output.card0.unknown-port",
    active_port = "hdmi-output-1",
    properties = {
      ["device.name"] = "alsa_card.card0",
      ["device.description"] = "Generic High Definition Audio",
    },
  }
  local testCard = { name = "alsa_card.card0", ports = {} }
  local testPrefs = {
    knownDevices = {
      ["alsa_card.card0:hdmi-output-1"] = { name = "Living Room TV" },
    },
  }
  local nameWithKnown = parser.buildOutputs({ genericSink }, { testCard }, "alsa_output.card0.unknown-port", testPrefs, nil)
  assert(nameWithKnown[1].displayName == "Living Room TV", "active sink should use knownDevices before falling back to device.description")
end

print("parser tests: ok")
