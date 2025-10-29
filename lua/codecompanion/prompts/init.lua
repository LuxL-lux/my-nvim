-- Prompts loader for CodeCompanion
local M = {}

-- Load individual prompt modules
local function load_prompt(name)
  local ok, prompt = pcall(require, "codecompanion.prompts." .. name)
  if not ok then
    vim.notify("Failed to load prompt: " .. name, vim.log.levels.ERROR)
    return nil
  end
  return prompt
end

-- Get all prompts for the prompt library
M.get_prompt_library = function()
  return {
    ["Environment Assistant"] = load_prompt("environment-assistant"),
    ["Code Reviewer"] = load_prompt("code-reviewer"),
    ["Documentation Writer"] = load_prompt("documentation-writer"),
  }
end

return M
