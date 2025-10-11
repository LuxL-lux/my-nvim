return {
  "mfussenegger/nvim-dap-python",
  lazy = true,
  config = function()
    local python = vim.fn.expand("~/.local/share/nvim/mason/packages/debugpy/venv/bin/python")
    require("dap-python").setup(python)
  end,
  -- Consider the mappings at
  -- https://github.com/mfussenegger/nvim-dap-python?tab=readme-ov-file#mappings
  dependencies = {
    "mfussenegger/nvim-dap",
  },
}
