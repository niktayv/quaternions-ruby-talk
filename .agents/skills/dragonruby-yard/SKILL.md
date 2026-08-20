---
name: dragonruby-yard
description: Set up YARD documentation and Solargraph LSP autocomplete for DragonRuby GTK projects. Use when the user asks about IDE autocomplete, type support, Solargraph, or editor integration for DragonRuby.
---

This skill sets up rich API autocomplete and type support for DragonRuby using the [dragonruby-yard-doc](https://github.com/owenbutler/dragonruby-yard-doc) stubs and [Solargraph](https://solargraph.org).

## How It Works

DragonRuby ships its own Ruby runtime — not CRuby — so standard LSP tooling doesn't know about `args`, `GTK`, `Geometry`, etc. The `dragonruby-yard-doc` repo provides YARD-annotated stub files that teach Solargraph the full DragonRuby API, giving you autocomplete and type hints without modifying the engine.

## Setup

### 1. Clone the stubs alongside your games

```sh
# Wherever you keep your DragonRuby projects, clone the stubs as a sibling:
cd ~/games
git clone https://github.com/owenbutler/dragonruby-yard-doc.git
```

### 2. Install CRuby and Solargraph

Solargraph runs on CRuby (not DragonRuby's bundled runtime).

```sh
# macOS (rbenv or mise recommended):
brew install rbenv && rbenv install 3.3.0 && rbenv global 3.3.0

# Then install Solargraph:
gem install solargraph
```

### 3. Configure your game project

Inside your game directory (the one containing `mygame/`):

```sh
cd ~/games/my-dragonruby-game
solargraph config
```

Edit the generated `.solargraph.yml` to include your app files and the stubs:

```yaml
include:
  - "mygame/app/**/*.rb"
  - "../dragonruby-yard-doc/*.rb"
exclude:
  - vendor/**/*
require_paths: []
reporters:
  - rubocop
formatter:
  rubocop:
    cops: safe
    except: []
    only: []
    extra_args: []
require: []
domains: []
max_files: 5000
```

Adjust the relative path to `dragonruby-yard-doc` if your directory layout differs.

## Editor Integration

### VS Code

Install the [Solargraph extension](https://marketplace.visualstudio.com/items?itemName=castwide.solargraph).

Add to `.vscode/settings.json`:

```json
{
  "solargraph.useBundler": false,
  "solargraph.formatting": true,
  "solargraph.diagnostics": true
}
```

### Neovim (Mason / nvim-lspconfig)

```sh
:MasonInstall solargraph
```

Or with `nvim-lspconfig`:

```lua
require('lspconfig').solargraph.setup({
  settings = {
    solargraph = {
      diagnostics = true,
      formatting  = true
    }
  }
})
```

### Zed

Add to your Zed `settings.json`:

```json
{
  "lsp": {
    "solargraph": {
      "initialization_options": {
        "diagnostics": true,
        "formatting": true
      }
    }
  }
}
```

### Emacs (lsp-mode)

```elisp
(use-package lsp-mode
  :hook (ruby-mode . lsp)
  :commands lsp)
```

### Sublime Text

Install the LSP and LSP-solargraph packages, then add to your Ruby syntax settings:

```json
{
  "lsp_format_on_save": true
}
```

## What's Documented

The stubs cover the full DragonRuby API surface:

| File | Covers |
|---|---|
| `args.rb` | `args` object — `state`, `inputs`, `outputs`, `audio`, `gtk`, `grid` |
| `outputs.rb` | `args.outputs` — sprites, solids, labels, lines, borders, primitives, sounds |
| `outputs_array.rb` | Array-form primitive shortcuts |
| `inputs.rb` | `args.inputs` — unified directional, last_active, touch |
| `keyboard.rb` | `args.inputs.keyboard` — key_down/held/up, all keys |
| `controller.rb` | `args.inputs.controller_one` through `controller_four` |
| `geometry.rb` | `Geometry.*` — intersect, distance, angle, vector, transform methods |
| `easing.rb` | `Easing.*` — ease, smooth_start/stop, spline |
| `layout.rb` | `Layout.*` — rect, point, rect_group, portrait?/landscape? |
| `numeric.rb` | Numeric extensions — lerp, clamp, remap, frame_index, elapsed?, vector_x/y |
| `gtk.rb` | `args.gtk` — file I/O, HTTP, window, cursor, platform?, serialize_state |
| `globals.rb` | Global helpers — `Kernel.tick_count`, `GTK.reset`, etc. |
| `constants.rb` | Engine constants |
| `phantom_types.rb` | Type definitions used internally by the stubs |
| `toplevel.rb` | Top-level `tick`, `boot`, `shutdown` signatures |

## Tips

- Re-run `solargraph config` if you add new `require` paths or restructure your project.
- If autocomplete stops working after a DragonRuby update, `git pull` the stubs repo — the community keeps them updated.
- The stubs are for editor tooling only; they are never loaded by DragonRuby at runtime.
- Add `.solargraph.yml` to `.gitignore` if team members use different editor setups, or commit it if everyone uses Solargraph. See the `.gitignore` section in `/dragonruby` for a complete template.
