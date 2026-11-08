--!nonstrict
local pollInterval = noctalia.getConfig("poll_interval") or 3

local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/ytm-helper.sh"
end

local function truncate(str, maxLen)
  if not str or str == "" then return "" end
  if #str <= maxLen then return str end
  return string.sub(str, 1, maxLen - 1) .. "…"
end

local function render(state)
  local data = state or {}
  local status = data.status or "Inactive"
  local title = data.title or ""
  local artist = data.artist or ""

  barWidget.setGlyph("brand-youtube")

  if status == "Playing" then
    barWidget.setGlyphColor("primary")
    if title ~= "" then
      local label = truncate(title, 20)
      barWidget.setText(label)
    else
      barWidget.setText("▶")
    end
    barWidget.setTooltip(string.format("▶ %s\n👤 %s\n\n• ЛКМ: Окно YouTube Music (Toggle)\n• ПКМ: Панель управления", title, artist))
  elseif status == "Paused" then
    barWidget.setGlyphColor("tertiary")
    if title ~= "" then
      local label = truncate(title, 18)
      barWidget.setText("⏸ " .. label)
    else
      barWidget.setText("⏸")
    end
    barWidget.setTooltip(string.format("⏸ %s\n👤 %s\n\n• ЛКМ: Окно YouTube Music (Toggle)\n• ПКМ: Панель управления", title, artist))
  elseif status == "Idle" then
    barWidget.setGlyphColor("on_surface")
    barWidget.setText("")
    barWidget.setTooltip("YouTube Music (Фоновый режим)\n\n• ЛКМ: Окно YouTube Music (Toggle)\n• ПКМ: Панель управления")
  else
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setText("")
    barWidget.setTooltip("YouTube Music (Не активен)\n\n• ЛКМ: Запустить и показать окно\n• ПКМ: Панель управления")
  end
end

local function refresh()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " status", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("ytm_status", data)
        render(data)
      end
    end
  end)
end

noctalia.state.watch("ytm_status", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function update()
  noctalia.setUpdateInterval(pollInterval * 1000)
  refresh()
end

function onClick()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " toggle", function(_res)
    refresh()
  end)
end

function onRightClick()
  noctalia.togglePanel("gidragir/ytm:panel")
end

local initial = noctalia.state.get("ytm_status")
render(initial)
refresh()
