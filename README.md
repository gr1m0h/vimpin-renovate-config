# vimpin-renovate-config

Renovate preset for pinning Vim/Neovim plugins by commit hash. Works with or without [vimpin](https://github.com/gr1m0h/vimpin) — drop it into any dotfiles repo that pins plugins explicitly and Renovate will start opening update PRs.

## Use

In your dotfiles repo's `renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>gr1m0h/vimpin-renovate-config"]
}
```

That enables every supported format below. If you only want one, pick the sub-preset:

```json
{ "extends": ["github>gr1m0h/vimpin-renovate-config:lua-pin"] }
```

| Preset             | Targets                          | When to use |
|--------------------|----------------------------------|-------------|
| `:vimpin`          | `vimpin.toml`                    | vimpin is your source of truth |
| `:lua-pin`         | `*.lua` plugin specs             | lazy.nvim / packer.nvim with inline `commit = "..."` |
| `:vim-plug`        | `init.vim`, `*.vim`, `.vimrc`    | vim-plug with `'commit'` in the spec dict |
| `:lazy-nvim-lock`  | `lazy-lock.json`                 | lazy.nvim's lockfile, **augmented with `url` fields** (see below) |

The bare `github>gr1m0h/vimpin-renovate-config` extends all four.

## Supported formats

### vimpin.toml

```toml
[[plugin]]
repo = "ggandor/leap.nvim"
commit = "abc1234567890abcdef0123456789abcdef0123"  # 40-hex
tag = "v0.1.5"      # or: branch = "main"
```

Tracking strategy is picked per entry:
- `commit + tag` → `github-tags` datasource (tag tracking)
- `commit + branch` → `git-refs` datasource (branch HEAD tracking)
- `tag` only (no commit) → `github-tags` (tag bumped, `vimpin pin` fills the commit later)

### lazy.nvim / packer.nvim Lua specs

The Lua regex managers require the pinning fields to appear in a fixed
order, **immediately after the repo name**:

```
repo  →  commit  →  tag | branch | version  →  (anything else)
```

This is the most common operational footgun. If Renovate stops finding an
entry you just edited, the cause is almost always that `config`, `opts`,
`event`, `keys`, etc. crept in between the repo and the pinning fields.

#### Supported patterns

```lua
-- tag-tracked pin (either order of commit/tag works)
{ "ggandor/leap.nvim", commit = "abc1234567890abcdef0123456789abcdef0123", tag = "v0.1.5" }

-- semver-tracked pin (version is treated as a semver range)
{ "ggandor/leap.nvim", commit = "abc...", version = "^0.1" }

-- branch-tracked pin
{ "folke/which-key.nvim", commit = "def5678...", branch = "main" }

-- tag-only tracking (no commit pin; Renovate bumps the tag when a newer release lands)
{ "ggandor/leap.nvim", tag = "v0.1.5" }
{ "ggandor/leap.nvim", version = "^0.1" }
```

Multi-line specs are supported as long as the matching fields appear consecutively, e.g.:

```lua
{
  "ggandor/leap.nvim",
  commit = "abc1234567890abcdef0123456789abcdef0123",
  tag = "v0.1.5",
  -- other settings (event, keys, config) may appear AFTER the pinning fields
}
```

#### Unsupported patterns (Renovate will silently skip)

```lua
-- repo and pinning fields separated by config — NOT matched
{
  "ggandor/leap.nvim",
  event = "VeryLazy",
  commit = "abc...",
  tag = "v0.1.5",
}

-- config = function() before the pin — NOT matched
{ "ggandor/leap.nvim", config = function() ... end, commit = "abc...", tag = "v0.1.5" }
```

#### Recommended guardrails

Because the order is regex-based, the preset cannot warn you when an
entry is silently skipped. Two practical mitigations:

- **Use `vimpin generate`.** If your manifest lives in `vimpin.toml`, the
  generated Lua spec emits fields in the supported order by construction.
- **Lint locally.** Run `renovate-config-validator` on the config, then
  `renovate --dry-run --print-config` (LOG_LEVEL=debug) against a checkout
  to see which dependencies the managers actually pick up before pushing.

### vim-plug

```vim
" tag-tracked
Plug 'ggandor/leap.nvim', { 'commit': 'abc1234567890abcdef0123456789abcdef0123', 'tag': 'v0.1.5' }

