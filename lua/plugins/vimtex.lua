return {
  "lervag/vimtex",
  lazy = false,
  config = function()
    vim.g.vimtex_compiler_latexmk_engines = {
      _ = "lualatex",
    }
    vim.g.vimtex_compiler_latexmk = {
      options = {
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
        "-shell-escape",
      },
    }
    vim.g.vimtex_view_method = "sioyek"
    vim.g.vimtex_format_enabled = 1
    vim.g.vimtex_fold_enabled = 1
  end,
}
