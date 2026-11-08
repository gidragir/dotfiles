--!nonstrict
-- Launcher search provider for gidragir/audio-outputs in Noctalia Shell.

local PANEL_ID = "gidragir/audio-outputs:audio-outputs"
local RESULT_ID = "open-panel"

local function resultFor(query)
  local title = noctalia and noctalia.tr and noctalia.tr("launcher.open") or "Open Audio Outputs"
  local subtitle = noctalia and noctalia.tr and noctalia.tr("launcher.description") or "Switch the default audio input or output."
  local trimmed = noctalia and noctalia.string and noctalia.string.trim(tostring(query or "")) or tostring(query or ""):match("^%s*(.-)%s*$")
  local score = 0

  if trimmed ~= "" then
    if noctalia and noctalia.fuzzyScore then
      score = noctalia.fuzzyScore(trimmed, title .. " " .. subtitle) or 0
      if score <= 0 then return nil end
    end
  end

  return {
    id = RESULT_ID,
    title = title,
    subtitle = subtitle,
    glyph = "switch-horizontal",
    score = score,
  }
end

function onQuery(query)
  if not launcher or not launcher.setResults then return end
  local result = resultFor(query)
  launcher.setResults(query, result and { result } or {})
end

function onActivate(id)
  if id == RESULT_ID and noctalia and noctalia.togglePanel then
    noctalia.togglePanel(PANEL_ID)
  end
end
