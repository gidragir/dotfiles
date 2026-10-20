--!nonstrict
local pollInterval = noctalia.getConfig("poll_interval") or 4
local ideaCapturing = false

local function render(statusText)
  local text = statusText or "⚡ 0"
  -- Trim whitespace and newline
  text = string.gsub(text, "^%s*(.-)%s*$", "%1")

  barWidget.setGlyph("message-chatbot")

  if string.find(text, "⚙") then
    barWidget.setGlyphColor("secondary")
  elseif string.find(text, "📥") or string.find(text, "🔍") then
    barWidget.setGlyphColor("primary")
  else
    barWidget.setGlyphColor("on_surface")
  end

  barWidget.setText(text)
  barWidget.setTooltip("⚡ Hermes AI Hub\n• ЛКМ: Hermes Desktop (Toggle)\n• ПКМ: Kanban Board (:9119)\n• СКМ: Меню профилей (Refiner/Thinker/Gemini)\n• Скролл: Захват идеи в Triage")
end

local function refresh()
  noctalia.runAsync("hermes-bar-status.sh", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      render(res.stdout)
    else
      render("⚡ 0")
    end
  end)
end

function update()
  noctalia.setUpdateInterval(pollInterval * 1000)
  refresh()
end

function onClick()
  noctalia.runAsync("hermes-desktop-toggle.sh", function(_res)
    refresh()
  end)
end

function onRightClick()
  noctalia.runAsync("vivaldi-stable --new-window --app=http://127.0.0.1:9119/#/kanban")
end

function onMiddleClick()
  noctalia.runAsync("ai-launcher.sh", function(_res)
    refresh()
  end)
end

function onScroll(_axis, steps, _startsGesture)
  local amount = tonumber(steps) or 0
  if amount == 0 then return end
  if ideaCapturing then return end
  ideaCapturing = true
  noctalia.runAsync("hermes-capture-idea.sh", function(_res)
    ideaCapturing = false
    refresh()
  end)
end

function onIpc(event)
  if event == "refresh" then
    refresh()
  end
end

render("⚡ 0")
refresh()
