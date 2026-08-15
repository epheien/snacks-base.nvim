#!/usr/bin/env lua

-- Extract snacks.nvim into two mutually-exclusive standalone plugin packages:
--
--   build/snacks-base.nvim   - minimal Snacks runtime used by split plugins
--   build/snacks-image.nvim  - original Snacks.image implementation
--
-- Usage:
--   lua scripts/extract-image.lua [source-root] [target-root] [--force]
--
-- Options:
--   --source PATH   upstream snacks.nvim source root
--   --target PATH   directory containing snacks-base.nvim and snacks-image.nvim
--   --force         replace generated contents
--
-- When this script lives at SOURCE/build/snacks-base.nvim/scripts, source-root
-- defaults to SOURCE and target-root defaults to SOURCE/build. Existing
-- generated packages are replaced only when --force is passed and a generated
-- marker is present. If a generated package is already a git repository, its
-- .git directory is preserved.

local GENERATED = ".snacks-extracted-generated"
local LEGACY_GENERATED = ".snacks-image-generated"

local function shq(str)
  return "'" .. tostring(str):gsub("'", "'\\''") .. "'"
end

local function run(cmd)
  local ok, why, code = os.execute(cmd)
  if ok == true or ok == 0 then
    return
  end
  error(("command failed (%s:%s): %s"):format(tostring(why), tostring(code), cmd))
end

local function capture(cmd)
  local handle = assert(io.popen(cmd))
  local out = assert(handle:read("*a"))
  local ok = handle:close()
  if not ok then
    error("command failed: " .. cmd)
  end
  return (out:gsub("%s+$", ""))
end

local function exists(path)
  local ok = os.rename(path, path)
  if ok then
    return true
  end
  local fd = io.open(path, "r")
  if fd then
    fd:close()
    return true
  end
  return false
end

local function dirname(path)
  return path:match("^(.*)/[^/]*$") or "."
end

local function basename(path)
  return path:match("([^/]+)$") or path
end

local function abs(path, base)
  if path:sub(1, 1) ~= "/" then
    path = (base or capture("pwd -P")) .. "/" .. path
  end
  local dir = dirname(path)
  local name = basename(path)
  run("mkdir -p " .. shq(dir))
  return capture("cd " .. shq(dir) .. " && pwd -P") .. "/" .. name
end

local function abs_dir(path, base)
  if path:sub(1, 1) ~= "/" then
    path = (base or capture("pwd -P")) .. "/" .. path
  end
  return capture("cd " .. shq(path) .. " && pwd -P")
end

local function read_file(path)
  local fd = assert(io.open(path, "rb"))
  local data = assert(fd:read("*a"))
  fd:close()
  return data
end

local function write_file(path, data)
  run("mkdir -p " .. shq(dirname(path)))
  local fd = assert(io.open(path, "wb"))
  assert(fd:write(data))
  fd:close()
end

