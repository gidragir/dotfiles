--!nonstrict
local pollInterval = noctalia.getConfig("poll_interval") or 10

local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/openrgb-helper.sh"
end

local function render(state)
  local isOff = not state or state.current == "off" or state.current == ""
  local current = (state and state.current) or "off"
  local brightness = (state and state.brightness) or 100

  local children = {
    ui.glyph({
      name = "palette",
      size = 15,
      color = isOff and "on_surface_variant" or "primary",
    }),
  }

  if not isOff then
    table.insert(children, ui.label({
      text = current,
      fontSize = 12,
      fontWeight = "medium",
      color = "on_surface",
    }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 6, align = "center" }, children))

  if isOff then
    barWidget.setTooltip("RGB: Off")
  else
    barWidget.setTooltip("RGB: " .. current .. " (" .. tostring(brightness) .. "%)")
  end
end

local function refresh()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " list", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("openrgb_state", data)
        render(data)
      end
    end
  end)
end

noctalia.state.watch("openrgb_state", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function update()
  noctalia.setUpdateInterval(pollInterval * 1000)
  refresh()
end

function onClick()
  noctalia.togglePanel("gidragir/openrgb:panel")
end

function onRightClick()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " apply off", function(res)
    if res and res.exitCode == 0 then
      refresh()
    end
  end)
end

update()
