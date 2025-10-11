local explorer_restore = false
local explorer_prev_win = nil

local function get_explorer_pickers()
  local ok, picker = pcall(require, "snacks.picker")
  if not ok then
    return {}
  end
  return picker.get({ source = "explorer" })
end

local function hide_explorer()
  local hidden = false
  for _, picker in ipairs(get_explorer_pickers()) do
    if not picker.closed then
      picker:close()
      hidden = true
    end
  end
  if hidden then
    local ok = pcall(require, "edgy")
    if ok then
      local main = require("edgy.editor").list_wins().main
      local wins = vim.tbl_values(main)
      if #wins > 0 then
        table.sort(wins, function(a, b)
          return (vim.w[a].edgy_enter or 0) > (vim.w[b].edgy_enter or 0)
        end)
        explorer_prev_win = wins[1]
      else
        explorer_prev_win = vim.api.nvim_get_current_win()
      end
    else
      explorer_prev_win = vim.api.nvim_get_current_win()
    end
  end
  return hidden
end

local function maybe_restore_explorer()
  if not explorer_restore then
    return
  end
  local pickers = get_explorer_pickers()
  if #pickers > 0 then
    explorer_restore = false
    return
  end
  local ok, explorer = pcall(require, "snacks.explorer")
  explorer_restore = false
  if not ok then
    return
  end
  vim.schedule(function()
    explorer.open()
    if explorer_prev_win and vim.api.nvim_win_is_valid(explorer_prev_win) then
      local win = explorer_prev_win
      vim.defer_fn(function()
        explorer_prev_win = nil
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_set_current_win, win)
        end
      end, 10)
    else
      explorer_prev_win = nil
    end
  end)
end

local function toggle_dapui_with_explorer()
  local ok_dapui, dapui = pcall(require, "dapui")
  if not ok_dapui then
    return
  end
  local sidebar_open = false
  local console_open = false
  local ok_windows, windows = pcall(require, "dapui.windows")
  if ok_windows then
    local sidebar = windows.layouts and windows.layouts[1]
    sidebar_open = sidebar and sidebar:is_open() or false
    local console = windows.layouts and windows.layouts[2]
    console_open = console and console:is_open() or false
  end

  if sidebar_open then
    dapui.close({})
    maybe_restore_explorer()
    return
  end

  local ok_dap, dap = pcall(require, "dap")
  local session_active = ok_dap and dap.session() ~= nil

  if console_open and not session_active then
    dapui.close({ layout = 2 })
    return
  end

  if hide_explorer() then
    explorer_restore = true
  end
  dapui.open({ layout = 1 })
  dapui.open({ layout = 2 })
end

return {
  "rcarriga/nvim-dap-ui",
  dependencies = { "nvim-neotest/nvim-nio" },
    -- stylua: ignore
    keys = {
      { "<leader>du", toggle_dapui_with_explorer, desc = "Dap UI" },
      { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "v"} },
    },
  opts = {
    layouts = {
      {
        elements = {
          { id = "scopes", size = 0.25 },
          { id = "breakpoints", size = 0.25 },
          { id = "stacks", size = 0.25 },
          { id = "watches", size = 0.25 },
        },
        size = 40,
        position = "right",
      },
      {
        elements = {
          { id = "console", size = 1 },
        },
        size = 12,
        position = "bottom",
      },
    },
  },
  config = function(_, opts)
    local dap = require("dap")
    local dapui = require("dapui")
    dapui.setup(opts)
    dap.listeners.after.event_initialized["dapui_config"] = function()
      explorer_restore = hide_explorer()
      dapui.open({})
    end
    local function close_handler()
      dapui.close({ layout = 1 })
      maybe_restore_explorer()
      vim.schedule(function()
        dapui.open({ layout = 2 })
      end)
    end
    dap.listeners.before.event_terminated["dapui_config"] = close_handler
    dap.listeners.before.event_exited["dapui_config"] = close_handler
  end,
}
