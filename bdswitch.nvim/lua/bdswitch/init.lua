-- bdswitch.nvim 主入口
-- 用于 Neovim 的动态开关自动高亮及值展示插件
-- 参照 bdswitch.vim / bsbdswitch.vim 重写

local config = require("bdswitch.config")
local parser = require("bdswitch.parser")
local highlight = require("bdswitch.highlight")
local ui = require("bdswitch.ui")

local M = {}

-- 当前解析结果缓存
M._parsed = nil
M._service_name = nil
M._service_config = nil
M._initialized = false

--- 初始化插件
--- @param opts table|nil 用户配置
function M.setup(opts)
  config.setup(opts)
  highlight.setup_highlights()

  -- 检测服务
  M._service_name, M._service_config = config.detect_service()

  if M._service_name and M._service_config then
    -- 解析配置
    M._parsed = parser.parse_service(M._service_config)

    local on_count = #(M._parsed.on_gflags or {}) + #(M._parsed.on_dync or {})
    local off_count = #(M._parsed.off_gflags or {}) + #(M._parsed.off_dync or {})
    vim.notify(
      string.format("[bdswitch] 检测到服务: %s | 开关: %d ON, %d OFF",
        M._service_name, on_count, off_count),
      vim.log.levels.INFO
    )
  end

  -- 注册自动命令
  M._setup_autocmds()
  -- 注册用户命令
  M._setup_commands()

  M._initialized = true
end

--- 刷新: 重新加载配置并应用高亮
function M.refresh()
  if not M._service_config then
    M._service_name, M._service_config = config.detect_service()
  end

  if not M._service_config then
    vim.notify("[bdswitch] 未检测到服务类型 (ranker/mixer/advserver/imbsproxy)", vim.log.levels.WARN)
    return
  end

  M._parsed = parser.parse_service(M._service_config)
  M.apply()

  local on_count = #(M._parsed.on_gflags or {}) + #(M._parsed.on_dync or {})
  local off_count = #(M._parsed.off_gflags or {}) + #(M._parsed.off_dync or {})
  vim.notify(
    string.format("[bdswitch] 已刷新 | 服务: %s | 开关: %d ON, %d OFF",
      M._service_name, on_count, off_count),
    vim.log.levels.INFO
  )
end

--- 应用高亮和虚拟文本到当前 buffer
function M.apply()
  if not M._parsed then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  highlight.apply(bufnr, M._parsed)
end

--- 切换虚拟文本显示
function M.toggle_virtual_text()
  config.options.show_virtual_text = not config.options.show_virtual_text
  -- 重新应用 (会根据 show_virtual_text 决定是否显示)
  M.apply()
  local state = config.options.show_virtual_text and "开启" or "关闭"
  vim.notify("[bdswitch] 虚拟文本: " .. state, vim.log.levels.INFO)
end

--- 更新配置仓库 (首次自动 clone, 之后 git pull)
function M.update_conf()
  local conf_root = config.options.conf_root
  local git_repo = config.options.git_repo
  local git_user = config.options.git_user
  local git_email = config.options.git_email

  if vim.fn.isdirectory(conf_root .. "/.git") == 1 then
    -- 已存在, 执行 git pull
    vim.notify("[bdswitch] 正在更新配置仓库 (git pull)...", vim.log.levels.INFO)
    vim.fn.jobstart({ "git", "-C", conf_root, "pull" }, {
      on_exit = function(_, code)
        vim.schedule(function()
          if code == 0 then
            vim.notify("[bdswitch] 配置仓库更新成功, 正在刷新...", vim.log.levels.INFO)
            M.refresh()
          else
            vim.notify("[bdswitch] git pull 失败 (exit code: " .. code .. ")", vim.log.levels.ERROR)
          end
        end)
      end,
    })
  elseif git_repo ~= "" then
    -- 首次克隆
    if git_user == "" then
      vim.ui.input({ prompt = "iCode 用户名: " }, function(input)
        if input and input ~= "" then
          config.options.git_user = input
          config.options.git_email = input .. "@baidu.com"
          -- 替换 repo URL 中的用户名
          local repo = git_repo:gsub("yourname@", input .. "@")
          M._do_clone(repo, conf_root, input, input .. "@baidu.com")
        end
      end)
    else
      local repo = git_repo:gsub("yourname@", git_user .. "@")
      M._do_clone(repo, conf_root, git_user, git_email)
    end
  else
    vim.notify("[bdswitch] 请在 setup() 中配置 git_repo, 或手动 clone 到: " .. conf_root, vim.log.levels.ERROR)
  end
