--!nonstrict
local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/ytm-helper.sh"
end

local function toggleWindow()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " toggle", function()
    panel.close()
  end)
end

local function controlPlayer(action, callback)
  local helper = getHelperPath()
  noctalia.runAsync(string.format("%s %s", helper, action), function()
    if callback then callback() end
  end)
end

local function fetchStatus(callback)
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " status", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("ytm_status", data)
        if callback then callback(data) end
      end
    end
  end)
end

function render(customData)
  local data = customData or noctalia.state.get("ytm_status") or {}
  local status = data.status or "Inactive"
  local title = (data.title and data.title ~= "") and data.title or noctalia.tr("panel.no_track")
  local artist = data.artist or ""
  local isPlaying = (status == "Playing")

  local statusText = noctalia.tr("panel.status_inactive")
  local statusColor = "on_surface_variant"
  if status == "Playing" then
    statusText = noctalia.tr("panel.status_playing")
    statusColor = "primary"
  elseif status == "Paused" then
    statusText = noctalia.tr("panel.status_paused")
    statusColor = "tertiary"
  elseif status == "Idle" then
    statusText = "Фоновый режим"
    statusColor = "on_surface"
  end

  panel.render(ui.column({ flexGrow = 1, padding = 14, gap = 12 }, {
    -- Header
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.row({ align = "center", gap = 8, flexGrow = 1 }, {
        ui.glyph({ name = "brand-youtube", size = 18, color = "primary" }),
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
        onClick = function() fetchStatus(render) end,
      }),
      ui.button({
        glyph = "close",
        variant = "ghost",
        onClick = function() panel.close() end,
      }),
    }),

    -- Track info card
    ui.column({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 12,
      gap = 4,
    }, {
      ui.row({ align = "center", justify = "space_between" }, {
        ui.label({
          text = statusText,
          fontSize = 11,
          fontWeight = "semibold",
          color = statusColor,
        }),
        ui.glyph({
          name = isPlaying and "music" or "player-pause",
          size = 14,
          color = statusColor,
        }),
      }),
      ui.label({
        text = title,
        fontSize = 14,
        fontWeight = "bold",
        color = "on_surface",
      }),
      ui.label({
        text = artist ~= "" and artist or "—",
        fontSize = 12,
        color = "on_surface_variant",
      }),
    }),

    -- Playback controls
    ui.row({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 10,
      align = "center",
      justify = "space_around",
    }, {
      ui.button({
        glyph = "player-skip-back",
        variant = "secondary",
        onClick = function()
          controlPlayer("prev", function() fetchStatus(render) end)
        end,
      }),
      ui.button({
        glyph = isPlaying and "player-pause" or "player-play",
        variant = "primary",
        onClick = function()
          controlPlayer("play-pause", function() fetchStatus(render) end)
        end,
      }),
      ui.button({
        glyph = "player-skip-forward",
        variant = "secondary",
        onClick = function()
          controlPlayer("next", function() fetchStatus(render) end)
        end,
      }),
    }),

    -- Scratchpad Window Toggle Action
    ui.column({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 12,
      gap = 8,
    }, {
      ui.label({
        text = noctalia.tr("panel.toggle_window_desc"),
        fontSize = 11,
        color = "on_surface_variant",
      }),
      ui.button({
        text = noctalia.tr("panel.toggle_window"),
        glyph = "app-window",
        variant = "primary",
        onClick = function()
          toggleWindow()
        end,
      }),
    }),
  }))
end

noctalia.state.watch("ytm_status", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function onOpen(_context)
  fetchStatus(render)
end

render()
