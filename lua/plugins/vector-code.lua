return {
  "Davidyz/VectorCode",
  version = "*",
  build = "uv tool upgrade vectorcode", -- Auto-upgrade CLI when plugin updates
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = "VectorCode", -- if you're lazy-loading VectorCode
  config = function()
    require("vectorcode").setup({
      async_opts = {
        debounce = 10,
        events = { "BufWritePost", "InsertEnter", "BufReadPost" },
        exclude_this = true,
        n_query = 5, -- Increase for better context retrieval
        notify = false,
        run_on_register = false,
      },
      async_backend = "lsp", -- Use LSP backend for better performance
      timeout_ms = 10000, -- Increase timeout for large projects
      notify = true,
      on_setup = {
        update = false, -- Set to true if you want auto-updates
      },
    })
  end,
}