end

--- 执行 git clone
function M._do_clone(repo, dest, user, email)
  -- 确保父目录存在
  local parent = vim.fn.fnamemodify(dest, ":h")
  vim.fn.mkdir(parent, "p")

  vim.notify("[bdswitch] 正在克隆配置仓库...\n" .. repo, vim.log.levels.INFO)
  vim.fn.jobstart({ "git", "clone", repo, dest }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("[bdswitch] git clone 失败 (exit code: " .. code .. ")", vim.log.levels.ERROR)
          return
        end

        -- 配置 git user
        if user and user ~= "" then
          vim.fn.system({ "git", "-C", dest, "config", "user.name", user })
          vim.fn.system({ "git", "-C", dest, "config", "user.email", email or (user .. "@baidu.com") })
        end

        -- 安装 commit-msg hook (iCode 需要)
        local hook_cmd = string.format(
          "scp -p -P 8235 %s@icode.baidu.com:hooks/commit-msg %s/.git/hooks/ 2>/dev/null",
          user, dest
        )
        vim.fn.system(hook_cmd)

        vim.notify("[bdswitch] 配置仓库克隆成功! 正在刷新...", vim.log.levels.INFO)
        M.refresh()
      end)
    end,
  })
end

--- 悬停查看开关详情
function M.hover()
  ui.show_hover(M._parsed)
end

--- 列出所有开关
function M.list()
  ui.list_switches(M._parsed)
end

--- 搜索配置
function M.search()
  ui.search_conf(M._parsed, M._service_config)
end

--- 设置自动命令
function M._setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("BdSwitch", { clear = true })

  -- 进入 C/C++ buffer 时自动高亮
  if config.options.auto_highlight then
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
      group = augroup,
      pattern = { "*.cpp", "*.cc", "*.c", "*.h", "*.hpp", "*.cxx" },
      callback = function()
        if M._parsed then
          -- 延迟一点执行, 让语法高亮先加载
          vim.defer_fn(function()
            M.apply()
          end, 100)
        end
      end,
    })

    -- 文件保存后重新扫描
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = augroup,
      pattern = { "*.cpp", "*.cc", "*.c", "*.h", "*.hpp", "*.cxx" },
      callback = function()
        if M._parsed then
          local bufnr = vim.api.nvim_get_current_buf()
          highlight.apply(bufnr, M._parsed)
        end
      end,
    })

    -- 文本改变时防抖刷新
    local timer = nil
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = augroup,
      pattern = { "*.cpp", "*.cc", "*.c", "*.h", "*.hpp", "*.cxx" },
      callback = function()
        if M._parsed then
          if timer then
            timer:stop()
          end
          timer = vim.defer_fn(function()
            local bufnr = vim.api.nvim_get_current_buf()
            highlight.apply(bufnr, M._parsed)
            timer = nil
          end, 500)
        end
      end,
    })
  end
end

--- 设置用户命令
function M._setup_commands()
  vim.api.nvim_create_user_command("BdSwitchRefresh", function()
    M.refresh()
  end, { desc = "刷新开关配置并重新高亮" })

  vim.api.nvim_create_user_command("BdSwitchHover", function()
    M.hover()
  end, { desc = "显示光标下开关的详细信息" })

  vim.api.nvim_create_user_command("BdSwitchList", function()
    M.list()
  end, { desc = "列出所有开关及其状态" })

  vim.api.nvim_create_user_command("BdSwitchSearch", function()
    M.search()
  end, { desc = "在配置文件中搜索光标下的标识符" })

  vim.api.nvim_create_user_command("BdSwitchToggleVirt", function()
    M.toggle_virtual_text()
  end, { desc = "切换虚拟文本显示" })

  vim.api.nvim_create_user_command("BdSwitchUpdate", function()
    M.update_conf()
  end, { desc = "更新配置仓库 (git pull)" })
end

return M
