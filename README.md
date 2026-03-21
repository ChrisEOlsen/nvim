# nvim — Systems Engineer Monk Config

A minimal, fast Neovim setup for C/C++ development with AI-assisted coding. No bloat. Comments in grey, everything else plain.

---

## Requirements

- Neovim ≥ 0.9
- `git`, `gcc` / `g++`, `clangd`, `curl`
- An [OpenRouter](https://openrouter.ai) account and API key

---

## Installation

```bash
git clone git@github.com:ChrisEOlsen/nvim.git ~/.config/nvim
```

Add your OpenRouter API key to `~/.bashrc`:

```bash
export OPENROUTER_API_KEY="sk-or-..."
```

Open Neovim — Lazy.nvim will bootstrap itself and install plugins on first launch.

---

## Theme

Cycles through four modes with `<Space>tm`:

| Mode | Description |
|------|-------------|
| Dark | GitHub Dark, opaque |
| Light | GitHub Light, opaque |
| Dark Transparent | GitHub Dark, transparent background |
| Light Transparent | GitHub Light, transparent background |

Theme choice persists across sessions.

---

## Keymaps

**Leader key: `Space`**

| Key | Action |
|-----|--------|
| `<leader>ff` | Fuzzy find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Browse open buffers |
| `<leader>gs` | Git status |
| `<leader>gd` | Git diff split |
| `<leader>z` | Zen mode |
| `<leader>tm` | Toggle theme |
| `<leader>e` | Show diagnostics float |
| `<leader>f` | Format buffer (LSP) |
| `gd` | Go to definition |
| `K` | Hover docs |
| `<Esc>` | Clear search highlight |
| `iq` / `aq` | Smart quote text objects |

---

## AI Features

Powered by [OpenRouter](https://openrouter.ai). Requests are filtered to providers that do not use your data for training (`data_collection: deny`).

Default model: `qwen/qwen3-coder`. Change it any time with `:Aiconfig`.

### `:Autogen` — Generate code at cursor

Sends the current file (plus any local `#include "..."` headers) as context, then inserts the generated code after the cursor line with a smooth line-by-line animation.

```
:Autogen write a function that returns the max of two integers
```

Or use the keymap — press `<leader>ag` in normal mode, type your prompt, hit Enter.

### `:Explain` — Explain selected code

Visually select a block of code, then press `<leader>ai`. A floating window with a rounded orange border appears with a two-part response:

1. **SYNTAX** — what language constructs are used
2. **PURPOSE** — what the code does in context

Press `q` or `<Esc>` to close the window.

Both commands show an `AI: thinking ▓▓▓▓▓▓▓▓▓▓▓▓` indicator in the command line while waiting for a response.

### `:Aiconfig` — Change model or provider

```
:Aiconfig google/gemini-2.5-flash
:Aiconfig qwen/qwen3-coder Google Vertex
:Aiconfig qwen/qwen3-coder any
```

- First argument: model name (any OpenRouter model ID)
- Optional second argument: lock to a specific provider, or `any` to remove the lock
- Config persists across sessions in `~/.local/share/nvim/ai_config.json`

### System prompts

Edit the prompt files directly to tune AI behaviour:

```
~/.config/nvim/ai_prompts/autogen.txt
~/.config/nvim/ai_prompts/explain.txt
```

---

## C/C++ Commands

| Command | Description |
|---------|-------------|
| `:MainArgs` | Insert `main(int argc, char *argv[])` boilerplate |
| `:MainVoid` | Insert `main(void)` boilerplate |
| `:AddProto <sig>` | Add function prototype before `main` and stub at end of file |
| `:CommentBox <name> <desc>` | Insert a K.N. King style comment block |
| `:Compile` | Compile the current file with `gcc` or `g++` |
| `:MyCommands` | List all custom commands |

---

## Plugins

| Plugin | Role |
|--------|------|
| [lazy.nvim](https://github.com/folke/lazy.nvim) | Package manager |
| [github-nvim-theme](https://github.com/projekt0n/github-nvim-theme) | Theme |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP (clangd) |
| [fzf-lua](https://github.com/ibhagwan/fzf-lua) | Fuzzy finder |
| [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) | Autocompletion |
| [nvim-autopairs](https://github.com/windwp/nvim-autopairs) | Auto bracket/quote pairs |
| [zen-mode.nvim](https://github.com/folke/zen-mode.nvim) | Distraction-free writing |
| [vim-fugitive](https://github.com/tpope/vim-fugitive) | Git integration |
