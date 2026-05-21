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

Supported single-line patterns (field order matters):

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

If you want Renovate to find your entry, put `commit` and `tag`/`branch`/`version` right after the repo name. Any custom config (`event`, `keys`, `opts`, `config = function()`) should come afterward.

### vim-plug

```vim
" tag-tracked
Plug 'ggandor/leap.nvim', { 'commit': 'abc1234567890abcdef0123456789abcdef0123', 'tag': 'v0.1.5' }

" branch-tracked
Plug 'folke/which-key.nvim', { 'commit': 'def5678...', 'branch': 'main' }
```

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

## How updates land

For each matched entry, Renovate opens a PR that bumps the `commit` value (`currentDigest`) and, where applicable, the `tag`, `branch`, or `version` value (`currentValue`). The actual checkout still happens through your plugin manager — vimpin or otherwise — so nothing in this preset depends on how plugins are installed.

## Caveats

- **`lazy-lock.json` requires `url`.** Without it, Renovate cannot map a short name back to a repository. Run `lazy-pin-extract.augment_lock()` once to populate `url`, then commit.
- **Field order matters for Lua / vim-plug specs.** The regex managers expect pinning fields (`commit`, `tag`, `branch`, `version`) to appear right after the repo name. Custom config can come later.
- **Tag-only tracking** is supported but does not lock to a commit; Renovate just bumps the tag value when a newer release exists.
- **Frozen entries** (`commit` only, no `tag`/`branch`/`version`) are intentionally invisible to Renovate. That is the supported way to say "do not update".

## License

MIT
