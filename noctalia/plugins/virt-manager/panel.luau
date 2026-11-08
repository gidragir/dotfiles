--!nonstrict
local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/virt-helper.sh"
end

local function launchDomain(name)
  local helper = getHelperPath()
  noctalia.runAsync(string.format("%s launch '%s'", helper, name), function() end)
end

local function fetchVms(callback)
  local helper = getHelperPath()
  noctalia.runAsync(helper .. " list", function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("vms_list", data)
        if callback then callback(data) end
      end
    end
  end)
end

function render(vmList)
  local list = vmList or noctalia.state.get("vms_list") or {}

  local vmRows = {}
  if #list == 0 then
    table.insert(vmRows, ui.column({
      fill = "surface_variant/0.25",
      radius = 8,
      border = "outline",
      borderWidth = 1,
      padding = 16,
      align = "center",
      gap = 8,
    }, {
      ui.glyph({ name = "server", size = 22, color = "on_surface_variant" }),
      ui.label({
        text = noctalia.tr("panel.empty"),
        color = "on_surface_variant",
        fontSize = 13,
      }),
    }))
  else
    for _, vm in ipairs(list) do
      local domainName = vm.name or "VM"
      local isRunning = (vm.state == "running" or vm.status == "running" or true)
      table.insert(vmRows, ui.row({
        fill = "surface_variant/0.25",
        radius = 8,
        border = "outline",
        borderWidth = 1,
        padding = 10,
        gap = 12,
        align = "center",
        justify = "space_between",
      }, {
        ui.row({ align = "center", gap = 8, flexGrow = 1 }, {
          ui.glyph({
            name = "server",
            size = 16,
            color = isRunning and "primary" or "on_surface_variant",
          }),
          ui.label({
            text = domainName,
            fontSize = 13,
            fontWeight = "medium",
            color = "on_surface",
          }),
        }),
        ui.button({
          text = noctalia.tr("panel.connect"),
          variant = "primary",
          glyph = "screen-share",
          onClick = function()
            launchDomain(domainName)
          end,
        }),
      }))
    end
  end

  panel.render(ui.column({ flexGrow = 1, padding = 14, gap = 12 }, {
    -- Header
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.row({ align = "center", gap = 8, flexGrow = 1 }, {
        ui.glyph({ name = "server-2", size = 18, color = "primary" }),
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
        onClick = function() fetchVms(render) end,
      }),
      ui.button({
        glyph = "close",
        variant = "ghost",
        onClick = function() panel.close() end,
      }),
    }),

    -- VM List
    ui.scroll({ flexGrow = 1, gap = 8 }, vmRows),
  }))
end

noctalia.state.watch("vms_list", function(val)
  if type(val) == "table" then
    render(val)
  end
end)

function onOpen(_context)
  fetchVms(render)
end

render()
