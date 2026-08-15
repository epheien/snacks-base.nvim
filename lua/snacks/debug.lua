local M = {}

local function shell_join(cmd, args)
  if type(cmd) == "table" then
    return table.concat(vim.tbl_map(tostring, cmd), " ")
  end
  local parts = { tostring(cmd or "") }
  for _, arg in ipairs(args or {}) do
    parts[#parts + 1] = tostring(arg)
  end
  return table.concat(parts, " ")
end

function M.cmd(opts)
  opts = opts or {}
  local rendered = shell_join(opts.cmd, opts.args)
  if opts.cwd then
    rendered = ("cd %s\n%s"):format(opts.cwd, rendered)
  end
  local ret = "```sh\n" .. rendered .. "\n```"
  if opts.footer then
    ret = ret .. "\n\n" .. opts.footer
  end
  if opts.notify ~= false then
    Snacks.notify(ret, opts.level or vim.log.levels.INFO, { title = opts.title or opts.header or "Command" })
  end
  return ret
end

function M.inspect(...)
  if vim.print then
    return vim.print(...)
  end
  print(vim.inspect({ ... }))
end

return M
