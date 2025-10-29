return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local diffview = require("diffview")

    diffview.setup({
      use_icons = true, -- disable if your terminal doesn't support icons
      enhanced_diff_hl = true,
      view = {
        merge_tool = {
          layout = "diff3_horizontal",
          disable_diagnostics = true, -- disable diagnostics while resolving conflicts
        },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { width = 35 },
      },
      hooks = {
        diff_buf_read = function(bufnr)
          vim.opt_local.wrap = false
          vim.opt_local.list = false
        end,
      },
    })
  end,
}
