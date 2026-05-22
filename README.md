# AI-Native Monk Config

AI-first Neovim for C/C++. Privacy-focused, minimal, fast.

## AI Features

Powered by [OpenRouter](https://openrouter.ai). `data_collection: deny` enforced.

- **AutoEdit (`<leader>ae`)**: Edit entire file/selection with diff preview. AI sees full file context.
- **Autogen (`<leader>ag`)**: Insert code at cursor. Includes local `#include` headers in context.
- **Explain (`<leader>ai`)**: Selection analysis in orange-bordered panel. Syntax + Purpose.
- **Model Picker (`<leader>ac`)**: Switch between favorite models via panel.
- **History (`<leader>ah`)**: View previous AI responses for current file.
- **Config**: `:Aiconfig <model> [provider]` and `:AddModel <id>`.

## Keymaps

| Key | Action |
|-----|--------|
| `<leader>ae` | **AI AutoEdit** (Normal: file, Visual: selection) |
| `<leader>ag` | **AI Autogen** (Insert at cursor) |
| `<leader>ai` | **AI Explain** (Visual selection) |
| `<leader>ac` | **AI Model Picker** |
| `<leader>ah` | **AI History** |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>gs` | Git status |
| `<leader>gd` | Git diff split |
| `<leader>tm` | Toggle theme (Dark/Light/Trans) |
| `<leader>z` | Zen mode |
| `gd` | Go to definition |
| `K` | Hover docs |
| `<leader>f` | LSP format |

## Requirements

- Neovim ≥ 0.9, `curl`, `clangd`
- `export OPENROUTER_API_KEY="sk-or-..."`
