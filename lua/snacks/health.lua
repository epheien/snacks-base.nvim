local Snacks = require("snacks")

local M = {}

local function health()
  return vim.health or require("vim.health")
end

for _, key in ipairs({ "ok", "warn", "error", "info", "start" }) do
  M[key] = function(msg)
    local h = health()
    local fn = h[key] or h["report_" .. key]
    return fn(msg)
  end
end

function M.have_tool(tools)
  tools = type(tools) == "string" and { tools } or tools
  tools = tools[1] and tools or { tools }

  local all = {}
  local found = false
  for _, tool in ipairs(tools) do
    tool = type(tool) == "string" and { cmd = tool } or tool
    if tool.enabled ~= false then
      local cmds = type(tool.cmd) == "string" and { tool.cmd } or tool.cmd
      vim.list_extend(all, cmds)
      for _, cmd in ipairs(cmds) do
        if vim.fn.executable(cmd) == 1 then
          local version = tool.version == false and "" or vim.fn.system(cmd .. " --version") or ""
          version = vim.trim(vim.split(version, "\n")[1])
          M.ok(version == "" and ("`" .. cmd .. "`") or ("`" .. cmd .. "` `" .. version .. "`"))
          found = true
        end
      end
    end
  end
  if found then
    return true
  end
  all = vim.tbl_map(function(item)
    return "`" .. tostring(item) .. "`"
  end, all)
  M.error(#all == 1 and ("Tool not found: " .. all[1]) or ("None of the tools found: " .. table.concat(all, ", ")))
  return false
end

function M.has_lang(langs)
  langs = type(langs) == "string" and { langs } or langs
  local ret, available, missing = {}, {}, {}
  for _, lang in ipairs(langs) do
    local has = Snacks.util.get_lang(lang) ~= nil
    ret[lang] = has
    if has then
      available[#available + 1] = "`" .. lang .. "`"
    else
      missing[#missing + 1] = "`" .. lang .. "`"
    end
  end
  if #available > 0 then
    M.ok("Available Treesitter languages:\n  " .. table.concat(available, ", "))
  end
  if #missing > 0 then
    M.warn("Missing Treesitter languages:\n  " .. table.concat(missing, ", "))
  end
  return ret, #available, #missing
end

function M.check()
  M.start("snacks-base.nvim")
  M[Snacks.did_setup and "ok" or "warn"](Snacks.did_setup and "setup called" or "setup not called")
end

return M