" branch-tracked
Plug 'folke/which-key.nvim', { 'commit': 'def5678...', 'branch': 'main' }
```

The same field-order rule applies: `commit` and `tag`/`branch` should be
the first keys inside the spec dict.

### lazy-lock.json (with url augmentation)

`lazy-lock.json` is keyed by plugin short name, not `owner/repo`, so Renovate can't identify a plugin from the lockfile alone. The `:lazy-nvim-lock` preset works on lockfile entries that **also carry a `url` field**:

```json
{
  "telescope.nvim": {
    "branch": "master",
    "commit": "abc1234567890abcdef0123456789abcdef0123",
    "url": "https://github.com/nvim-telescope/telescope.nvim"
  }
}
```

lazy.nvim emits `url` for non-default sources but not for default GitHub plugins. Use the bootstrap helper below to augment the lockfile.

## Bootstrap helper (`lazy-pin-extract.lua`)

A small Lua module is included under [`bootstrap/lazy-pin-extract.lua`](bootstrap/lazy-pin-extract.lua) for users who want Renovate to manage `lazy-lock.json` directly or who prefer the vimpin schema without adopting the vimpin CLI.

Two entry points:

```vim
:lua require('lazy-pin-extract').augment_lock()
" Adds the missing "url" field to every entry in lazy-lock.json, in place.
" Run this after Plug install or whenever you add new plugins. Commit the
" augmented file; Renovate (via :lazy-nvim-lock) takes it from there.

:lua require('lazy-pin-extract').to_vimpin_manifest()
" Writes lazy-pins.toml in vimpin schema by combining lazy.nvim's runtime
" plugin URLs with lazy-lock.json's commits and your spec's tag/branch.
```

Install by copying the file to a path Neovim can `require`, for example:

```bash
mkdir -p ~/.config/nvim/lua
curl -fsSL https://raw.githubusercontent.com/gr1m0h/vimpin-renovate-config/main/bootstrap/lazy-pin-extract.lua \
  -o ~/.config/nvim/lua/lazy-pin-extract.lua
```

### Headless invocation

`augment_lock()` depends on lazy.nvim's runtime plugin index, so lazy must
be fully loaded before the call. From a headless shell:

```bash
nvim --headless \
  -c "lua require('lazy').sync({wait = true})" \
  -c "lua require('lazy-pin-extract').augment_lock()" \
  -c "qa!"
```

Without the `Lazy sync`/`Lazy load` step first, `lazy.plugins()` may
return an empty or partial list and entries will be silently skipped.

## How updates land

For each matched entry, Renovate opens a PR that bumps the `commit` value (`currentDigest`) and, where applicable, the `tag`, `branch`, or `version` value (`currentValue`). The actual checkout still happens through your plugin manager — vimpin or otherwise — so nothing in this preset depends on how plugins are installed.

## Recommended companion config

Once the preset is matching dozens of plugins, the default Renovate
schedule produces a PR storm. A reasonable starting config:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "github>gr1m0h/vimpin-renovate-config"
  ],
  "dependencyDashboard": true,
  "prConcurrentLimit": 5,
  "prHourlyLimit": 2,
  "schedule": ["before 9am on monday"],
  "packageRules": [
    {
      "matchManagers": ["custom.regex"],
      "matchFileNames": ["**/vimpin.toml"],
      "groupName": "vimpin-pinned",
      "addLabels": ["vimpin"]
    },
    {
      "matchPackageNames": ["LazyVim/LazyVim"],
      "groupName": "lazyvim-distribution",
      "schedule": ["before 9am on first monday of month"],
      "dependencyDashboardApproval": true
    }
  ]
}
```

Why each knob:

- `dependencyDashboard: true` — gives a single issue listing every pending
  update; essential when 50+ plugins are in scope.
- `prConcurrentLimit` / `prHourlyLimit` — caps the open-PR backlog so a
  bulk bump (e.g., LazyVim major) does not drown the repo.
- `schedule` — batches the noise into one weekly window.
- `dependencyDashboardApproval` on LazyVim — distribution-layer bumps
  warrant a human pre-approval before the PR even opens.

Tune the schedules and groupings to your team's tolerance; the preset
itself stays neutral on policy.

## Caveats

- **`lazy-lock.json` requires `url`.** Without it, Renovate cannot map a short name back to a repository. Run `lazy-pin-extract.augment_lock()` once to populate `url`, then commit.
- **Field order matters for Lua / vim-plug specs.** The regex managers expect pinning fields (`commit`, `tag`, `branch`, `version`) to appear right after the repo name. Custom config (`event`, `keys`, `opts`, `config = function()`) must come afterward, or Renovate will silently skip the entry.
- **Tag-only tracking** is supported but does not lock to a commit; Renovate just bumps the tag value when a newer release exists.
- **Frozen entries** (`commit` only, no `tag`/`branch`/`version`) are intentionally invisible to Renovate. That is the supported way to say "do not update".

## License

MIT
