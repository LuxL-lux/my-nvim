return {
  "sudormrfbin/cheatsheet.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/popup.nvim",
    "nvim-lua/plenary.nvim",
  },
  cmd = { "Cheatsheet" }, -- Optional: lazy-load on :Cheatsheet command
  config = function()
    require("cheatsheet").setup({})
  end,
}
