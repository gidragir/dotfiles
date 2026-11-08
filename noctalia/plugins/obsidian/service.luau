--!nonstrict
local vaultPath = noctalia.getConfig("vault_path") or "/data/obsidian"
local dailyFolder = noctalia.getConfig("daily_folder") or "DAILY"
local refreshInterval = noctalia.getConfig("refresh_interval") or 15

local function getHelperPath()
  local dir = noctalia.pluginDir() or ""
  return dir .. "/scripts/obsidian-helper.sh"
end

local function pollStatus()
  local helper = getHelperPath()
  local cmd = string.format("%s status '%s' '%s'", helper, vaultPath, dailyFolder)
  noctalia.runAsync(cmd, function(res)
    if res and res.exitCode == 0 and res.stdout ~= "" then
      local data, _ = noctalia.json.decode(res.stdout)
      if type(data) == "table" then
        noctalia.state.set("obsidian_status", data)
      end
    end
  end)
end

function update()
  noctalia.setUpdateInterval(refreshInterval * 1000)
  pollStatus()
end

function onIpc(event, _payload)
  if event == "refresh" then
    pollStatus()
  end
end

update()
