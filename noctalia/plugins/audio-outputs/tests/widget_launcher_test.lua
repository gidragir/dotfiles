--!nonstrict
-- widget_launcher_test.lua
-- Unit tests for widget.luau and launcher.luau in gidragir/audio-outputs plugin.

local function assertEqual(actual, expected, msg)
  if actual ~= expected then
    error(string.format("Assertion failed: %s (expected %s, got %s)", msg or "", tostring(expected), tostring(actual)))
  end
end

local function assertTrue(cond, msg)
  if not cond then
    error("Assertion failed: " .. (msg or "condition was false"))
  end
end

print("Running widget and launcher unit tests...")

-- =========================================================================
-- Part 1: Widget Tests
-- =========================================================================

-- Mock environment for widget
local barWidgetMock
barWidgetMock = {
  glyph = "",
  glyphColor = "",
  text = "",
  tooltip = nil,
  vertical = false,
  setGlyph = function(g) barWidgetMock.glyph = g end,
  setGlyphColor = function(c) barWidgetMock.glyphColor = c end,
  setText = function(t) barWidgetMock.text = t end,
  setTooltip = function(tt) barWidgetMock.tooltip = tt end,
  isVertical = function() return barWidgetMock.vertical end,
}

local mockConfig = {
  show_percentage = true,
  show_disconnected = true,
}

local mockState = {}
local mockStateWatchers = {}

local noctaliaMock = {
  getConfig = function(k) return mockConfig[k] end,
  tr = function(k, params)
    local s = k
    if type(params) == "table" then
      for pk, pv in pairs(params) do
        s = s:gsub("{" .. tostring(pk) .. "}", tostring(pv))
      end
    end
    return s
  end,
  state = {
    get = function(k) return mockState[k] end,
    set = function(k, v)
      mockState[k] = v
      if mockStateWatchers[k] then
        for _, w in ipairs(mockStateWatchers[k]) do w(v) end
      end
    end,
    watch = function(k, cb)
      if not mockStateWatchers[k] then mockStateWatchers[k] = {} end
      table.insert(mockStateWatchers[k], cb)
    end,
  },
  fuzzyScore = function(pattern, text)
    if not pattern or pattern == "" or not text or text == "" then return nil end
    local p = pattern:lower()
    local t = text:lower()
    local idx = t:find(p, 1, true)
    if idx then
      return 100 - (idx - 1) * 2
    end
    return nil
  end,
  togglePanel = function(panelId)
    mockState._lastToggledPanel = panelId
  end,
  runAsync = function(cmd, cb)
    mockState._lastRunCmd = cmd
    if cb then cb(0, "", "") end
  end,
}

_G.barWidget = barWidgetMock
_G.noctalia = noctaliaMock

-- Load widget.luau
dofile("widget.luau")

-- Scenario 1.1: Default initial state (100% volume, not muted)
mockState["audio_outputs_snapshot"] = {
  available = true,
  busy = false,
  error = "",
  defaultOutputId = "sink:1",
  outputVolume = 85,
  outputMuted = false,
  outputs = {
    { id = "sink:1", displayName = "LG ULTRAWIDE", isDefault = true },
  },
}
update()

assertEqual(barWidgetMock.glyph, "volume-3", "85% volume should yield volume-3")
assertEqual(barWidgetMock.glyphColor, "on_surface", "Normal state should yield on_surface color")
assertEqual(barWidgetMock.text, "85%", "Text should be 85%")
assertTrue(type(barWidgetMock.tooltip) == "string", "Tooltip should be a formatted string")
assertTrue(barWidgetMock.tooltip:find("widget.output"), "Tooltip should include widget.output")
assertTrue(barWidgetMock.tooltip:find("LG ULTRAWIDE"), "Tooltip should include output name")
assertTrue(barWidgetMock.tooltip:find("85%%"), "Tooltip should include percentage")
assertTrue(barWidgetMock.tooltip:find("widget.tooltip_help"), "Tooltip should include help text")

-- Scenario 1.2: Muted state
mockState["audio_outputs_snapshot"].outputMuted = true
update()
assertEqual(barWidgetMock.glyph, "volume-off", "Muted output must yield volume-off glyph")
assertTrue(barWidgetMock.tooltip:find("panel.muted"), "Tooltip should reflect muted state")

-- Scenario 1.3: Volume level steps (0, 25, 55, 95)
mockState["audio_outputs_snapshot"].outputMuted = false

mockState["audio_outputs_snapshot"].outputVolume = 0
update()
assertEqual(barWidgetMock.glyph, "volume-off", "0% volume must yield volume-off")

mockState["audio_outputs_snapshot"].outputVolume = 25
update()
assertEqual(barWidgetMock.glyph, "volume", "25% volume must yield volume")

mockState["audio_outputs_snapshot"].outputVolume = 55
update()
assertEqual(barWidgetMock.glyph, "volume-2", "55% volume must yield volume-2")

mockState["audio_outputs_snapshot"].outputVolume = 95
update()
assertEqual(barWidgetMock.glyph, "volume-3", "95% volume must yield volume-3")

-- Scenario 1.4: Status colors (busy, error, pactl_missing)
mockState["audio_outputs_snapshot"].busy = true
update()
assertEqual(barWidgetMock.glyphColor, "secondary", "busy=true must yield secondary color")

mockState["audio_outputs_snapshot"].busy = false
mockState["audio_outputs_snapshot"].error = "errors.sink_spawn_timeout"
update()
assertEqual(barWidgetMock.glyphColor, "error", "error state must yield error color")

