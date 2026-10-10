 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#303446',
    base01 = '#414559',
    base02 = '#4a4e65',
    base03 = '#767d98',
    base04 = '#a5adce',
    base05 = '#c6d0f5',
    base06 = '#c6d0f5',
    base07 = '#c6d0f5',
    base08 = '#e78284',
    base09 = '#ca9ee6',
    base0A = '#8caaee',
    base0B = '#babbf1',
    base0C = '#c896e9',
    base0D = '#9597e9',
    base0E = '#90adef',
    base0F = '#bccef5',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#c6d0f5',          bg = '#303446' })
  hi('TelescopeBorder',         { fg = '#767d98',             bg = '#303446' })
  hi('TelescopePromptNormal',   { fg = '#c6d0f5',          bg = '#303446' })
  hi('TelescopePromptBorder',   { fg = '#767d98',             bg = '#303446' })
  hi('TelescopePromptPrefix',   { fg = '#babbf1',             bg = '#303446' })
  hi('TelescopePromptCounter',  { fg = '#a5adce',  bg = '#303446' })
  hi('TelescopePromptTitle',    { fg = '#303446',             bg = '#babbf1' })
  hi('TelescopePreviewTitle',   { fg = '#303446',             bg = '#8caaee' })
  hi('TelescopeResultsTitle',   { fg = '#303446',             bg = '#ca9ee6' })
  hi('TelescopeSelection',      { fg = '#c6d0f5',          bg = '#4a4e65' })
  hi('TelescopeSelectionCaret', { fg = '#babbf1',             bg = '#4a4e65' })
  hi('TelescopeMatching',       { fg = '#babbf1',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#c6d0f5',          bg = '#303446' })
  hi('MiniPickBorder',         { fg = '#767d98',             bg = '#303446' })
  hi('MiniPickPrompt',   { fg = '#c6d0f5',          bg = '#303446' })
  hi('MiniPickPromptPrefix',   { fg = '#babbf1',             bg = '#303446' })
  hi('MiniPickBorderText',    { fg = '#303446',             bg = '#babbf1' })
  hi('MiniPickMatchCurrent',      { fg = '#c6d0f5',          bg = '#4a4e65' })
  hi('MiniPickPromptCaret', { fg = '#babbf1',             bg = '#4a4e65' })
  hi('MiniPickMatchRanges',       { fg = '#babbf1',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
