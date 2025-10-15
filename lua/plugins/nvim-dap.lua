return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require("dap")

    dap.adapters.python = {
      type = "executable",
      command = vim.fn.expand("~/.local/share/nvim/mason/packages/debugpy/venv/bin/python"),
      args = { "-m", "debugpy.adapter" },
    }

    dap.configurations.python = {
      {
        justMyCode = true,
        type = "python",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        console = "integratedTerminal",
      },
    }
  end,
}
