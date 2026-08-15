---@class snacks.picker.util
local M = {}

---@param str string
---@param data table<string, string|boolean|number>|table<string, string|boolean|number>[]
---@param opts? {prefix?: string, indent?: boolean}
function M.tpl(str, data, opts)
  opts = opts or {}

  local function get(key)
    if not vim.tbl_isempty(data) and svim.islist(data) and not getmetatable(data) then
      for _, item in ipairs(data) do
        if item[key] ~= nil then
          return item[key]
        end
      end
    elseif data[key] ~= nil then
      return data[key]
    end
  end

  local ret = str:gsub("(" .. vim.pesc(opts.prefix or "") .. "%b{}" .. ")", function(word)
    local inner = word:sub(2 + #(opts.prefix or ""), -2)
    local key, default = inner:match("^(.-):(.*)$")
    local value = get(key or inner)
    if value == "" and default then
      return default
    end
    return value or word
  end)

  if opts.indent then
    local lines = vim.split(ret:gsub("\t", "  "), "\n", { plain = true })
    local indent = 1000
    for _, line in ipairs(lines) do
      indent = math.min(indent, line:find("%S") or 1000)
    end
    for index, line in ipairs(lines) do
      lines[index] = line:sub(indent)
    end
    ret = table.concat(lines, "\n")
  end

  return ret
end

return M
