local M = {}
M.pro_user = {
  "cmd_runner",
  "read_file",
  "create_file",
  "insert_edit_into_file",
  "get_changed_files",
  "fetch_webpage",
  "vectorcode_query",
  "vectorcode_vectorise",
  "vectorcode_ls",
  "list_code_usages",
  "file_search",
  "grep_search",
  "get_changed_files",
  "memory",
}

M.tool_groups = {
  ["pro_user"] = {
    description = "Pro User - You can search, retrieve and edit  ",
    prompt = "I'm giving you access to the ${tools} to help you searching, indexing, developing, debugging and answering",
    tools = {
      "cmd_runner",
      "read_file",
      "create_file",
      "insert_edit_into_file",
      "get_changed_files",
      "fetch_webpage",
      "vectorcode_query",
      "vectorcode_vectorise",
      "vectorcode_ls",
      "list_code_usages",
      "file_search",
      "grep_search",
      "get_changed_files",
      "memory",
    },
  },
  ["content_search"] = {
    description = "Content Searcher - Can use Vectorcode and Memory to seeach for files and contents ",
    prompt = "I'm giving you access to the ${tools} to help you searching and indexing tasks",
    tools = {
      "vectorcode_query",
      "vectorcode_vectorise",
      "vectorcode_ls",
      "list_code_usages",
      "file_search",
      "grep_search",
      "get_changed_files",
      "memory",
    },
  },
  ["dev"] = {
    description = "Expert Developer - Can use Dev Tools to write and change code ",
    prompt = "I'm giving you access to the ${tools} to help you developing, writing and debugging code",
    tools = {
      "cmd_runner",
      "read_file",
      "create_file",
      "insert_edit_into_file",
      "get_changed_files",
      "fetch_webpage",
    },
  },
  ["reseracher"] = {
    description = "Web Searcher - Can use the Web to find docs and helpful info",
    prompt = "I'm giving you access to the ${tools} to help you searching and indexing the web for docs and information",
    tools = {
      "fetch_webpage",
      "vectorcode_query",
      "file_search",
      "grep_search",
    },
  },
}

M.get_toolbox = function()
  return M.tool_groups
end

-- Get default tools for strategies
M.get_default_tools = function()
  return M.pro_user
end

M.get_vectorcode_opts = function()
  return {
    tool_group = {
      enabled = true,
      extras = { "file_search", "read_file", "grep_search", "get_changed_files", "fetch_webpage" },
      collapse = true,
    },
    tool_opts = {
      ["*"] = {
        use_lsp = true,
        requires_approval = false,
      },
      vectorise = {
        requires_approval = false,
      },
      query = {
        max_num = { chunk = 100, document = 20 },
        default_num = { chunk = 50, document = 10 },
        include_stderr = false,
        use_lsp = true,
        no_duplicate = true,
        chunk_mode = false,
        summarise = {
          enabled = true,
          adapter = nil,
          query_augmented = true,
        },
      },
    },
  }
end

return M
