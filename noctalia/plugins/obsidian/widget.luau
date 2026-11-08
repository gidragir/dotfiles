--!nonstrict
local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/obsidian-helper.sh"
end

local function render(status)
  local total = (status and status.totalTasks) or 0
  local completed = (status and status.completedTasks) or 0
  local pending = (status and status.pendingTasks) or 0
  local syncStatus = (status and status.syncStatus) or "idle"

  barWidget.setGlyph(total > 0 and "checklist" or "notebook")

  local text = ""
  if pending > 0 then
    text = tostring(pending)
  elseif total > 0 and pending == 0 then
    text = "✓"
  end
  barWidget.setText(text)

  local color = "on_surface"
  if syncStatus == "error" then
    color = "error"
  elseif pending > 0 then
    color = "primary"
  elseif total > 0 and pending == 0 then
    color = "tertiary"
  end
  barWidget.setGlyphColor(color)

  local tooltip = "Obsidian Companion"
  if status and status.todayFormatted and status.todayFormatted ~= "" then
    tooltip = tooltip .. " (" .. status.todayFormatted .. ")"
  end
  if total > 0 then
    tooltip = tooltip .. "\n" .. tostring(completed) .. "/" .. tostring(total) .. " tasks done"
  else
    tooltip = tooltip .. "\nNo tasks for today"
  end
  tooltip = tooltip .. "\nSync: " .. syncStatus
  barWidget.setTooltip(tooltip)
end

noctalia.state.watch("obsidian_status", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function update()
  local current = noctalia.state.get("obsidian_status")
  render(current)
end

function onClick()
  noctalia.togglePanel("gidragir/obsidian:panel")
end

function onRightClick()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " sync", function(_res)
    noctalia.runAsync("noctalia msg plugin gidragir/obsidian:service all refresh", function() end)
  end)
end

local initial = noctalia.state.get("obsidian_status")
render(initial)
