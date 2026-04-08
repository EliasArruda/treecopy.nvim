---

# 🌳 treecopy.nvim

A high-performance, feature-rich Neovim plugin designed to capture and copy your project's file structure. Whether you're providing context to an **AI (ChatGPT, Claude)**, documenting a project, or opening GitHub issues, `treecopy.nvim` makes it seamless.

> **Now with 100% Lua fallback – no external dependencies required (but supported for speed)!**

---

## ✨ Features

- 📋 **One-Click Copy:** Instantly send your project tree to the system clipboard.
- 🎨 **Multi-Format Support:** Export as **Markdown**, **JSON**, **YAML**, or **Plain Text**.
- 🛠️ **Interactive Selector:** Choose your format on the fly with a beautiful `vim.ui` menu.
- 🤖 **AI-Optimized:** Perfectly formatted structures for Large Language Models.
- 🌳 **Smart Engine:** Uses the native `tree` command for speed, with a **built-in Lua engine** fallback for systems without it.
- ⚙️ **Highly Configurable:** Filter hidden files, ignore specific patterns (node_modules, .git), and set recursion limits.
- ⌨️ **Which-Key Ready:** Automatic integration with icons for a better DX.

---

## 🚀 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "EliasArruda/treecopy.nvim",
  keys = {
    { "<leader>fq", mode = "n", desc = "🌲 Copy File Tree" },
  },
  opts = {
    -- Your custom configuration here (optional)
    output_format = "markdown",
    show_hidden = false,
  },
  config = function(_, opts)
    require("treecopy").setup(opts)
  end,
}
```

---

## ⌨️ Usage

### Interactive Selection (Recommended)
Press your configured keymap (default: `<leader>fq`). An interactive menu will appear allowing you to select the desired output format.

### Commands
| Command | Description |
| :--- | :--- |
| `:TreeCopy` | Copies the tree using the default format in your config. |
| `:TreeCopy json` | Force copy as **Pretty JSON**. |
| `:TreeCopy yaml` | Force copy as **YAML**. |
| `:TreeCopy plain` | Force copy as **Plain Text**. |
| `:TreeCopy markdown` | Force copy as **Markdown**. |

---

## ⚙️ Configuration

You can pass these options to the `setup()` function:

```lua
require("treecopy").setup({
  -- Patterns to ignore
  ignore = { ".git", "node_modules", "__pycache__", ".next", "dist", ".DS_Store" },
  
  -- Title used in Markdown format header
  title = "📁 Project File Tree",
  
  -- Keymap to trigger the interactive selector
  keymap = "<leader>fq",
  
  -- nil = no limit, or set a number (e.g. 3)
  max_depth = nil, 
  
  -- Default format: "markdown", "json", "yaml", "plain"
  output_format = "markdown",
  
  -- Show files starting with a dot
  show_hidden = false,
  
  -- UI Icons
  icons = {
    success = "✅",
    error = "❌",
    copy = "📋",
  },
  
  -- Integration with which-key.nvim
  which_key = {
    icon = "🌲",
    description = "Copy File Tree (Select Format)",
  },
})
```

---

## 🔍 Technical Details

### Why two engines?
1. **Native Engine (`tree` binary):** If you have the `tree` utility installed, the plugin uses it for maximum performance on large repositories.
2. **Lua Engine:** If `tree` is not found, the plugin automatically switches to a custom **built-in Lua engine** using `uv` (libuv) bindings. You get the same result without installing anything extra.

### Format Examples

#### 📝 Markdown (Default)
```markdown
# 📁 Project File Tree
**Root:** `/home/user/project`
```text
├── 📁 src
│   ├── 📄 main.lua
│   └── 📄 utils.lua
└── 📄 README.md
```

#### 📦 JSON (Pretty Printed)
```json
{
  "name": "project",
  "type": "directory",
  "contents": [
    { "name": "src", "type": "directory", "contents": [...] }
  ]
}
```

---

## ⚡️ Prerequisites

While the plugin works out of the box using Lua, for the best performance in massive projects, we recommend installing the `tree` utility:

- **macOS:** `brew install tree`
- **Linux:** `sudo apt install tree`
- **Windows:** Pre-installed or `choco install tree`

*Ensure you have a clipboard manager working with Neovim (`xclip`, `wl-clipboard`, or `pbcopy`).*

---

## 📄 License
MIT © [EliasArruda](https://github.com/EliasArruda)
