return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers = opts.servers or {}
    opts.servers.bacon_ls = { enabled = diagnostics == "bacon_ls" }
    opts.servers.rust_analyzer = { enabled = false }

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

    opts.servers.pyright = {}

    local home = vim.fn.expand("~")
    local schema_path = string.format("file://%s/Projects/Priv/lazygit/schema/config.json", home)
    local config_path = string.format("%s/.config/lazygit/config.yml", home)
    opts.servers.yamlls = vim.tbl_deep_extend("force", opts.servers.yamlls or {}, {
      settings = {
        yaml = {
          schemaStore = {
            enable = false,
            url = "",
          },
          schemas = {
            ["https://raw.githubusercontent.com/jesseduffield/lazygit/master/schema/config.json"] = false,
            [schema_path] = { config_path },
          },
        },
      },
    })
    local lspconfig = require("lspconfig")

    opts.servers.zls = {
      cmd = { "zls" },
      filetypes = { "zig", "zir" },
      root_dir = lspconfig.util.root_pattern("build.zig", ".git"),
      single_file_support = true,
    }
    return opts
  end,
}
