# snacks-base.nvim

Minimal runtime extracted from snacks.nvim for standalone split packages.

The runtime is exposed through `require("snacks")` without assigning
`_G.Snacks`. It still uses the original `snacks.*` Lua module namespace and is
therefore intended to be used mutually exclusively with the full snacks.nvim
package.

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
