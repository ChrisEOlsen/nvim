# Python LSP Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pyright LSP to the Neovim config so Python files get go-to-definition, hover, diagnostics, and completion — identical to the existing clangd setup for C/C++.

**Architecture:** Single additional `lspconfig.pyright.setup()` call in `init.lua` section 8, alongside the existing `clangd` block. Reuses the same `on_attach` pattern. No new plugins required — `nvim-lspconfig` is already installed.

**Tech Stack:** Neovim, nvim-lspconfig (already installed), pyright (external binary), uv (for installing pyright and managing venvs)

---

## File Map

| File | Change |
|------|--------|
| `init.lua` | Add `lspconfig.pyright.setup()` after the `lspconfig.clangd.setup()` block (around line 369); update LSP section title string in `show_keymaps()` (around line 771) |

---

### Task 1: Add pyright LSP setup

**Files:**
- Modify: `init.lua` (section 8, after `lspconfig.clangd.setup({...})` block, around line 378)

- [ ] **Step 1: Locate the clangd setup block**

Open `init.lua`. Find this block (around line 369):

```lua
lspconfig.clangd.setup({
  cmd = { "clangd", "--background-index" },
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)
  end,
})
```

- [ ] **Step 2: Add pyright setup immediately after the clangd block**

Insert this block directly after the closing `})` of `lspconfig.clangd.setup`:

```lua
lspconfig.pyright.setup({
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K',  vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)
  end,
  settings = {
    python = {
      venvPath = ".",
      venv = ".venv",
    },
  },
})
```

- [ ] **Step 3: Commit**

```bash
git add init.lua
git commit -m "feat(lsp): add pyright for Python LSP support"
```

---

### Task 2: Update keymap reference

**Files:**
- Modify: `init.lua` (`show_keymaps()` function, around line 771)

- [ ] **Step 1: Find the LSP section title in show_keymaps()**

Search for this string in `init.lua`:

```lua
{ title = "LSP  (active in C/C++ buffers)", maps = {
```

- [ ] **Step 2: Update the title**

Change it to:

```lua
{ title = "LSP  (active in C/C++ and Python buffers)", maps = {
```

- [ ] **Step 3: Commit**

```bash
git add init.lua
git commit -m "docs(keymaps): note LSP active in Python buffers"
```

---

### Task 3: Verify

- [ ] **Step 1: Install pyright if not already on PATH**

```bash
uv tool install pyright
# Verify:
pyright --version
```

Expected output: `pyright X.Y.Z`

- [ ] **Step 2: Reload Neovim config and open a Python file**

In Neovim:
```
:source $MYVIMRC
```
Or restart Neovim, then open any `.py` file.

- [ ] **Step 3: Confirm LSP attached**

In Neovim with a `.py` file open:
```
:LspInfo
```
Expected: pyright listed as attached to the current buffer.

- [ ] **Step 4: Confirm venv detection (if in a uv project)**

In a uv project directory (one with `.venv/`), open a `.py` file and run:
```
:LspInfo
```
Hover over an imported symbol with `K` — the hover doc should reflect the venv's packages, not just stdlib.

- [ ] **Step 5: Confirm keymap reference updated**

In Neovim:
```
:Keymaps
```
Expected: LSP section now reads `LSP  (active in C/C++ and Python buffers)`.
