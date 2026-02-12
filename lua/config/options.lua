-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- set guicursor=n-v-c-sm:ver25,i-ci-ve:ver25,r-cr-o:ver25

vim.opt.guicursor = "a:ver100"
vim.o.fileencodings = "utf-8,gbk,big5,cp936,gb18030,euc-jp,euc-kr,latin1,ucs-bom,ucs"
vim.g.autoformat = false
vim.opt_local.expandtab = true
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt.tabstop = 4 -- 一个 Tab 显示为 4 个空格
vim.opt.shiftwidth = 4 -- 自动缩进宽度
vim.opt.softtabstop = 4 -- Tab/退格时的空格数
vim.opt.expandtab = true -- 将 Tab 转为空格
