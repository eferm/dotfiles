-- Tree-sitter grammar for Ghostty configuration files
-- https://github.com/bezhermoso/tree-sitter-ghostty

---@module 'lazy'
---@type LazySpec
return {
  'bezhermoso/tree-sitter-ghostty',
  build = 'make nvim_install',
}
