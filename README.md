# vimpin-renovate-config

Renovate preset for keeping Vim/Neovim plugin pins up to date.

Built to consume [vimpin](https://github.com/gr1m0h/vimpin)'s canonical
Lua spec form, but the managers work on any Lua spec that follows the same
layout — vimpin is not a requirement for using this preset.

## Use

In your dotfiles repo's `renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>gr1m0h/vimpin-renovate-config"]
}
```

The default preset enables every supported manager. To pull in only one,
extend the sub-preset directly:

```json
{ "extends": ["github>gr1m0h/vimpin-renovate-config:lua-pin"] }
```

| Preset             | Targets                | When to use |
|--------------------|------------------------|-------------|
| `:lua-pin`         | `*.lua` plugin specs   | lazy.nvim specs pinned in vimpin's canonical form |
| `:lazy-nvim-lock`  | `lazy-lock.json`       | lazy.nvim's lockfile, **augmented with `url` fields** (see below) |

The bare `github>gr1m0h/vimpin-renovate-config` extends both.

## Supported Lua spec form

The `:lua-pin` manager looks for entries shaped like vimpin's canonical
output (commit hash abbreviated with `...` for readability):

```lua
-- Form A: single-line spec
{ "ggandor/leap.nvim", commit = "8a40d3aa...07b9079b" }, -- tag: v0.1.5

-- Form B: multi-line spec
{
  "folke/which-key.nvim",
  commit = "3aab2147...0a44c15a", -- branch: main
  keys = { "<leader>" },
  config = function() end,
}
```

Two invariants must hold for Renovate to pick up the entry:

1. **`commit` comes immediately after the positional repo string.** Between
   the closing quote of the repo and the start of `commit = "..."` there
   may be only whitespace (including newlines) and the comma separator. No
   other fields belong in that slot.
2. **The `-- tag: <ref>` or `-- branch: <ref>` annotation is on the same
   line as the commit value.** For Form A, that line ends with the closing
   `},`; for Form B, the annotation trails the commit field's value
   directly. Either way the regex never has to span a newline between the
   commit and its annotation.

vimpin emits this layout by construction. If you edit specs by hand, keep
the field order — Renovate will silently skip non-conforming entries.

### Branch tracking vs tag tracking

- `-- tag: <ref>` → managed by `github-tags` datasource. Renovate opens a
  PR whenever a newer tag exists on the upstream repo and atomically
  rewrites both the commit hash and the annotation.
- `-- branch: <name>` → managed by `git-refs` datasource. Renovate opens a
  PR whenever the branch's HEAD moves and rewrites the commit hash; the
  annotation stays as-is (the branch name itself does not change).

### lazy-lock.json (with url augmentation)

`lazy-lock.json` is keyed by plugin short name, not `owner/repo`, so
Renovate cannot identify a plugin from the lockfile alone. The
`:lazy-nvim-lock` preset works on lockfile entries that **also carry a
`url` field**:

```json
{
  "telescope.nvim": {
    "branch": "master",
    "commit": "abc12345...ef012345",
    "url": "https://github.com/nvim-telescope/telescope.nvim"
  }
}
```

lazy.nvim emits `url` for non-default sources but not for default GitHub
plugins. If you need `lazy-lock.json` to be Renovate-managed, post-process
the file once to add the missing `url` fields (any small Lua snippet that
walks `lazy.plugins()` and writes them back will do). When using vimpin
itself, the lockfile is informational only — the canonical Lua spec is
the source of truth, so this preset is mostly relevant to users who have
not adopted vimpin yet.

## How updates land

For each matched entry, Renovate opens a PR that bumps the `commit` value
(`currentDigest`) and, where applicable, the annotation (`currentValue`).
Because both halves of the entry are captured in the same regex match,
they update together — drift between commit and annotation is
structurally impossible while Renovate is the sole updater.

The actual checkout still happens through lazy.nvim — nothing in this
preset depends on how plugins are installed.

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
      "matchFileNames": ["**/*.lua"],
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

- **Field order matters.** `commit` must come immediately after the
  positional repo string. Custom fields (`event`, `keys`, `opts`,
  `config = function()`) must come *after* the commit, not before. Use
  `vimpin run` to enforce this layout automatically.
- **Annotation must follow commit on the same line.** Comments placed
  elsewhere (above the spec, on the repo line, after `}` in multi-line
  specs) are ignored.
- **No HEAD-only tracking.** Specs with neither a `-- tag:` nor a `-- branch:`
  annotation are invisible to Renovate. That is the supported way to say
  "do not update this plugin": pin the commit, omit the annotation.
- **`lazy-lock.json` requires `url`.** Without it, Renovate cannot map a
  short name back to a repository.

## Roadmap

Tracked as [GitHub Issues](https://github.com/gr1m0h/vimpin-renovate-config/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement):

- **`lazy-lock.json` `url` augmentation helper** ([#1](https://github.com/gr1m0h/vimpin-renovate-config/issues/1)) — script that adds the `url` field lazy.nvim omits for default GitHub plugins
- **packer.nvim spec preset** ([#2](https://github.com/gr1m0h/vimpin-renovate-config/issues/2)) — pair with the planned packer adapter in vimpin
- **vim-plug spec preset** ([#3](https://github.com/gr1m0h/vimpin-renovate-config/issues/3)) — VimScript-side managers for `Plug 'owner/repo', { 'commit': '...' }`
- **Multi-host source URL support** ([#4](https://github.com/gr1m0h/vimpin-renovate-config/issues/4)) — gitlab.com / sr.ht / custom hosts
- **Expanded regex test cases** ([#5](https://github.com/gr1m0h/vimpin-renovate-config/issues/5)) — edge layouts and silent-skip regressions

## License

MIT
