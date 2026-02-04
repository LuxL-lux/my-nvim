local M = {}

local function get_root()
  local root = vim.fn.getcwd()
  if not root or root == "" then
    return nil
  end
  return root
end

local function clean_relative(rel)
  rel = rel:gsub("^[./]+", "")
  rel = rel:gsub("[\\/]+", "_")
  rel = rel:gsub("[^%w%._-]", "_")
  rel = rel:gsub("__+", "_")
  rel = rel:gsub("^_+", "")
  rel = rel:gsub("_+$", "")
  if rel == "" then
    rel = "script"
  end
  if not rel:match("%.sql$") then
    rel = rel .. ".sql"
  end
  return rel
end

local function remove_symlinks(dir)
  if vim.fn.isdirectory(dir) == 0 then
    return
  end
  for _, file in ipairs(vim.split(vim.fn.glob(dir .. "/*"), "\n")) do
    if file ~= "" then
      local stat = vim.loop.fs_lstat(file)
      if stat and stat.type == "link" then
        vim.fn.delete(file)
      end
    end
  end
end

local function enumerate_sql(root)
  local files = vim.fs.find(function(name)
    return name:match("%.sql$")
  end, { path = root, type = "file", limit = math.huge })
  local filtered = {}
  for _, path in ipairs(files) do
    if not path:find("/.git/") and not path:find("\\.git\\") then
      table.insert(filtered, path)
    end
  end
  return filtered
end

local function create_symlink(src, dst)
  local stat = vim.loop.fs_stat(dst)
  if stat then
    vim.fn.delete(dst)
  end
  local ok, err = pcall(vim.loop.fs_symlink, src, dst)
  if not ok then
    return false, err
  end
  return true
end

function M.sync()
  local root = get_root()
  if not root then
    return true
  end

  local notes_dir = vim.fn.stdpath("state") .. "/dbee/notes/global"
  vim.fn.mkdir(notes_dir, "p")
  remove_symlinks(notes_dir)

  local scripts = enumerate_sql(root)
  local seen = {}
  for _, path in ipairs(scripts) do
    local rel = vim.fn.fnamemodify(path, ":.")
    local name = clean_relative(rel)
    local candidate = notes_dir .. "/" .. name
    local suffix = 0
    while vim.fn.filereadable(candidate) == 1 or vim.fn.isdirectory(candidate) == 1 do
      suffix = suffix + 1
      candidate = notes_dir .. "/" .. name:gsub("%.sql$", "") .. "_" .. suffix .. ".sql"
    end
    local ok, err = create_symlink(path, candidate)
    if not ok then
      local contents = vim.fn.readfile(path)
      vim.fn.writefile(contents, candidate)
    end
    seen[candidate] = path
  end
  return true
end

return M
