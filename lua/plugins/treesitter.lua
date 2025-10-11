return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, _)
      vim.filetype.add({
        pattern = {
          ["*.json"] = "json",
        },
      })
    end,
  },
}
