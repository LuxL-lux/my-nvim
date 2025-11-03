-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Enhanced gf to handle file paths with line and column numbers
-- e.g., src/app.py:28:5 -> opens file at line 28, column 5
vim.keymap.set("n", "gf", function()
  local cfile = vim.fn.expand("<cfile>")
  local line = vim.fn.line(".")
  local col = vim.fn.col(".")

  -- Get the full text under and around cursor
  local current_line = vim.fn.getline(line)

  -- Pattern to match file:line:col or file:line
  local pattern = "([^%s:]+):(%d+):?(%d*)"

  -- Try to find the pattern in the current line around the cursor
  local best_match = nil
  local best_distance = math.huge

  for filepath, line_num, col_num in current_line:gmatch(pattern) do
    -- Find position of this match in the line
    local start_pos = current_line:find(filepath, 1, true)
    if start_pos then
      local end_pos = start_pos + #filepath + #line_num + (col_num ~= "" and #col_num + 2 or 1)

      -- Check if cursor is within or near this match
      if col >= start_pos and col <= end_pos then
        local distance = math.abs(col - start_pos)
        if distance < best_distance then
          best_distance = distance
          best_match = {
            file = filepath,
            line = tonumber(line_num),
            col = col_num ~= "" and tonumber(col_num) or nil
          }
        end
      end
    end
  end

  if best_match then
    -- Check if file exists
    if vim.fn.filereadable(best_match.file) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(best_match.file))
      vim.fn.cursor(best_match.line, best_match.col or 1)
      vim.cmd("normal! zz") -- Center the screen
    else
      -- Fall back to default gf behavior
      vim.cmd("normal! gf")
    end
  else
    -- Fall back to default gf behavior
    vim.cmd("normal! gf")
  end
end, { desc = "Go to file with line and column support" })
