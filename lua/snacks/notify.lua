local M = {}

setmetatable(M, {
  __call = function(_, msg, opts)
    return M.notify(msg, nil, opts)
  end,
})

function M.notify(msg, level, opts)
  opts = opts or {}
  return vim.notify(msg, level or opts.level or vim.log.levels.INFO, opts)
end

function M.info(msg, opts)
  return M.notify(msg, vim.log.levels.INFO, opts)
end

function M.warn(msg, opts)
  return M.notify(msg, vim.log.levels.WARN, opts)
end

function M.error(msg, opts)
  return M.notify(msg, vim.log.levels.ERROR, opts)
end

return M
