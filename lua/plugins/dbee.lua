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
    "DbeeView",
  },
  keys = {
    { "<leader>D", "<cmd>DbeeToggle<cr>", desc = "Toggle Dbee" },
    { "<leader>dS", "<cmd>DbeeSwitch<cr>", desc = "Switch Azure SQL connection" },
    { "<leader>dV", "<cmd>DbeeView<cr>", desc = "View results in tabiew" },
  },
  build = function()
    require("dbee").install("go")
  end,
  config = function()
    local azure_source = require("dbee.sources.azure").new()

    vim.api.nvim_create_user_command("DbeeSwitch", function()
      azure_source:switch()
    end, { desc = "Switch Azure SQL connection" })

    vim.api.nvim_create_user_command("DbeeView", function()
      local api = require("dbee").api
      local call = api.ui.result_get_call()
      if not call then
        vim.notify("No query results to view", vim.log.levels.WARN)
        return
      end

      local tmp = vim.fn.tempname() .. ".csv"
      api.core.call_store_result(call.id, "csv", "file", { extra_arg = tmp })

      local buf = vim.api.nvim_create_buf(false, true)
      local width = math.floor(vim.o.columns * 0.85)
      local height = math.floor(vim.o.lines * 0.8)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = "minimal",
        border = "rounded",
      })

      vim.fn.termopen("tw " .. vim.fn.shellescape(tmp), {
        on_exit = function()
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
            if vim.api.nvim_buf_is_valid(buf) then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
            vim.fn.delete(tmp)
          end)
        end,
      })
      vim.cmd("startinsert")
    end, { desc = "View query results in tabiew" })

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

    -- plugin is lazy-loaded, so config runs on first dbee command
    require("utils.dbee_sql_notes").sync()
    azure_source:auto_connect()
  end,
}