local function list_files(path)
  local out = capture("find " .. shq(path) .. " -type f | sort")
  local ret = {}
  for file in out:gmatch("[^\n]+") do
    ret[#ret + 1] = file
  end
  return ret
end

local function copy_file(src, dest)
  write_file(dest, read_file(src))
end

local function copy_tree(src, dest, filter)
  for _, file in ipairs(list_files(src)) do
    local rel = file:sub(#src + 2)
    if not filter or filter(rel, file) then
      copy_file(file, dest .. "/" .. rel)
    end
  end
end

local script = arg[0] or "scripts/extract-image.lua"
local script_abs = abs(script)
local script_dir = dirname(script_abs)
local control_root = abs_dir(script_dir .. "/..")

local inferred_source = script_dir .. "/../../.."
if exists(inferred_source .. "/lua/snacks/image/init.lua") then
  inferred_source = abs_dir(inferred_source)
else
  inferred_source = os.getenv("SNACKS_NVIM_SOURCE")
end

local force = false
local source_arg
local target_arg
local index = 1
while index <= #arg do
  local item = arg[index]
  if item == "--force" then
    force = true
  elseif item == "--source" then
    index = index + 1
    source_arg = arg[index]
  elseif item:find("^%-%-source=") then
    source_arg = item:match("^%-%-source=(.*)$")
  elseif item == "--target" then
    index = index + 1
    target_arg = arg[index]
  elseif item:find("^%-%-target=") then
    target_arg = item:match("^%-%-target=(.*)$")
  elseif item == "--help" or item == "-h" then
    print("Usage: lua scripts/extract-image.lua [source-root] [target-root] [--force]")
    os.exit(0)
  elseif not source_arg then
    source_arg = item
  elseif not target_arg then
    target_arg = item
  else
    error("unexpected argument: " .. item)
  end
  index = index + 1
end

local root = abs_dir(source_arg or inferred_source or ".")
if not exists(root .. "/lua/snacks/image/init.lua") then
  error("source root does not look like snacks.nvim: " .. root)
end

local target_root = abs(target_arg or dirname(control_root))
local base_target = target_root .. "/snacks-base.nvim"
local image_target = target_root .. "/snacks-image.nvim"
local self_script = read_file(script_abs)
local extraction_doc_path = control_root .. "/docs/extraction.md"
local extraction_doc = exists(extraction_doc_path) and read_file(extraction_doc_path) or nil

local function prepare_package(path)
  if exists(path) then
    if not force then
      error("target exists; pass --force to replace generated output: " .. path)
    end
    if not (exists(path .. "/" .. GENERATED) or exists(path .. "/" .. LEGACY_GENERATED)) then
      error("refusing to remove target without generated marker: " .. path)
    end
    run("find " .. shq(path) .. " -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +")
  else
    run("mkdir -p " .. shq(path))
  end
  write_file(path .. "/" .. GENERATED, "generated by scripts/extract-image.lua\n")
end

prepare_package(base_target)
prepare_package(image_target)

local formats = [===[
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
]===]

local base_runtime = {}

base_runtime[".gitignore"] = [===[
.DS_Store
doc/tags
]===]

base_runtime["lua/snacks/init.lua"] = ([===[
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
%s
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
]===]):format(formats)

base_runtime["lua/snacks/notify.lua"] = [===[
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
]===]

base_runtime["lua/snacks/debug.lua"] = [===[
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
]===]

base_runtime["lua/snacks/health.lua"] = [===[
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
]===]

base_runtime["lua/snacks/picker/init.lua"] = [===[
---@class snacks.picker
local M = {}

M.util = require("snacks.picker.util")

return M
]===]

base_runtime["lua/snacks/picker/util/init.lua"] = [===[
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
]===]

base_runtime["plugin/snacks-base.lua"] = [===[
if vim.g.loaded_snacks_base == 1 then
  return
end
vim.g.loaded_snacks_base = 1
]===]

base_runtime["README.md"] = [===[
# snacks-base.nvim

Minimal runtime extracted from snacks.nvim for standalone split packages.

This package keeps the original `Snacks` namespace and is intended to be used
mutually exclusively with the full snacks.nvim package.

Extraction and update workflow notes are in [docs/extraction.md](docs/extraction.md).

Example with lazy.nvim:

```lua
{
  dir = "/path/to/snacks-base.nvim",
  main = "snacks",
  opts = {
    image = {},
  },
}
```
]===]

base_runtime["scripts/extract-image.lua"] = self_script
if extraction_doc then
  base_runtime["docs/extraction.md"] = extraction_doc
end

local image_runtime = {}

image_runtime[".gitignore"] = [===[
.DS_Store
doc/tags
]===]

image_runtime["plugin/snacks-image.lua"] = [===[
if vim.g.loaded_snacks_image == 1 then
  return
end
vim.g.loaded_snacks_image = 1

vim.schedule(function()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return
  end

  -- Loading the standalone image package should enable it by default, just as
  -- `Snacks.setup({ image = {} })` does in the monolithic package. Keep an
  -- explicit `enabled = false` override intact.
  local config = snacks.config.image
  if config.enabled == nil then
    config.enabled = true
  end
  if not config.enabled then
    return
  end

  local image = require("snacks.image")
  image.setup()

  -- setup is deferred so that a user's Snacks config can be applied first.
  -- A document opened on the command line may already have emitted FileType by
  -- this point, so attach any matching buffers that are already loaded.
  if image.config.doc.enabled then
    local langs = image.langs()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
        if vim.tbl_contains(langs, lang) then
          image.doc.attach(buf)
        end
      end
    end
  end
end)
]===]

image_runtime["README.md"] = [===[
# snacks-image.nvim

Standalone `Snacks.image` package extracted from snacks.nvim.

Requires `snacks-base.nvim` on the runtime path. This package keeps the original
`Snacks.image` namespace and is intended to be used mutually exclusively with
the full snacks.nvim package.

Example with lazy.nvim:

```lua
{
  dir = "/path/to/snacks-image.nvim",
  dependencies = {
    { dir = "/path/to/snacks-base.nvim" },
  },
}
```

Loading this package enables `Snacks.image` by default. To configure it or
disable it explicitly, configure the base package before this plugin loads:

```lua
{
  dir = "/path/to/snacks-base.nvim",
  main = "snacks",
  opts = {
    image = {
      -- enabled = false,
    },
  },
}
```
]===]

local function write_runtime(target, files)
  for rel, data in pairs(files) do
    write_file(target .. "/" .. rel, data)
  end
end

copy_file(root .. "/LICENSE", base_target .. "/LICENSE")
copy_file(root .. "/LICENSE", image_target .. "/LICENSE")

copy_file(root .. "/lua/snacks/compat.lua", base_target .. "/lua/snacks/compat.lua")
copy_file(root .. "/lua/snacks/win.lua", base_target .. "/lua/snacks/win.lua")
copy_tree(root .. "/lua/snacks/util", base_target .. "/lua/snacks/util")
copy_file(root .. "/lua/snacks/picker/util/async.lua", base_target .. "/lua/snacks/picker/util/async.lua")
write_runtime(base_target, base_runtime)
run("chmod +x " .. shq(base_target .. "/scripts/extract-image.lua"))

copy_tree(root .. "/lua/snacks/image", image_target .. "/lua/snacks/image")
copy_file(root .. "/docs/image.md", image_target .. "/docs/image.md")
if exists(root .. "/doc/snacks.nvim-image.txt") then
  copy_file(root .. "/doc/snacks.nvim-image.txt", image_target .. "/doc/snacks.nvim-image.txt")
end
copy_tree(root .. "/tests/image", image_target .. "/tests/image")
copy_tree(root .. "/queries", image_target .. "/queries", function(rel)
  return rel:match("/images%.scm$") or rel:match("/injections%.scm$")
end)
write_runtime(image_target, image_runtime)

print("generated " .. base_target)
print("generated " .. image_target)
