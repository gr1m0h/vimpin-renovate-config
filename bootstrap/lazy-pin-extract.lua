-- lazy-pin-extract: bridge lazy.nvim runtime URLs with lazy-lock.json so
-- lazy.nvim's lockfile can either be augmented with `url` fields (for the
-- lazy-nvim-lock Renovate preset) or projected into a vimpin.toml manifest.
--
-- Usage (from Neovim, with lazy.nvim already loaded):
--
--   :lua require("lazy-pin-extract").augment_lock()
--     Adds a "url" field to every entry in lazy-lock.json so the
--     lazy-nvim-lock Renovate preset can identify each plugin.
--
--   :lua require("lazy-pin-extract").to_vimpin_manifest()
--     Writes lazy-pins.toml in vimpin schema (repo + commit + branch/tag).
--
-- Drop this file under your nvim config so `require("lazy-pin-extract")` works,
-- or call it with a fully qualified path via :luafile.

local M = {}

local function parse_repo(url)
  if not url then return nil, nil end
  for _, host in ipairs({ "github.com", "gitlab.com" }) do
    local pat = host:gsub("%.", "%%.")
    local repo = url:match("^https?://" .. pat .. "/(.+)$") or url:match("^git@" .. pat .. ":(.+)$")
    if repo then
      repo = repo:gsub("%.git$", "")
      return host, repo
    end
  end
  local sr = url:match("^https?://git%.sr%.ht/(.+)$")
  if sr then return "git.sr.ht", sr end
  return nil, nil
end

local function lazy_spec_index()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    error("lazy.nvim is not loaded; run :Lazy or boot the config first")
  end
  local out = {}
  for _, p in ipairs(lazy.plugins()) do
    out[p.name] = p
  end
  return out
end

local function read_lock(path)
  local f = io.open(path, "r")
  if not f then error("cannot read " .. path) end
  local body = f:read("*a")
  f:close()
  return vim.json.decode(body)
end

local function write_json(path, obj)
  local body = vim.json.encode(obj)
  local f = assert(io.open(path, "w"))
  f:write(body)
  f:close()
end

local function lock_path(opts)
  return (opts and opts.lock_path) or (vim.fn.stdpath("config") .. "/lazy-lock.json")
end

--- Add a "url" field to every entry in lazy-lock.json by looking up the
--- live lazy.nvim plugin spec. Idempotent: existing url values are kept.
function M.augment_lock(opts)
  local path = lock_path(opts)
  local lock = read_lock(path)
  local specs = lazy_spec_index()
  local touched = 0
  for name, entry in pairs(lock) do
    if not entry.url then
      local spec = specs[name]
      if spec and spec.url then
        entry.url = spec.url
        touched = touched + 1
      end
    end
  end
  write_json(path, lock)
  print(string.format("lazy-pin-extract: augmented %d entries in %s", touched, path))
end

--- Project lazy.nvim's state into a vimpin.toml manifest. Useful for users
--- who want Renovate to manage their pins via the vimpin schema without
--- adopting the vimpin CLI for installation.
function M.to_vimpin_manifest(opts)
  opts = opts or {}
  local path = opts.lock_path or lock_path(opts)
  local out_path = opts.output_path or (vim.fn.stdpath("config") .. "/lazy-pins.toml")

  local lock = read_lock(path)
  local specs = lazy_spec_index()

  local lines = {
    'schema = "https://vimpin.io/schema/v1"',
    "",
    "[settings]",
    'default_host = "github.com"',
    'allow_hosts = ["github.com", "gitlab.com", "git.sr.ht"]',
    "",
  }

  local names = {}
  for n in pairs(lock) do names[#names + 1] = n end
  table.sort(names)

  for _, name in ipairs(names) do
    local entry = lock[name]
    local spec = specs[name]
    local url = entry.url or (spec and spec.url)
    local host, repo = parse_repo(url)
    if host and repo then
      lines[#lines + 1] = "[[plugin]]"
      lines[#lines + 1] = string.format('repo = "%s"', repo)
      if host ~= "github.com" then
        lines[#lines + 1] = string.format('host = "%s"', host)
      end
      if entry.commit then
        lines[#lines + 1] = string.format('commit = "%s"', entry.commit)
      end
      -- Prefer tag if the user's spec carries one; otherwise version; else fall back to branch.
      if spec and spec.tag then
        lines[#lines + 1] = string.format('tag = "%s"', spec.tag)
      elseif spec and spec.version then
        lines[#lines + 1] = string.format('tag = "%s"', spec.version)
      elseif entry.branch then
        lines[#lines + 1] = string.format('branch = "%s"', entry.branch)
      end
      lines[#lines + 1] = ""
    end
  end

  local f = assert(io.open(out_path, "w"))
  f:write(table.concat(lines, "\n"))
  f:close()
  print("lazy-pin-extract: wrote " .. out_path)
end

return M
