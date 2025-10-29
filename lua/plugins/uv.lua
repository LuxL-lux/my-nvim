return {
  "benomahony/uv.nvim",
  -- Optional filetype to lazy load when you open a python file
  ft = { "python" },
  dependencies = {
    "folke/snacks.nvim",
  },
  opts = {
    picker_integration = true,
  },
}
