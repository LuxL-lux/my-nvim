return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      cs = { "csharpier" },
      tex = { "tex-fmt" },
      plaintex = { "tex-fmt" },
      latex = { "tex-fmt" },
      bib = { "bibtex-tidy" },
      json = { "jq"},
      xml = { "xmlformatter" },
      typescript = { "biome" },
      postgres = { "pg_format" },
      sql = { "sqlfluff" },
    },
    formatters = {
      csharpier = {
        command = "csharpier",
        args = { "format", "--write-stdout" },
        to_stdin = true,
      },
      ["tex-fmt"] = {
        command = "tex-fmt",
        args = { "--stdin" },
        stdin = true,
      },
      ["bibtex-tidy"] = {
        command = vim.fn.expand("~/.local/share/nvim/mason/packages/bibtex-tidy/node_modules/.bin/bibtex-tidy"),
        args = {
          "--curly", -- Use braces for all values
          "--align=14", -- Align values
          "--sort", -- Sort by citation key
          "--sort-fields", -- Sort fields within entries
          "--trailing-commas", -- Add trailing commas
          "--encode-urls", -- Encode URLs properly
          "--remove-empty-fields", -- Remove empty fields
          "--wrap=80", -- Wrap at 80 columns
        },
        stdin = true,
      },
    },
  },
}
