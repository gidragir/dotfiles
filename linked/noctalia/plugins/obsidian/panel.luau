--!nonstrict
local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/obsidian-helper.sh"
end

local function getCreateNotePath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/create-note.sh"
end

local function triggerSync()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " sync", function(_res)
    noctalia.runAsync("noctalia msg plugin gidragir/obsidian:service all refresh", function() end)
  end)
end

local function toggleTask(dailyFile, line)
  local helper = getHelperPath()
  local cmd = string.format("%s toggle-task '%s' %d", helper, dailyFile, line)
  noctalia.runAsync(cmd, function(_res)
    noctalia.runAsync("noctalia msg plugin gidragir/obsidian:service all refresh", function() end)
  end)
end

local function openNeovim(dailyFile)
  if dailyFile and dailyFile ~= "" then
    noctalia.runAsync(string.format("ghostty -e nvim '%s'", dailyFile), function() end)
  end
end

local function openObsidian()
  noctalia.runAsync("xdg-open obsidian://", function() end)
end

local function createNewNote()
  local script = getCreateNotePath()
  noctalia.runAsync(script, function() end)
end

function render(st)
  local status = st or noctalia.state.get("obsidian_status") or {
    vault = "/data/obsidian",
    dailyFile = "",
    exists = false,
    todayFormatted = "",
    totalTasks = 0,
    completedTasks = 0,
    pendingTasks = 0,
    tasks = {},
    syncStatus = "idle",
    syncMessage = "Idle"
  }

  local dailyFile = status.dailyFile or ""
  local tasks = status.tasks or {}
  local syncStatus = status.syncStatus or "idle"
  local dateStr = status.todayFormatted or "Today"
  local pendingCount = status.pendingTasks or 0
  local totalCount = status.totalTasks or 0

  -- Tasks UI rows
  local taskElements = {}
  if #tasks == 0 then
    table.insert(taskElements, ui.column({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 16,
      align = "center",
      gap = 6,
    }, {
      ui.glyph({ name = "notebook", size = 20, color = "on_surface_variant" }),
      ui.label({
        text = noctalia.tr("panel.noTasksFound"),
        color = "on_surface_variant",
        fontSize = 13,
      }),
    }))
  else
    for _, t in ipairs(tasks) do
      local lineNum = t.line
      local isDone = t.done
      local taskText = t.text or ""

      table.insert(taskElements, ui.row({
        fill = isDone and "surface_variant/0.10" or "surface_variant/0.25",
        radius = 8,
        border = "outline",
        borderWidth = 1,
        padding = 8,
        gap = 10,
        align = "center",
      }, {
        ui.button({
          glyph = isDone and "square-check" or "square",
          variant = isDone and "primary" or "ghost",
          onClick = function()
            toggleTask(dailyFile, lineNum)
          end,
        }),
        ui.label({
          text = taskText,
          color = isDone and "on_surface_variant" or "on_surface",
          fontSize = 13,
          flexGrow = 1,
        }),
      }))
    end
  end

  panel.render(ui.column({ flexGrow = 1, padding = 14, gap = 12 }, {
    -- Header
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.row({ align = "center", gap = 8, flexGrow = 1 }, {
        ui.glyph({ name = "notebook", size = 18, color = "primary" }),
        ui.label({
          text = noctalia.tr("panel.title") .. " · " .. dateStr,
          fontSize = 15,
          fontWeight = "bold",
          color = "on_surface",
        }),
      }),
      ui.button({
        glyph = "close",
        variant = "ghost",
        onClick = function() panel.close() end,
      }),
    }),

    -- Status & Sync Card
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
            name = syncStatus == "syncing" and "refresh" or (syncStatus == "error" and "alert-triangle" or "check"),
            size = 14,
            color = syncStatus == "error" and "destructive" or (syncStatus == "syncing" and "primary" or "on_surface_variant"),
          }),
          ui.label({
            text = "Sync: " .. syncStatus,
            fontSize = 12,
            color = "on_surface_variant",
          }),
        }),
        ui.label({
          text = string.format("Tasks: %d / %d pending", pendingCount, totalCount),
          fontSize = 12,
          fontWeight = "medium",
          color = pendingCount > 0 and "primary" or "on_surface_variant",
        }),
      }),
    }),

    -- Quick Action Buttons Card
    ui.column({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 8,
    }, {
      ui.row({ gap = 6, align = "center" }, {
        ui.button({
          text = noctalia.tr("panel.syncNow"),
          variant = syncStatus == "syncing" and "primary" or "outline",
          flexGrow = 1,
          onClick = triggerSync,
        }),
        ui.button({
          text = "Neovim",
          variant = "outline",
          flexGrow = 1,
          onClick = function() openNeovim(dailyFile) end,
        }),
        ui.button({
          text = "Obsidian",
          variant = "outline",
          flexGrow = 1,
          onClick = openObsidian,
        }),
        ui.button({
          glyph = "plus",
          variant = "primary",
          onClick = createNewNote,
        }),
      }),
    }),

    -- Tasks list in scrollable container
    ui.scroll({ flexGrow = 1, gap = 6 }, taskElements),
  }))
end

noctalia.state.watch("obsidian_status", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function onOpen(_context)
  noctalia.runAsync("noctalia msg plugin gidragir/obsidian:service all refresh", function() end)
  render()
end

render()
