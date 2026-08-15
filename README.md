# snacks-base.nvim

Minimal runtime extracted from snacks.nvim for standalone split packages.

This package keeps the original `Snacks` namespace and is intended to be used
mutually exclusively with the full snacks.nvim package.

Extraction and update workflow notes are in [docs/extraction.md](docs/extraction.md).

Example with lazy.nvim:

```lua
{
  dir = "/path/to/snacks-base.nvim",
  main = "snacks",
  opts = {
    image = {},
  },
}
```
