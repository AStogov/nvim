require('lspconfig').clangd.setup{
  cmd = {
    "clangd",
    "--background-index",
    "--cache-dir=" .. vim.fn.getcwd() .. "/.cache/clangd",
  },
}
