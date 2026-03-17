# bdswitch.nvim

Neovim 插件：自动高亮 C/C++ 代码中的 GFlags 开关和动态开关，并以虚拟文本显示当前值。

参照 `bdswitch.vim` / `bsbdswitch.vim` 使用 Lua 重写，支持 ranker / mixer / advserver / imbsproxy 四种服务。

## 功能

- **自动检测项目类型**：根据 git remote 或工作目录自动识别服务
- **GFlags 高亮**：`FLAGS_xxx` / `gflags_xxx` 开启为绿色, 关闭为灰色
- **动态开关高亮**：动态配置中的开关名, 开启为蓝色, 关闭为灰色
- **虚拟文本**：在行尾显示开关状态 (`● ON` / `○ OFF`) 及非布尔值
- **悬停详情**：光标悬停查看开关来源、状态和值
- **开关列表**：QuickFix 列表展示所有开关
- **配置搜索**：在配置仓库中查找光标下标识符的定义

## 截图效果

```
// 代码中的效果示例:
if (FLAGS_enable_new_ranker) {   ◆ ● ON
    // ...
}
if (FLAGS_use_old_strategy) {    ◆ ○ OFF
    // ...
}
int timeout = FLAGS_request_timeout;  ◆ ⊙ 3000
```

## 安装

### lazy.nvim

```lua
{
  "your-name/bdswitch.nvim",
  ft = { "c", "cpp" },
  opts = {
    -- 配置仓库本地路径
    conf_root = vim.fn.expand("~/.config/bdswitch/asconf"),
    -- 是否显示虚拟文本
    show_virtual_text = true,
    -- 虚拟文本位置: "eol" | "inline"
    virt_text_pos = "eol",
  },
}
```

### packer.nvim

```lua
use {
  "your-name/bdswitch.nvim",
  ft = { "c", "cpp" },
  config = function()
    require("bdswitch").setup({
      conf_root = vim.fn.expand("~/.config/bdswitch/asconf"),
    })
  end,
}
```

### 手动安装

```bash
# 将插件目录放到 Neovim 的 runtimepath 中
git clone <repo> ~/.local/share/nvim/site/pack/plugins/start/bdswitch.nvim
```

## 配置

```lua
require("bdswitch").setup({
  -- 配置仓库根目录 (git clone 后的本地路径)
  conf_root = vim.fn.expand("~/.config/bdswitch/asconf"),

  -- 自动高亮 (打开 C/C++ 文件时)
  auto_highlight = true,

  -- 显示虚拟文本
  show_virtual_text = true,

  -- 虚拟文本位置
  virt_text_pos = "eol",

  -- 高亮颜色 (可自定义)
  highlights = {
    on_gflags  = { fg = "#98c379", bold = true },   -- 开启的 gflags
    off_gflags = { fg = "#5c6370", italic = true },  -- 关闭的 gflags
    on_dync    = { fg = "#61afef", bold = true },    -- 开启的动态开关
    off_dync   = { fg = "#5c6370", italic = true },  -- 关闭的动态开关
    virt_on    = { fg = "#98c379" },                  -- 虚拟文本: ON
    virt_off   = { fg = "#e06c75" },                  -- 虚拟文本: OFF
    virt_value = { fg = "#d19a66" },                  -- 虚拟文本: 值
  },

  -- 自定义服务 (可在此新增或覆盖)
  services = {
    my_service = {
      detect = function()
        return vim.fn.system("pwd"):match("my%-service") ~= nil
      end,
      gflags_file = "my_service/conf/gflags.conf",
      dync_file = "my_service/conf/switches.conf",
      conf_glob = "my_service/**",
      dync_format = "switches",  -- "switches" 或 "yacl"
    },
  },
})
```

## 命令

| 命令 | 说明 |
|------|------|
| `:BdSwitchRefresh` | 重新加载配置文件并刷新高亮 |
| `:BdSwitchHover` | 显示光标下开关标识符的详细信息 (浮窗) |
| `:BdSwitchList` | 在 QuickFix 列出所有开关及其状态/值 |
| `:BdSwitchSearch` | 在配置仓库中搜索光标下标识符 |
| `:BdSwitchToggleVirt` | 切换虚拟文本显示开/关 |
| `:BdSwitchUpdate` | 更新配置仓库 (git pull) |

## 推荐快捷键

```lua
vim.keymap.set("n", "<leader>bh", "<cmd>BdSwitchHover<cr>",      { desc = "开关详情" })
vim.keymap.set("n", "<leader>bl", "<cmd>BdSwitchList<cr>",       { desc = "开关列表" })
vim.keymap.set("n", "<leader>bs", "<cmd>BdSwitchSearch<cr>",     { desc = "搜索配置" })
vim.keymap.set("n", "<leader>br", "<cmd>BdSwitchRefresh<cr>",    { desc = "刷新开关" })
vim.keymap.set("n", "<leader>bv", "<cmd>BdSwitchToggleVirt<cr>", { desc = "切换虚拟文本" })
vim.keymap.set("n", "<leader>bu", "<cmd>BdSwitchUpdate<cr>",     { desc = "更新配置" })
```

## 工作原理

1. **服务检测**: 根据 `git remote -v` 或 `pwd` 自动识别当前项目属于哪个服务
2. **配置解析**: 读取对应服务的 `gflags.conf` 和动态开关配置文件
3. **GFlags 解析**: `--flag_name` → ON, `--noflag_name` → OFF, `--flag_name=value` → 带值
4. **动态开关解析**: `key: 1` → ON, `key: 0` → OFF, `key: value` → 带值
5. **高亮应用**: 使用 `matchadd()` 在窗口级别高亮所有匹配的标识符
6. **虚拟文本**: 使用 `nvim_buf_set_extmark()` 在行尾显示开关状态和值

## 与原 Vim 插件的区别

| 特性 | bdswitch.vim | bdswitch.nvim |
|------|-------------|---------------|
| 语言 | VimScript | Lua |
| 高亮方式 | `syn keyword` | `matchadd` + extmark |
| 值显示 | 无 | 虚拟文本行尾显示 |
| 悬停详情 | 无 | 浮窗显示 (hover) |
| 开关列表 | 无 | QuickFix 列表 |
| 自动检测 | 需要手动调用 | 打开 C/C++ 文件自动触发 |
| 防抖刷新 | 无 | TextChanged 500ms 防抖 |
| 扩展性 | 硬编码服务 | 可配置自定义服务 |

## License

MIT
