local M = {}

local function repo_root()
  local cwd = vim.fn.getcwd()
  if cwd == "" then
    return nil
  end
  local git_dir = vim.fn.finddir(".git", cwd .. ";")
  if git_dir == "" then
    return cwd
  end
  return vim.fn.fnamemodify(git_dir, ":h")
end

local function ensure_dir(path)
  if path == "" or vim.fn.isdirectory(path) == 1 then
    return true
  end
  vim.fn.mkdir(path, "p")
  return vim.fn.isdirectory(path) == 1
end

local function sanitize_name(rel)
  local cleaned = rel:gsub("[\\/]+", "_"):gsub("[^%w_%-]", "_")
  cleaned = cleaned:gsub("__+", "_")
  cleaned = cleaned:gsub("^_+", ""):gsub("_+$", "")
  return cleaned
end

local function list_sql_files(root)
  if not root or root == "" then
    return {}
  end
  return vim.fs.find(function(name)
    return name:match("%.sql$")
  end, { path = root, type = "file" })
end

local function note_name_for(path, root)
  local rel = vim.fn.fnamemodify(path, ":.")
  local prefix = vim.fn.fnamemodify(root, ":p")
  if rel:sub(1, #prefix) == prefix then
    rel = rel:sub(#prefix + 1)
  end
  rel = rel:gsub("^/", "")
  local clean = sanitize_name(rel)
  local short_hash = vim.fn.sha256(rel):sub(1, 8)
  local name = string.format("sql-%s-%s.sql", clean == "" and "root" or clean, short_hash)
  return name
end

local function remove_old_links(dir, wanted)
  local matches = vim.fn.globpath(dir, "sql-*.sql", true, true)
  for _, file in ipairs(matches) do
    local base = vim.fn.fnamemodify(file, ":t")
    if not wanted[base] then
      vim.fn.delete(file)
    end
  end
end

local function ensure_symlink(src, dst)
  local stat = vim.loop.fs_stat(dst)
  if stat then
    local ok, target = pcall(vim.loop.fs_readlink, dst)
    if ok and target == src then
      return true
    end
    vim.loop.fs_unlink(dst)
  end
  local success, err = pcall(vim.loop.fs_symlink, src, dst)
  if not success then
    vim.notify(string.format("Failed to link %s: %s", dst, err), vim.log.levels.WARN)
  end
end

function M.sync()
  local root = repo_root()
  if not root then
    return
  end
  local notes_dir = vim.fn.stdpath("state") .. "/dbee/notes/global"
  if not ensure_dir(notes_dir) then
    vim.notify("Unable to create dbee notes directory", vim.log.levels.ERROR)
    return
  end

  local scripts = list_sql_files(root)
  if #scripts == 0 then
    return
  end

  local wanted = {}
  for _, path in ipairs(scripts) do
    local name = note_name_for(path, root)
    wanted[name] = true
    local target = notes_dir .. "/" .. name
    ensure_symlink(path, target)
  end

  remove_old_links(notes_dir, wanted)
end

return M
