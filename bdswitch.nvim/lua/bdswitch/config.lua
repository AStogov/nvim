-- bdswitch.nvim 配置模块
-- 定义各服务的配置路径和检测逻辑

local M = {}

--- 获取当前 buffer 所在的 git 仓库目录
--- 先用 buffer 所在目录, 回退到 CWD
local function get_buf_git_dir()
  local buf_dir = vim.fn.expand("%:p:h")
  if buf_dir and buf_dir ~= "" and vim.fn.isdirectory(buf_dir) == 1 then
    local root = vim.fn.systemlist(
      "cd " .. vim.fn.shellescape(buf_dir) .. " && git rev-parse --show-toplevel 2>/dev/null"
    )
    if root and #root > 0 and root[1] ~= "" then
      return root[1]
    end
  end
  -- 回退: 用 CWD
  local root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
  if root and #root > 0 and root[1] ~= "" then
    return root[1]
  end
  return nil
end

--- 工具函数: git remote 中是否包含指定关键字 (plain text, 不是 Lua pattern)
local function detect_by_git_remote(keyword)
  return function()
    local git_dir = get_buf_git_dir()
    if not git_dir then return false end
    local cmd = string.format(
      "git -C %s remote -v 2>/dev/null | grep fetch | grep '%s'",
      vim.fn.shellescape(git_dir), keyword
    )
    local ok = vim.fn.system(cmd)
    return ok and #vim.trim(ok) > 0
  end
end

--- 工具函数: buffer 路径中是否包含指定关键字
local function detect_by_buf_path(keyword)
  return function()
    local buf_path = vim.fn.expand("%:p")
    return buf_path and buf_path:find(keyword, 1, true) ~= nil
  end
end

-- 默认配置
M.defaults = {
  -- 配置仓库根目录
  conf_root = vim.fn.expand("~/.config/bdswitch/asconf"),
  -- git 克隆信息 (首次 clone 时使用)
  git_repo = "ssh://yourname@icode.baidu.com:8235/baidu/ecom-release/im-prod",
  git_user = "",   -- icode 用户名
  git_email = "",  -- 邮箱
  -- 是否自动高亮
  auto_highlight = true,
  -- 是否显示虚拟文本 (值)
  show_virtual_text = true,
  -- 虚拟文本位置: "eol"
  virt_text_pos = "eol",
  -- 高亮颜色
  highlights = {
    on_gflags  = { fg = "#98c379", bold = true },
    off_gflags = { fg = "#5c6370", italic = true },
    on_dync    = { fg = "#61afef", bold = true },
    off_dync   = { fg = "#5c6370", italic = true },
    virt_on    = { fg = "#98c379" },
    virt_off   = { fg = "#e06c75" },
    virt_value = { fg = "#d19a66" },
  },
  -- 服务配置
  -- gflags_files: gflags 配置文件列表 (FLAGS_xxx 只在这些文件中匹配)
  -- dync_files:   动态开关文件列表   (DYNC_xxx 只在这些文件中匹配)
  -- dync_format:  "switches" (key: value) 或 "yacl" (带 ERB 模板)
  -- conf_globs:   搜索配置时的 glob 列表
  services = {
    ranker = {
      detect = detect_by_git_remote("im-as/ranker"),
      gflags_files = { "ranker/conf/gflags.conf" },
      dync_files   = { "ranker/conf/switches.conf" },
      dync_format  = "switches",
      conf_globs   = { "ranker/conf/**" },
    },
    mixer = {
      detect = detect_by_git_remote("im-as/mixer"),
      gflags_files = { "mixer/conf/gflags.conf" },
      dync_files   = { "mixer/conf/switches.conf" },
      dync_format  = "switches",
      conf_globs   = { "mixer/conf/**" },
    },
    auction = {
      detect = detect_by_git_remote("im-as/auction"),
      gflags_files = {
        "ranker/conf/auction/gflags.conf",
        "ranker/conf/gflags.conf",
      },
      dync_files = {
        "ranker/conf/auction/auction_switches.conf",
        "ranker/conf/switches.conf",
      },
      dync_format = "switches",
      conf_globs  = { "ranker/conf/auction/**", "ranker/conf/**" },
    },
    gabriel = {
      detect = detect_by_git_remote("im-as/gabriel"),
      gflags_files = { "mixer/conf/gflags.conf" },
      dync_files   = { "mixer/conf/switches.conf" },
      dync_format  = "switches",
      conf_globs   = { "mixer/conf/**" },
    },
    advserver = {
      detect = detect_by_buf_path("adv-server"),
      gflags_files = { "advserver/conf/gflags.conf" },
      dync_files   = { "advserver/conf/diffgen/adquery/adquery_yacl.conf.erb" },
      dync_format  = "yacl",
      conf_globs   = { "advserver/conf/**" },
    },
    imbsproxy = {
      detect = detect_by_buf_path("imbs-proxy"),
      gflags_files = { "imbsproxy/conf/gflags.conf" },
      dync_files   = { "imbsproxy/conf/diffgen/imbs_proxy_yacl.conf.erb" },
      dync_format  = "yacl",
      conf_globs   = { "imbsproxy/conf/**" },
    },
  },
}

-- 当前用户配置 (setup 后合并)
M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

--- 检测当前项目所属服务
--- @return string|nil service_name, table|nil service_config
function M.detect_service()
  for name, svc in pairs(M.options.services) do
    if svc.detect and svc.detect() then
      return name, svc
    end
  end
  return nil, nil
end

--- 获取某个服务配置文件的绝对路径
function M.get_conf_path(relative)
  return M.options.conf_root .. "/" .. relative
end

return M
