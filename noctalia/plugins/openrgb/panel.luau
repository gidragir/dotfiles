--!nonstrict
local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/openrgb-helper.sh"
end

local quickColors = {
  { name = "Red", hex = "FF0000" },
  { name = "Cyan", hex = "00FFFF" },
  { name = "Purple", hex = "B000FF" },
  { name = "Green", hex = "00FF00" },
  { name = "Orange", hex = "FF8800" },
  { name = "White", hex = "FFFFFF" },
}

local function fetchState(callback)
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " list", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("openrgb_state", data)
        if callback then callback(data) end
      end
    end
  end)
end

local function applyProfile(name)
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " apply '" .. name .. "'", function(_res)
    fetchState(render)
  end)
end

local function setBrightness(val)
  local helper = getHelperPath()
  local b = math.floor(tonumber(val) or 100)
  noctalia.runAsync(helper .. " set_brightness " .. tostring(b), function(_res)
    fetchState(render)
  end)
end

local function setColor(hex)
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " set_color " .. hex, function(_res)
    fetchState(render)
  end)
end

function render(st)
  local state = st or noctalia.state.get("openrgb_state") or {
    current = "off",
    brightness = 100,
    base_color = "000000",
    profiles = {}
  }

  local current = state.current or "off"
  local brightness = state.brightness or 100
  local profiles = state.profiles or {}
  local isOff = (current == "off" or current == "")

  local profileButtons = {}
  for _, prof in ipairs(profiles) do
    local isSelected = (prof == current)
    table.insert(profileButtons, ui.button({
      text = prof,
      variant = isSelected and "primary" or "outline",
      flexGrow = 1,
      onClick = function()
        applyProfile(prof)
      end,
    }))
  end

  local colorBoxes = {}
  for _, c in ipairs(quickColors) do
    table.insert(colorBoxes, ui.box({
      width = 36,
      height = 36,
      radius = 8,
      fill = "#" .. c.hex,
      border = "outline",
      borderWidth = 1,
      onClick = function()
        setColor(c.hex)
      end,
    }))
  end

  panel.render(ui.column({ flexGrow = 1, padding = 14, gap = 12 }, {
    -- Header
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.row({ align = "center", gap = 8, flexGrow = 1 }, {
        ui.glyph({ name = "palette", size = 18, color = "primary" }),
        ui.label({
          text = noctalia.tr("panel.title"),
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
      }),
      ui.button({
        glyph = "refresh",
        variant = "ghost",
        onClick = function() fetchState(render) end,
      }),
      ui.button({
        glyph = "close",
        variant = "ghost",
        onClick = function() panel.close() end,
      }),
    }),

    -- Status Card
    ui.column({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 10,
    }, {
      ui.row({ align = "center", justify = "space_between" }, {
        ui.row({ align = "center", gap = 6 }, {
          ui.glyph({
            name = isOff and "bulb-off" or "bulb",
            size = 14,
            color = isOff and "on_surface_variant" or "primary",
          }),
          ui.label({
            text = "Active: " .. (isOff and "Off" or current),
            fontSize = 13,
            fontWeight = "medium",
            color = isOff and "on_surface_variant" or "on_surface",
          }),
        }),
        ui.label({
          text = tostring(brightness) .. "%",
          fontSize = 12,
          color = "on_surface_variant",
        }),
      }),
    }),

    -- Scrollable body
    ui.scroll({ flexGrow = 1, gap = 12 }, {
      -- Profiles Section Card
      ui.column({
        fill = "surface_variant/0.25",
        radius = 8,
        border = "outline",
        borderWidth = 1,
        padding = 12,
        gap = 8,
      }, {
        ui.label({
          text = noctalia.tr("panel.profiles"),
          fontSize = 12,
          fontWeight = "medium",
          color = "on_surface_variant",
        }),
        ui.row({ gap = 6, align = "center" }, profileButtons),
      }),

      -- Brightness Section Card
      ui.column({
        fill = "surface_variant/0.25",
        radius = 8,
        border = "outline",
        borderWidth = 1,
        padding = 12,
        gap = 8,
      }, {
        ui.label({
          text = noctalia.tr("panel.brightness") .. " (" .. tostring(brightness) .. "%)",
          fontSize = 12,
          fontWeight = "medium",
          color = "on_surface_variant",
        }),
        ui.slider({
          min = 0,
          max = 100,
          step = 5,
          value = brightness,
          onChange = function(val)
            setBrightness(val)
          end,
        }),
      }),

      -- Quick Colors Section Card
      ui.column({
        fill = "surface_variant/0.25",
        radius = 8,
        border = "outline",
        borderWidth = 1,
        padding = 12,
        gap = 8,
      }, {
        ui.label({
          text = noctalia.tr("panel.quick_colors"),
          fontSize = 12,
          fontWeight = "medium",
          color = "on_surface_variant",
        }),
        ui.row({ gap = 6, align = "center", justify = "space_between" }, colorBoxes),
      }),

      -- Turn Off Action
      ui.button({
        text = noctalia.tr("panel.turn_off"),
        variant = "destructive",
        onClick = function()
          applyProfile("off")
        end,
      }),
      ui.box({ height = 6 }),
    }),
  }))
end

function onOpen(_context)
  fetchState(render)
end

render()
