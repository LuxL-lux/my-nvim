return {
  "kndndrj/nvim-dbee",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  cmd = {
    "Dbee",
    "DbeeToggle",
    "DbeeOpen",
    "DbeeClose",
    "DbeeSwitch",
  },
  keys = {
    { "<leader>D", "<cmd>DbeeToggle<cr>", desc = "Toggle Dbee" },
    { "<leader>dS", "<cmd>DbeeSwitch<cr>", desc = "Switch Azure SQL connection" },
  },
  build = function()
    require("dbee").install("go")
  end,
  config = function()
    local azure_source = require("dbee.sources.azure").new()

    vim.api.nvim_create_user_command("DbeeSwitch", function()
      azure_source:switch()
    end, { desc = "Switch Azure SQL connection" })

    require("dbee").setup({
      sources = {
        azure_source,
        require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
      },
      extra_helpers = {
        ["sqlserver"] = {
          ["List Tables"] = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' ORDER BY TABLE_NAME",
          ["Describe Table"] = "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '{{ .Table }}' ORDER BY ORDINAL_POSITION",
          ["Select Top 100"] = "SELECT TOP 100 * FROM dbo.[{{ .Table }}]",
        },
      },
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "DbeeOpen",
      callback = function()
        azure_source:auto_connect()
        require("utils.dbee_sql_notes").sync()
      end,
    })
  end,
}
