return {
  "folke/trouble.nvim",
  opts = {
    -- Add custom keymaps for navigation
    keys = {
      ["<Tab>"] = {
        action = function(view, ctx)
          if ctx.item then
            -- Jump to the item
            view:jump(ctx.item)
            -- Schedule code actions to run after jumping
            vim.schedule(function()
              vim.lsp.buf.code_action()
            end)
          end
        end,
        desc = "Jump and show code actions",
      },
      o = "jump",  -- Jump but keep Trouble open
      ["<CR>"] = "jump",
      j = "next",
      k = "prev",
      p = "preview",
      P = "toggle_preview",
      q = "close",
      r = "refresh",
      ["?"] = "help",
    },
  },
}