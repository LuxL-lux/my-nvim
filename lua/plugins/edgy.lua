return {
  "folke/edgy.nvim",
  event = "VeryLazy",
  init = function()
    vim.opt.laststatus = 3
    vim.opt.splitkeep = "screen"
  end,
  opts = {
    left = {
      {
        ft = "snacks_explorer",
        title = "Explorer",
        size = { width = 0.25 },
      },
      {
        ft = { "dapui_scopes", "dapui_breakpoints", "dapui_stacks", "dapui_watches" },
        title = "DAP UI",
        size = { width = 0.25 },
      },
    },
    bottom = {
      {
        ft = "dapui_console",
        title = "DAP Console",
        size = { height = 0.25 },
      },
      {
        ft = "snacks_terminal",
        title = "%{b:snacks_terminal.id}: %{b:term_title}",
        size = { height = 0.3 },
        filter = function(_buf, win)
          return not vim.w[win].trouble_preview
        end,
      },
    },
  },
}
