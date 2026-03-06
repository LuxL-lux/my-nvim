local M = {}

local azure_tenant = vim.g.dbee_azure_tenant or vim.env.AZURE_TENANT_ID or "702ed1df-fbf3-42e7-a14d-db80a314e632"
local azure_scope = vim.g.dbee_azure_scope or "https://management.core.windows.net//.default"
local azure_login_method = (vim.g.dbee_azure_login_method or "interactive"):lower()

local cache_path = vim.fn.stdpath("data") .. "/dbee_azure_cache.json"
local keychain_service = "nvim-dbee-azure"

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

local notify
local function get_notify()
  if notify then
    return notify
  end
  local ok, util = pcall(require, "lazy.util")
  if ok and util.notify then
    notify = function(message, level)
      util.notify(message, { title = "Azure SQL", level = level or vim.log.levels.INFO })
    end
  else
    notify = function(message, level)
      vim.notify(message, level)
    end
  end
  return notify
end

-- ---------------------------------------------------------------------------
-- Async job helpers (kept from original)
-- ---------------------------------------------------------------------------

local function run_job(cmd, on_success, on_error)
  local stdout = {}
  local stderr = {}
  local function append(buffer, lines)
    if not lines then
      return
    end
    for _, line in ipairs(lines) do
      if line ~= vim.NIL then
        table.insert(buffer, line)
      end
    end
  end

  local cmd_args
  if type(cmd) == "string" then
    cmd_args = { "sh", "-c", cmd }
  else
    cmd_args = cmd
  end

  local job_id = vim.fn.jobstart(cmd_args, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      append(stdout, data)
    end,
    on_stderr = function(_, data)
      append(stderr, data)
    end,
    on_exit = function(_, code)
      local out = table.concat(stdout, "\n")
      local err = table.concat(stderr, "\n")
      vim.schedule(function()
        if code == 0 then
          if on_success then
            on_success(out)
          end
        else
          if on_error then
            on_error(err ~= "" and err or out)
          end
        end
      end)
    end,
  })

  if job_id <= 0 then
    local err_msg = string.format("failed to start job %s", vim.inspect(cmd_args))
    vim.schedule(function()
      if on_error then
        on_error(err_msg)
      end
    end)
  end
end

local function az_login(on_success, on_error)
  local login_cmd = { "az", "login" }
  if azure_tenant and azure_tenant ~= "" then
    table.insert(login_cmd, "--tenant")
    table.insert(login_cmd, azure_tenant)
  end
  if azure_login_method == "device-code" then
    table.insert(login_cmd, "--use-device-code")
  elseif azure_scope and azure_scope ~= "" then
    table.insert(login_cmd, "--scope")
    table.insert(login_cmd, azure_scope)
  end
  run_job(login_cmd, on_success, on_error)
end

local function run_az(cmd, on_success, on_error)
  local retried = false
  local function exec()
    run_job(cmd, function(out)
      if on_success then
        on_success(out)
      end
    end, function(err)
      local needs_login = err and (err:match("AADSTS70043") or err:match("Please run az login"))
      if needs_login and not retried then
        retried = true
        az_login(function()
          exec()
        end, function(login_err)
          if on_error then
            on_error(login_err)
          end
        end)
      else
        if on_error then
          on_error(err)
        end
      end
    end)
  end
  exec()
end

local function sanitize_rule_name(value)
  if not value or value == "" then
    return "user_access_metadb"
  end
  local sanitized = value:gsub("%s+", "-"):gsub("[^%w%-]", "")
  return sanitized
end

local function load_cache()
  local fd = io.open(cache_path, "r")
  if not fd then
    return {}
  end
  local raw = fd:read("*a")
  fd:close()
  if not raw or raw == "" then
    return {}
  end
  local ok, data = pcall(vim.fn.json_decode, raw)
  if not ok or type(data) ~= "table" then
    return {}
  end
  return data
end