mockState["audio_outputs_snapshot"].error = ""
mockState["audio_outputs_snapshot"].available = false
update()
assertEqual(barWidgetMock.glyphColor, "error", "available=false must yield error color")

-- Scenario 1.5: Config show_percentage and vertical bar
mockState["audio_outputs_snapshot"].available = true
mockConfig.show_percentage = false
onConfigChanged()
assertEqual(barWidgetMock.text, "", "show_percentage=false must hide text")

mockConfig.show_percentage = true
barWidgetMock.vertical = true
onConfigChanged()
assertEqual(barWidgetMock.text, "", "vertical widget must hide text")

barWidgetMock.vertical = false
onConfigChanged()
assertEqual(barWidgetMock.text, "95%", "horizontal widget with show_percentage=true must show percentage")

-- Scenario 1.6: Fallback click callbacks (onClick and onRightClick)
mockState._lastToggledPanel = nil
onClick()
assertEqual(mockState._lastToggledPanel, "gidragir/audio-outputs:audio-outputs", "onClick must toggle plugin panel")

mockState["audio_outputs_command"] = nil
onRightClick()
assertTrue(type(mockState["audio_outputs_command"]) == "table", "onRightClick must post audio_outputs_command")
assertEqual(mockState["audio_outputs_command"].type, "cycle-output", "Command type must be cycle-output")

print("  ✓ Widget unit tests passed")

-- =========================================================================
-- Part 2: Launcher Tests
-- =========================================================================

-- Load launcher.luau
dofile("launcher.luau")

mockState["audio_outputs_snapshot"] = {
  available = true,
  busy = false,
  error = "",
  defaultOutputId = "sink:hdmi",
  outputVolume = 90,
  outputMuted = false,
  outputs = {
    {
      id = "sink:hdmi",
      displayName = "LG ULTRAWIDE",
      rawDescription = "HDMI Monitor Audio",
      available = true,
      isDefault = true,
      icon = "video-display",
    },
    {
      id = "profile:panasonic",
      displayName = "Panasonic-TV",
      rawDescription = "HDMI Television",
      available = false,
      isDefault = false,
      icon = "device-tv",
    },
    {
      id = "sink:usb",
      displayName = "USB Audio DAC",
      rawDescription = "External Headphone Amp",
      available = true,
      isDefault = false,
      icon = "headphones",
    },
  },
}

-- Scenario 2.1: Empty query returns all available actions sorted by score
local allResults = onQuery("")
assertTrue(#allResults >= 3, "Empty query must return panel and outputs")
assertEqual(allResults[1].id, "open-panel", "First item on empty query should be open-panel")
assertEqual(allResults[1].glyph, "volume-2", "Panel item should have volume-2 glyph")

-- Verify outputs are present
local foundUsb = false
local foundTv = false
for _, res in ipairs(allResults) do
  if res.id == "switch:sink:usb" then
    foundUsb = true
    assertEqual(res.title, "USB Audio DAC", "Title must match displayName")
    assertEqual(res.glyph, "headphones", "Glyph must match output icon")
  elseif res.id == "switch:profile:panasonic" then
    foundTv = true
    assertEqual(res.badge, "status.disconnected", "Standby device must have disconnected badge")
  end
end
assertTrue(foundUsb, "USB Audio output should be in launcher results")
assertTrue(foundTv, "TV output should be in launcher results when show_disconnected=true")

-- Verify launcher normalizes 'tv' icon to 'device-tv'
mockState["audio_outputs_snapshot"].outputs[2].icon = "tv"
local tvNormResults = onQuery("")
for _, res in ipairs(tvNormResults) do
  if res.id == "switch:profile:panasonic" then
    assertEqual(res.glyph, "device-tv", "Launcher must normalize 'tv' icon to 'device-tv'")
  end
end
mockState["audio_outputs_snapshot"].outputs[2].icon = "device-tv"

-- Scenario 2.2: Fuzzy query filtering
local usbResults = onQuery("USB")
assertTrue(#usbResults >= 1, "Query 'USB' must match USB Audio DAC")
assertEqual(usbResults[1].id, "switch:sink:usb", "Top result for 'USB' should be switch:sink:usb")

local tvResults = onQuery("Panasonic")
assertTrue(#tvResults >= 1, "Query 'Panasonic' must match Panasonic-TV")
assertEqual(tvResults[1].id, "switch:profile:panasonic", "Top result for 'Panasonic' should be Panasonic-TV")

local panelResults = onQuery("Outputs")
assertTrue(#panelResults >= 1, "Query 'Outputs' must match open-panel")

-- Scenario 2.3: Config show_disconnected = false excludes disconnected devices
mockConfig.show_disconnected = false
local filteredResults = onQuery("")
for _, res in ipairs(filteredResults) do
  if res.id == "switch:profile:panasonic" then
    error("Disconnected TV should not be included when show_disconnected=false")
  end
end
mockConfig.show_disconnected = true

-- Scenario 2.4: onActivate handling
mockState._lastToggledPanel = nil
onActivate("open-panel")
assertEqual(mockState._lastToggledPanel, "gidragir/audio-outputs:audio-outputs", "open-panel must toggle plugin panel")

mockState["audio_outputs_command"] = nil
onActivate("switch:sink:usb")
assertTrue(type(mockState["audio_outputs_command"]) == "table", "switch action must set audio_outputs_command")
assertEqual(mockState["audio_outputs_command"].type, "set-output", "Command type should be set-output")
assertEqual(mockState["audio_outputs_command"].id, "sink:usb", "Command target should be sink:usb")

print("  ✓ Launcher unit tests passed")
print("widget and launcher tests: ok")
