# snacks-base.nvim

Minimal runtime extracted from
[folke/snacks.nvim](https://github.com/folke/snacks.nvim) for standalone split
packages such as
[`snacks-image.nvim`](https://github.com/epheien/snacks-image.nvim).

> [!CAUTION]
> `snacks-base.nvim` **cannot coexist** with the full `snacks.nvim` plugin in the
> same Neovim instance. Although this package does not assign `_G.Snacks`, both
> plugins provide the same `snacks.*` Lua modules. Runtimepath order would decide
> which implementation is loaded. Use this package only as a dependency of the
> split plugins, or use the full `snacks.nvim` plugin instead.

## Requirements

- Neovim >= 0.9.4.
- No external plugin dependency. Feature packages that depend on this runtime
  may have additional requirements.

## Installation

Most users should install this package through a split feature package. For
example, with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "epheien/snacks-image.nvim",
  dependencies = {
    {
      "epheien/snacks-base.nvim",
      main = "snacks",
      opts = {
        image = {},
      },
    },
  },
}
```

The extracted runtime is exposed through `require("snacks")` without creating a
global `Snacks` variable:

```lua
local Snacks = require("snacks")
Snacks.setup({
  image = {},
})
```

Extraction and update workflow notes are in
[docs/extraction.md](docs/extraction.md).
