-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    io.write("\27[6 q")  -- 设置为竖线光标
  end,
})
