return {
  "kdheepak/lazygit.nvim",
  lazy = true,
  cmd = {
    "LazyGit",
    "LazyGitConfig",
    "LazyGitCurrentFile",
    "LazyGitFilter",
    "LazyGitFilterCurrentFile",
  },
  -- optional for floating window border decoration
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("telescope").load_extension("lazygit")
    vim.g.lazygit_use_custom_config_file_path = 1 -- config file path is evaluated if this value is 1
    vim.g.lazygit_config_file_path = vim.fn.expand("$HOME/.config/lazygit/config.yml") -- custom config file path

    vim.g.lazygit_use_neovim_remote = 1
    local socket_path = vim.fn.stdpath("run") .. "/nvim.sock"
    vim.fn.serverstart(socket_path)
    vim.env.NVIM = socket_path
  end,
  -- setting the keybinding for LazyGit with 'keys' is recommended in
  -- order to load the plugin when the command is run for the first time
  keys = {
    { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
  },
}