local function save_cache(data)
  local raw = vim.fn.json_encode(data)
  local tmp = cache_path .. ".tmp"
  local fd = io.open(tmp, "w")
  if not fd then
    get_notify()("Failed to write cache file", vim.log.levels.WARN)
    return
  end
  fd:write(raw)
  fd:close()
  os.rename(tmp, cache_path)
end

-- ---------------------------------------------------------------------------
-- macOS Keychain helpers (credentials stored encrypted)
-- ---------------------------------------------------------------------------

local function save_keychain(account, value, callback)
  run_job({
    "security",
    "add-generic-password",
    "-s",
    keychain_service,
    "-a",
    account,
    "-w",
    value,
    "-U", -- update if exists
  }, function()
    if callback then
      callback(true)
    end
  end, function(err)
    get_notify()(string.format("Failed to save to Keychain (%s): %s", account, err), vim.log.levels.WARN)
    if callback then
      callback(false)
    end
  end)
end

local function load_keychain(account, callback)
  run_job({
    "security",
    "find-generic-password",
    "-s",
    keychain_service,
    "-a",
    account,
    "-w", -- print only the password value
  }, function(out)
    local value = vim.fn.trim(out)
    callback(value ~= "" and value or nil)
  end, function()
    callback(nil)
  end)
end

local function save_credentials(server_name, username, password, callback)
  save_keychain(server_name .. "/username", username, function(ok_user)
    if not ok_user then
      if callback then
        callback(false)
      end
      return
    end
    save_keychain(server_name .. "/password", password, function(ok_pass)
      if callback then
        callback(ok_pass)
      end
    end)
  end)
end

local function load_credentials(server_name, callback)
  load_keychain(server_name .. "/username", function(username)
    if not username then
      callback(nil, nil)
      return
    end
    load_keychain(server_name .. "/password", function(password)
      callback(username, password)
    end)
  end)
end

-- ---------------------------------------------------------------------------
-- AzureSqlSource
-- ---------------------------------------------------------------------------

local AzureSqlSource = {}
AzureSqlSource.__index = AzureSqlSource

function AzureSqlSource:new()
  return setmetatable({
    connections = {},
    connecting = false,
    current_selection = nil,
    rule_name = nil,
    cached_ip = nil,
  }, self)
end

function AzureSqlSource:name()
  return "azure-sql"
end

function AzureSqlSource:load()
  return self.connections
end

-- ---------------------------------------------------------------------------
-- Resolve helpers
-- ---------------------------------------------------------------------------

function AzureSqlSource:resolve_rule_name(callback)
  if self.rule_name then
    callback(self.rule_name)
    return
  end
  run_job({ "git", "config", "user.name" }, function(result)
    local name = vim.fn.trim(result)
    if name == "" then
      name = vim.env.USER or "nvim"
    end
    self.rule_name = sanitize_rule_name(name)
    callback(self.rule_name)
  end, function()
    local fallback = sanitize_rule_name(vim.env.USER or "nvim")
    self.rule_name = fallback
    callback(self.rule_name .. "-local")
  end)
end

function AzureSqlSource:resolve_public_ip(callback)
  if self.cached_ip then
    callback(self.cached_ip)
    return
  end
  run_job({ "curl", "-fsSL", "https://api.ipify.org" }, function(result)
    local ip = vim.fn.trim(result)
    if ip == "" then
      get_notify()("Public IP lookup returned empty value", vim.log.levels.WARN)
      callback(nil)
      return
    end
    self.cached_ip = ip
    callback(ip)
  end, function(err)
    get_notify()(string.format("Failed to determine public IP: %s", err), vim.log.levels.WARN)
    callback(nil)
  end)
end

-- ---------------------------------------------------------------------------
-- switch() — interactive picker flow
-- ---------------------------------------------------------------------------

