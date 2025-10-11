return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    local esp32 = require("esp32")
    opts.servers = opts.servers or {}
    opts.servers.clangd = esp32.lsp_config()

    local solarized_lib = vim.fn.stdpath("data") .. "/lazy/solarized.nvim/lua"
    opts.servers.lua_ls = vim.tbl_deep_extend("force", opts.servers.lua_ls or {}, {
      settings = {
        Lua = {
          hint = { enable = true },
          runtime = { version = "LuaJIT" },
          workspace = {
            checkThirdParty = true,
            library = {
              vim.env.VIMRUNTIME,
              solarized_lib,
            },
          },
        },
      },
    })
    return opts
  end,
}
