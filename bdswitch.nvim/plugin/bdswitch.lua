-- bdswitch.nvim 插件入口 (自动加载)
-- 在 plugin/ 目录下, Neovim 启动时自动执行

if vim.g.loaded_bdswitch then
  return
end
vim.g.loaded_bdswitch = true

-- 延迟加载: 只有打开 C/C++ 文件时才初始化
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  once = true,
  callback = function()
    -- 如果用户没有手动调用 setup, 则使用默认配置
    local bdswitch = require("bdswitch")
    if not bdswitch._initialized then
      bdswitch.setup()
    end
  end,
})