function AzureSqlSource:switch()
  if self.connecting then
    get_notify()("Azure connection already in progress", vim.log.levels.DEBUG)
    return
  end
  self.connecting = true
  -- force IP re-resolution (may have changed)
  self.cached_ip = nil

  local function abort()
    self.connecting = false
  end

  -- step 1: ensure logged in
  local function step_check_login()
    run_az({ "az", "account", "show", "-o", "none" }, function()
      step_list_subscriptions()
    end, function()
      get_notify()("Not logged in, running az login…", vim.log.levels.INFO)
      az_login(function()
        step_list_subscriptions()
      end, function(err)
        get_notify()(string.format("az login failed: %s", err), vim.log.levels.ERROR)
        abort()
      end)
    end)
  end

  -- step 2: pick subscription
  function step_list_subscriptions()
    run_az({ "az", "account", "list", "--query", "[?state=='Enabled']", "-o", "json" }, function(out)
      local ok, subs = pcall(vim.fn.json_decode, out)
      if not ok or type(subs) ~= "table" or #subs == 0 then
        get_notify()("No enabled Azure subscriptions found", vim.log.levels.ERROR)
        abort()
        return
      end
      vim.ui.select(subs, {
        prompt = "Select Azure subscription:",
        format_item = function(item)
          return string.format("%s (%s)", item.name or "", item.id or "")
        end,
      }, function(selected)
        if not selected then
          abort()
          return
        end
        step_set_subscription(selected)
      end)
    end, function(err)
      get_notify()(string.format("Failed to list subscriptions: %s", err), vim.log.levels.ERROR)
      abort()
    end)
  end

  -- step 3: set subscription context
  local chosen_sub_id
  function step_set_subscription(sub)
    chosen_sub_id = sub.id
    run_az({ "az", "account", "set", "--subscription", sub.id }, function()
      step_list_resource_groups()
    end, function(err)
      get_notify()(string.format("Failed to set subscription: %s", err), vim.log.levels.ERROR)
      abort()
    end)
  end

  -- step 4: pick resource group
  function step_list_resource_groups()
    run_az({ "az", "group", "list", "-o", "json" }, function(out)
      local ok, groups = pcall(vim.fn.json_decode, out)
      if not ok or type(groups) ~= "table" or #groups == 0 then
        get_notify()("No resource groups found", vim.log.levels.ERROR)
        abort()
        return
      end
      vim.ui.select(groups, {
        prompt = "Select resource group:",
        format_item = function(item)
          return item.name or ""
        end,
      }, function(selected)
        if not selected then
          abort()
          return
        end
        step_list_servers(selected.name)
      end)
    end, function(err)
      get_notify()(string.format("Failed to list resource groups: %s", err), vim.log.levels.ERROR)
      abort()
    end)
  end

  -- step 5: discover SQL servers
  local chosen_rg
  function step_list_servers(rg_name)
    chosen_rg = rg_name
    run_az({ "az", "sql", "server", "list", "--resource-group", rg_name, "-o", "json" }, function(out)
      local ok, servers = pcall(vim.fn.json_decode, out)
      if not ok or type(servers) ~= "table" or #servers == 0 then
        get_notify()(string.format("No SQL servers found in %s", rg_name), vim.log.levels.WARN)
        abort()
        return
      end
      if #servers == 1 then
        step_list_databases(servers[1].name)
      else
        vim.ui.select(servers, {
          prompt = "Select SQL server:",
          format_item = function(item)
            return item.name or ""
          end,
        }, function(selected)
          if not selected then
            abort()
            return
          end
          step_list_databases(selected.name)
        end)
      end
    end, function(err)
      get_notify()(string.format("Failed to list SQL servers: %s", err), vim.log.levels.ERROR)
      abort()
    end)
  end

  -- step 6: discover databases
  local chosen_server
  function step_list_databases(server_name)
    chosen_server = server_name
    run_az({
      "az",
      "sql",
      "db",
      "list",
      "--server",
      server_name,
      "--resource-group",
      chosen_rg,
      "-o",
      "json",
    }, function(out)
      local ok, dbs = pcall(vim.fn.json_decode, out)
      if not ok or type(dbs) ~= "table" then
        get_notify()("Failed to parse database list", vim.log.levels.ERROR)
        abort()
        return
      end
      -- filter out system databases
      local filtered = {}
      for _, db in ipairs(dbs) do
        if db.name ~= "master" then
          table.insert(filtered, db)
        end
      end
      if #filtered == 0 then
        get_notify()(string.format("No user databases found on %s", server_name), vim.log.levels.WARN)
        abort()
        return
      end
      if #filtered == 1 then
        self:connect(chosen_sub_id, chosen_rg, server_name, filtered[1].name, true)
      else
        vim.ui.select(filtered, {
          prompt = "Select database:",
          format_item = function(item)
            return item.name or ""
          end,
        }, function(selected)
          if not selected then
            abort()
            return
          end
          self:connect(chosen_sub_id, chosen_rg, server_name, selected.name, true)
        end)
      end
    end, function(err)
      get_notify()(string.format("Failed to list databases: %s", err), vim.log.levels.ERROR)
      abort()
    end)
  end

  step_check_login()
