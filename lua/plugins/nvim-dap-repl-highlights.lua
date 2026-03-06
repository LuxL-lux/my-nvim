return {
  {
    "LiadOz/nvim-dap-repl-highlights",
    lazy = false,
    config = function()
      require("nvim-dap-repl-highlights").setup()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "dap_repl" },
    },
  },
}
