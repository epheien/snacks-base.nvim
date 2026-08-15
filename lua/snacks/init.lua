---@class Snacks: snacks.plugins
local M = {}

setmetatable(M, {
  __index = function(t, k)
    local ok, mod = pcall(require, "snacks." .. k)
    if not ok then
      error(mod)
    end
    t[k] = mod
    return mod
  end,
})

_G.Snacks = M
_G.svim = vim.fn.has("nvim-0.11") == 1 and vim or require("snacks.compat")

M.version = "base"

local config = {
  image = {
    formats = {
    "png",
    "jpg",
    "jpeg",
    "gif",
    "bmp",
    "webp",
    "tiff",
    "heic",
    "avif",
    "mp4",
    "mov",
    "avi",
    "mkv",
    "webm",
    "pdf",
    "icns",

    },
  },
  styles = {},
}

---@class snacks.config: snacks.Config
M.config = setmetatable({}, {
  __index = function(_, k)
    config[k] = config[k] or {}
    return config[k]
  end,
  __newindex = function(_, k, v)
    config[k] = v
  end,
})

local is_dict_like = function(v)
  return type(v) == "table" and (vim.tbl_isempty(v) or not svim.islist(v))
end

local is_dict = function(v)
  return type(v) == "table" and (vim.tbl_isempty(v) or not v[1])
end

---@generic T
---@param ... T
---@return T
function M.config.merge(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if is_dict_like(ret) and is_dict(value) then
      for k, v in pairs(value) do
        ret[k] = M.config.merge(ret[k], v)
      end
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

---@generic T: table
---@param snack string
---@param defaults T
---@param ... T[]
---@return T
function M.config.get(snack, defaults, ...)
  local merge = {}
  for i = 1, select("#", ...) + 2 do
    local value = i == 1 and defaults or (i == 2 and config[snack] or select(i - 2, ...))
    if type(value) == "table" then
      merge[#merge + 1] = vim.deepcopy(value)
    end
  end
  local ret = M.config.merge(unpack(merge))
  if type(ret.config) == "function" then
    ret.config(ret, defaults)
  end
  return ret
end

---@param name string
---@param defaults snacks.win.Config|{}
---@return string
function M.config.style(name, defaults)
  config.styles[name] = vim.tbl_deep_extend("force", vim.deepcopy(defaults), config.styles[name] or {})
  return name
end

M.did_setup = false
M.did_setup_after_vim_enter = false

---@param opts snacks.Config?
function M.setup(opts)
  if M.did_setup then
    return vim.notify("snacks-base.nvim is already setup", vim.log.levels.ERROR, { title = "snacks-base.nvim" })
  end
  M.did_setup = true
  opts = opts or {}
  for _, value in pairs(opts) do
    if type(value) == "table" then
      value.enabled = value.enabled == nil or value.enabled
    end
  end
  config = vim.tbl_deep_extend("force", config, opts)

  if M.config.image and M.config.image.enabled then
    local ok, image = pcall(require, "snacks.image")
    if ok and image.setup then
      image.setup()
    end
  end
end

return M