end

-- ---------------------------------------------------------------------------
-- connect() — firewall + credentials + activate connection
-- ---------------------------------------------------------------------------

function AzureSqlSource:connect(subscription_id, resource_group, server_name, database_name, force_refresh)
  self.connecting = true

  local function done()
    self.connecting = false
  end

  -- derive key vault name from server name pattern: data-sqlsrv-meta-{short}-{env}
  local short, env = server_name:match("^data%-sqlsrv%-meta%-(.+)%-(%w+)$")
  if not short or not env then
    get_notify()(
      string.format(
        "Server name '%s' does not match pattern data-sqlsrv-meta-{short}-{env}. Cannot derive Key Vault name.",
        server_name
      ),
      vim.log.levels.ERROR
    )
    done()
    return
  end
  local vault = string.format("sec-keyvlt-%s-%s", short, env)

  -- ensure correct subscription context
  run_az({ "az", "account", "set", "--subscription", subscription_id }, function()
    -- resolve IP and rule name in parallel-ish (rule_name is cached after first call)
    self:resolve_public_ip(function(ip)
      if not ip then
        done()
        return
      end
      self:resolve_rule_name(function(rule_name)
        -- create/update firewall rule (always)
        run_az({
          "az",
          "sql",
          "server",
          "firewall-rule",
          "create",
          "--resource-group",
          resource_group,
          "--server",
          server_name,
          "--name",
          rule_name,
          "--start-ip-address",
          ip,
          "--end-ip-address",
          ip,
          "--output",
          "none",
        }, function()
          get_notify()(
            string.format("Firewall rule %s on %s allows %s", rule_name, server_name, ip),
            vim.log.levels.INFO
          )
          self:resolve_credentials(vault, server_name, force_refresh, function(username, password)
            if not username or not password then
              done()
              return
            end
            self:activate_connection(subscription_id, resource_group, server_name, database_name, username, password)
            done()
          end)
        end, function(err)
          get_notify()(
            string.format("Failed to update firewall rule on %s: %s", server_name, err),
            vim.log.levels.ERROR
          )
          done()
        end)
      end)
    end)
  end, function(err)
    get_notify()(string.format("Failed to set subscription: %s", err), vim.log.levels.ERROR)
    done()
  end)
end

-- ---------------------------------------------------------------------------
-- resolve_credentials — use cache or fetch from Key Vault
-- ---------------------------------------------------------------------------

function AzureSqlSource:resolve_credentials(vault, server_name, force_refresh, callback)
  -- try Keychain-cached credentials first
  if not force_refresh then
    load_credentials(server_name, function(username, password)
      if username and password then
        callback(username, password)
      else
        -- not in keychain, fall through to Key Vault
        self:fetch_credentials_from_vault(vault, server_name, callback)
      end
    end)
    return
  end

  self:fetch_credentials_from_vault(vault, server_name, callback)
