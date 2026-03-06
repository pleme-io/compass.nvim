# compass.nvim

Fast workspace-aware project navigation for Neovim.

## Overview

compass.nvim scans workspace roots for projects, ranks them by recency using fuzzy matching (nucleo-matcher), and provides a floating picker UI for quick project switching. The core logic is written in Rust as a native Neovim module (via nvim-oxi), with a Lua frontend for UI and configuration.

## Installation

With Nix (recommended):

```nix
# As a flake input
inputs.compass-nvim.url = "github:pleme-io/compass.nvim";

# Use the overlay
pkgs.vimPlugins.compass-nvim
```

With lazy.nvim:

```lua
{ "pleme-io/compass.nvim", build = "nix build" }
```

## Usage

```lua
require("compass").setup({
  roots = { "~/code" },   -- directories to scan for projects
  max_depth = 4,           -- max directory depth
  restore_last_file = true, -- reopen last edited file on project switch
})

-- Open the project picker
require("compass").open()

-- Keybinding example
vim.keymap.set("n", "<leader>fp", require("compass").open)
```

## Project Structure

```
lua/compass/
  init.lua   -- Plugin setup, config, Lua API
  ui.lua     -- Floating window picker
src/
  lib.rs     -- Rust core: project scanning, fuzzy filtering, recency tracking
```

## License

MIT
