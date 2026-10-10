--!nonstrict
local pollInterval = noctalia.getConfig("poll_interval") or 5

local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/virt-helper.sh"
end

local function render(vms)
  local list = vms or {}
  local count = #list

  barWidget.setGlyph("server-2")
  if count > 0 then
    barWidget.setText(tostring(count))
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip(string.format("%d running VM(s)", count))
  else
    barWidget.setText("")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip("No running VMs")
  end
end

local function refresh()
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " list", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("vms_list", data)
        render(data)
      end
    end
  end)
end

noctalia.state.watch("vms_list", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function update()
  noctalia.setUpdateInterval(pollInterval * 1000)
  refresh()
end

function onClick()
  noctalia.togglePanel("gidragir/virt-manager:panel")
end

function onRightClick()
  refresh()
end

local initial = noctalia.state.get("vms_list")
render(initial)
refresh()
