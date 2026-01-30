return {
  "kndndrj/nvim-dbee",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  build = function()
    require("dbee").install("go")
  end,
  config = function()
    local azure_databases = {
      {
        short = "dap",
        env = "dt",
        subscription = "8b325692-b38a-4eb7-8a9d-28b44e2a1335",
      },
    }

    local sql_notes = require("utils.dbee_sql_notes")

    local notify
    do
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
    end

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

    local function escape_jmespath_string(value)
      if not value then
        return ""
      end
      return value:gsub("'", "\\'")
    end

    local function sanitize_rule_name(value)
      if not value or value == "" then
        return "llx-wanne-eickel"
      end
      local sanitized = value:gsub("%s+", "-"):gsub("[^%w%-]", "")
      return sanitized
    end

    local AzureSqlSource = {}
    AzureSqlSource.__index = AzureSqlSource

    function AzureSqlSource:new(databases)
      return setmetatable({
        databases = databases,
        connections = {},
        refreshing = false,
        rule_name = nil,
        cached_ip = nil,
      }, self)
    end

    function AzureSqlSource:name()
      return "azure-sql"
    end

    function AzureSqlSource:load()
      if not self.refreshing and #self.connections == 0 then
        self:refresh()
      end
      return self.connections
    end

    function AzureSqlSource:refresh(manual)
      if self.refreshing then
        if manual then
          notify("Azure refresh already running", vim.log.levels.DEBUG)
        end
        return
      end
      if #self.databases == 0 then
        notify("No Azure database entries configured", vim.log.levels.WARN)
        return
      end
      self.refreshing = true
      self:resolve_rule_name(function(rule_name)
        self:resolve_public_ip(function(ip)
          if not ip then
            self.refreshing = false
            return
          end
          self:refresh_databases(rule_name, ip)
        end)
      end)
    end

    function AzureSqlSource:resolve_rule_name(callback)
      if self.rule_name then
        callback(self.rule_name)
        return
      end
      run_job({ "git", "config", "user.name" }, function(result)
        local name = vim.fn.trim(result)
        if name == "" then
          name = vim.env.USER or "llx"
        end
        self.rule_name = sanitize_rule_name(name)
        callback(self.rule_name)
      end, function(err)
        notify(string.format("Failed to determine git user for firewall rule: %s", err), vim.log.levels.WARN)
        local fallback = sanitize_rule_name(vim.env.USER or "llx")
        self.rule_name = fallback
        callback(self.rule_name)
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
          notify("Public IP lookup returned empty value", vim.log.levels.WARN)
          callback(nil)
          return
        end
        self.cached_ip = ip
        callback(ip)
      end, function(err)
        notify(string.format("Failed to determine public IP: %s", err), vim.log.levels.WARN)
        callback(nil)
      end)
    end

    local dbee_ui = require("dbee.api.ui")
    local dbee_core = require("dbee.api.core")

    function AzureSqlSource:refresh_databases(rule_name, ip)
      local results = {}
      local remaining = #self.databases

      local function finalize()
        self.connections = results
        self.refreshing = false
        vim.schedule(function()
          notify("Azure SQL connections refreshed", vim.log.levels.INFO)
          dbee_core.source_reload(self:name())
          dbee_ui.drawer_refresh()
        end)
      end

      if remaining == 0 then
        finalize()
        return
      end

      for _, db in ipairs(self.databases) do
        self:refresh_database(db, rule_name, ip, function(conn)
          if conn then
            table.insert(results, conn)
          end
          remaining = remaining - 1
          if remaining == 0 then
            finalize()
          end
        end)
      end
    end

    function AzureSqlSource:refresh_database(db, rule_name, ip, done)
      local finished = false
      local function finalize(conn)
        if finished then
          return
        end
        finished = true
        done(conn)
      end

      local vault = string.format("sec-keyvlt-%s-%s", db.short, db.env)
      local server = string.format("data-sqlsrv-meta-%s-%s", db.short, db.env)
      local database = string.format("data-sqldb-meta-%s-%s", db.short, db.env)

      local function fetch_secrets()
        local user_cmd = {
          "az",
          "keyvault",
          "secret",
          "show",
          "--vault-name",
          vault,
          "--name",
          server .. "-username",
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
          server .. "-password",
          "--query",
          "value",
          "-o",
          "tsv",
        }
        run_job(user_cmd, function(username_result)
          local username = vim.fn.trim(username_result)
          if username == "" then
            notify(string.format("Key Vault username empty for %s", vault), vim.log.levels.ERROR)
            finalize(nil)
            return
          end
          run_job(pass_cmd, function(password_result)
            local password = vim.fn.trim(password_result)
            if password == "" then
              notify(string.format("Key Vault password empty for %s", vault), vim.log.levels.ERROR)
              finalize(nil)
              return
            end
            finalize({
              id = string.format("azure-%s-%s", db.short, db.env),
              name = string.format("%s-%s", db.short, db.env:upper()),
              type = "sqlserver",
              url = string.format(
                "sqlserver://%s:%s@%s.database.windows.net:1433?database=%s&encrypt=true",
                username,
                password,
                server,
                database
              ),
            })
          end, function(err)
            notify(string.format("Failed to fetch password secret: %s", err), vim.log.levels.ERROR)
            finalize(nil)
          end)
        end, function(err)
          notify(string.format("Failed to fetch username secret: %s", err), vim.log.levels.ERROR)
          finalize(nil)
        end)
      end

      local function ensure_firewall(resource_group)
        if not resource_group then
          finalize(nil)
          return
        end
        local rule_cmd = {
          "az",
          "sql",
          "server",
          "firewall-rule",
          "create",
          "--resource-group",
          resource_group,
          "--server",
          server,
          "--name",
          rule_name,
          "--start-ip-address",
          ip,
          "--end-ip-address",
          ip,
          "--output",
          "none",
        }
        run_job(rule_cmd, function()
          notify(string.format("Firewall rule %s on %s now allows %s", rule_name, server, ip), vim.log.levels.INFO)
          fetch_secrets()
        end, function(err)
          notify(string.format("Failed to ensure firewall rule on %s: %s", server, err), vim.log.levels.ERROR)
          finalize(nil)
        end)
      end

      local function resolve_resource_group()
        if db.resource_group and db.resource_group ~= "" then
          ensure_firewall(db.resource_group)
          return
        end
        local query = string.format("[?name=='%s'].resourceGroup | [0]", escape_jmespath_string(server))
        run_job({
          "az",
          "resource",
          "list",
          "--subscription",
          db.subscription,
          "--resource-type",
          "Microsoft.Sql/servers",
          "--query",
          query,
          "-o",
          "tsv",
        }, function(result)
          local rg = vim.fn.trim(result)
          if rg == "" then
            notify(string.format("Resource group lookup returned empty value for %s", server), vim.log.levels.ERROR)
            finalize(nil)
            return
          end
          ensure_firewall(rg)
        end, function(err)
          notify(string.format("Failed to resolve resource group for %s: %s", server, err), vim.log.levels.ERROR)
          finalize(nil)
        end)
      end

      if not db.subscription or db.subscription == "" then
        resolve_resource_group()
        return
      end
      run_job({ "az", "account", "set", "--subscription", db.subscription }, function()
        resolve_resource_group()
      end, function(err)
        notify(string.format("Failed to select subscription %s: %s", db.subscription, err), vim.log.levels.ERROR)
        finalize(nil)
      end)
    end

    local azure_source = AzureSqlSource:new(azure_databases)
    local dbee_module = require("dbee")

    local function trigger_refresh(manual)
      sql_notes.sync()
      azure_source:refresh(manual)
    end

    local function wrap_and_refresh(original)
      return function(...)
        trigger_refresh(false)
        return original(...)
      end
    end

    local original_open = dbee_module.open
    local original_toggle = dbee_module.toggle
    dbee_module.open = wrap_and_refresh(original_open)
    dbee_module.toggle = wrap_and_refresh(original_toggle)

    vim.api.nvim_create_user_command("DbeeAzureRefresh", function()
      trigger_refresh(true)
    end, { desc = "Refresh Azure SQL Dbee source" })

    dbee_module.setup({
      sources = {
        azure_source,
        require("dbee.sources").FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
      },
      extra_helpers = {
        ["sqlserver"] = {
          ["List Tables"] = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' ORDER BY TABLE_NAME",
          ["Describe Table"] = "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '{{ .Table }}' ORDER BY ORDINAL_POSITION",
          ["Select Top 100"] = "SELECT TOP 100 * FROM dbo.[{{ .Table }}]",
        },
      },
    })

  end,
}