end

function AzureSqlSource:fetch_credentials_from_vault(vault, server_name, callback)
  -- fetch from Key Vault
  local user_cmd = {
    "az",
    "keyvault",
    "secret",
    "show",
    "--vault-name",
    vault,
    "--name",
    server_name .. "-username",
    "--query",
    "value",
    "-o",
    "tsv",
  }
  local pass_cmd = {
    "az",
    "keyvault",
    "secret",
    "show",
    "--vault-name",
    vault,
    "--name",
    server_name .. "-password",
    "--query",
    "value",
    "-o",
    "tsv",
  }
  run_az(user_cmd, function(username_result)
    local username = vim.fn.trim(username_result)
    if username == "" then
      get_notify()(string.format("Key Vault username empty for %s", vault), vim.log.levels.ERROR)
      callback(nil, nil)
      return
    end
    run_az(pass_cmd, function(password_result)
      local password = vim.fn.trim(password_result)
      if password == "" then
        get_notify()(string.format("Key Vault password empty for %s", vault), vim.log.levels.ERROR)
        callback(nil, nil)
        return
      end
      callback(username, password)
    end, function(err)
      get_notify()(string.format("Failed to fetch password secret: %s", err), vim.log.levels.ERROR)
      callback(nil, nil)
    end)
  end, function(err)
    get_notify()(string.format("Failed to fetch username secret: %s", err), vim.log.levels.ERROR)
    callback(nil, nil)
  end)
end

-- ---------------------------------------------------------------------------
-- URL-encode a string (percent-encoding for userinfo in URIs)
-- ---------------------------------------------------------------------------

local function url_encode(str)
  return (str:gsub("[^%w%-%.%_~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- ---------------------------------------------------------------------------
-- activate_connection — set as the single active connection + save cache
-- ---------------------------------------------------------------------------

function AzureSqlSource:activate_connection(
  subscription_id,
  resource_group,
  server_name,
  database_name,
  username,
  password
)
  local url = string.format(
    "sqlserver://%s:%s@%s.database.windows.net:1433?database=%s&encrypt=true",
    url_encode(username),
    url_encode(password),
    server_name,
    database_name
  )

  self.connections = {
    {
      id = "azure-active",
      name = string.format("%s/%s", server_name, database_name),
      type = "sqlserver",
      url = url,
    },
  }

  self.current_selection = {
    subscription_id = subscription_id,
    resource_group = resource_group,
    server = server_name,
    database = database_name,
  }

  -- persist connection metadata to JSON cache (no credentials)
  local cache = load_cache()
  cache[vim.fn.getcwd()] = self.current_selection
  save_cache(cache)

  -- persist credentials to macOS Keychain (encrypted)
  save_credentials(server_name, username, password)

  -- reload dbee source and refresh drawer
  local ok1, dbee_core = pcall(require, "dbee.api.core")
  local ok2, dbee_ui = pcall(require, "dbee.api.ui")
  if ok1 then
    dbee_core.source_reload(self:name())
  end
  if ok2 then
    dbee_ui.drawer_refresh()
  end

  get_notify()(string.format("Connected to %s/%s", server_name, database_name), vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- auto_connect — restore from cache on DbeeOpen
-- ---------------------------------------------------------------------------

function AzureSqlSource:auto_connect()
  if self.connecting then
    return
  end
  -- skip if already connected
  if #self.connections > 0 then
    return
  end

  local cache = load_cache()
  local entry = cache[vim.fn.getcwd()]
  if not entry or not entry.subscription_id or not entry.server then
    return
  end

  get_notify()(string.format("Auto-connecting to %s/%s…", entry.server, entry.database), vim.log.levels.INFO)
  self:connect(entry.subscription_id, entry.resource_group, entry.server, entry.database, false)
end

-- ---------------------------------------------------------------------------
-- Module export
-- ---------------------------------------------------------------------------

function M.new()
  return AzureSqlSource:new()
end

return M
