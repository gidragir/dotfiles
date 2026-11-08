--!nonstrict
-- Status bar widget for gidragir/audio-outputs plugin in Noctalia Shell.

local SNAPSHOT_KEY = "audio_outputs_snapshot"

local snapshot = (noctalia and noctalia.state and noctalia.state.get(SNAPSHOT_KEY)) or {
  available = false,
  loading = true,
  outputs = {},
  inputs = {},
  outputVolume = 0,
  inputVolume = 0,
  outputMuted = false,
  inputMuted = false,
}

local function activeDevice(devices)
  for _, device in ipairs(type(devices) == "table" and devices or {}) do
    if device.active == true then return device end
  end
  return nil
end

local function percent(value)
  return tostring(math.floor((tonumber(value) or 0) + 0.5)) .. "%"
end

local function render()
  if not barWidget then return end

  local outputDevice = activeDevice(snapshot.outputs)
  local inputDevice = activeDevice(snapshot.inputs)
  local outputName = outputDevice and tostring(outputDevice.name or "") or (noctalia.tr and noctalia.tr("panel.no_output") or "No output")
  local inputPortName = inputDevice and tostring(inputDevice.activePortDescription or "") or ""
  local inputName = inputDevice and (inputPortName ~= "" and inputPortName or tostring(inputDevice.name or ""))
    or (noctalia.tr and noctalia.tr("panel.no_input") or "No input")
  local outputVolume = percent(snapshot.outputVolume)
  local inputVolume = percent(snapshot.inputVolume)

  local glyph = snapshot.outputMuted == true and "volume-off" or "volume"
  if outputDevice ~= nil and snapshot.outputMuted ~= true then
    glyph = tostring(outputDevice.icon or "volume")
  end

  barWidget.setGlyph(glyph)
  if snapshot.busy == true then
    barWidget.setGlyphColor("secondary")
  elseif snapshot.available == true then
    barWidget.setGlyphColor("default")
  else
    barWidget.setGlyphColor("error")
  end

  local showPercentage = not noctalia or not noctalia.getConfig or noctalia.getConfig("show_percentage") ~= false
  local isVertical = barWidget.isVertical and barWidget.isVertical() or false
  barWidget.setText(showPercentage and not isVertical and outputVolume or "")

  local tooltipItems = {
    { key = noctalia.tr and noctalia.tr("widget.output") or "Output", value = `{outputName} ({outputVolume})` },
    { key = noctalia.tr and noctalia.tr("widget.input") or "Input", value = `{inputName} ({inputVolume})` },
  }
  if not noctalia or not noctalia.getConfig or noctalia.getConfig("show_actions_in_tooltip") ~= false then
    table.insert(tooltipItems, {
      key = noctalia.tr and noctalia.tr("widget.action.scroll.key") or "Scroll",
      value = noctalia.tr and noctalia.tr("widget.action.scroll.description") or "Adjust output volume",
    })
    table.insert(tooltipItems, {
      key = noctalia.tr and noctalia.tr("widget.action.left_click.key") or "Left click",
      value = noctalia.tr and noctalia.tr("widget.action.left_click.description") or "Open audio panel",
    })
    table.insert(tooltipItems, {
      key = noctalia.tr and noctalia.tr("widget.action.right_click.key") or "Right click",
      value = noctalia.tr and noctalia.tr("widget.action.right_click.description") or "Cycle output",
    })
    table.insert(tooltipItems, {
      key = noctalia.tr and noctalia.tr("widget.action.middle_click.key") or "Middle click",
      value = noctalia.tr and noctalia.tr("widget.action.middle_click.description") or "Cycle input",
    })
  end
  barWidget.setTooltip(tooltipItems)
end

if noctalia and noctalia.state and noctalia.state.watch then
  noctalia.state.watch(SNAPSHOT_KEY, function(value)
    if type(value) == "table" then
      snapshot = value
      render()
    end
  end)
end

function onConfigChanged()
  render()
end

render()
