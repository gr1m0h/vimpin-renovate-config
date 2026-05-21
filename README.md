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

| Preset | Targets | When to use |
|--------|---------|-------------|
| `:vimpin`   | `vimpin.toml`              | You use vimpin as the source of truth |
| `:lua-pin`  | `*.lua` plugin specs       | You write lazy.nvim / packer.nvim specs by hand with inline `commit = "..."` |
| `:vim-plug` | `init.vim`, `*.vim`, `.vimrc` | You use vim-plug with `'commit'` in the spec dict |

Bare `github>gr1m0h/vimpin-renovate-config` extends all three.

## Supported formats

### vimpin.toml

```toml
[[plugin]]
repo = "ggandor/leap.nvim"
commit = "abc1234567890abcdef0123456789abcdef0123"  # 40-hex
tag = "v0.1.5"      # or: branch = "main"
```

The preset auto-detects which tracking strategy to apply per entry:
- `commit + tag` → tracked via `github-tags` datasource
- `commit + branch` → tracked via `git-refs` (branch HEAD)

### lazy.nvim / packer.nvim Lua specs

```lua
-- tag-tracked
{ "ggandor/leap.nvim", commit = "abc1234567890abcdef0123456789abcdef0123", tag = "v0.1.5" }

-- branch-tracked
{ "folke/which-key.nvim", commit = "def5678...", branch = "main" }

-- frozen (no tracking ref → Renovate ignores it on purpose)
{ "some/plugin", commit = "0000..." }
```

Field order must be **`"owner/repo", commit = "...", tag/branch = "..."`**. Renovate's regex managers cannot reliably handle arbitrary spec bodies, so this canonical order is required for the manager to fire. If you want a different ordering, you can copy the preset and tweak the regex locally.

### vim-plug

```vim
" tag-tracked
Plug 'ggandor/leap.nvim', { 'commit': 'abc1234567890abcdef0123456789abcdef0123', 'tag': 'v0.1.5' }

" branch-tracked
Plug 'folke/which-key.nvim', { 'commit': 'def5678...', 'branch': 'main' }
```

## How updates land

For each matched entry, Renovate opens a PR that bumps the `commit` value (`currentDigest`) and, where applicable, the `tag` or `branch` value (`currentValue`). The actual checkout still happens through your plugin manager — vimpin or otherwise — so nothing in this preset depends on how plugins are installed.

## Caveats

- **`lazy-lock.json` is not supported.** lazy.nvim's lockfile stores only the plugin short name (e.g. `telescope.nvim`), not `owner/repo`, so Renovate cannot resolve where to fetch updates from. Pin in your spec files (or in `vimpin.toml`) instead.
- **Field order matters.** As noted above, the regex managers rely on a canonical order. This trade-off keeps the patterns simple and predictable; a future JSONata-based manager could be more permissive.
- **Frozen entries.** Pins with only `commit` (no `tag` or `branch`) are intentionally invisible to Renovate. That is the supported way to say "do not update".

## License

MIT
