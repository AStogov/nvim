-- bdswitch.nvim 浮窗/悬停/列表模块

local config = require("bdswitch.config")

local M = {}

--- 在 switch_map 中查找光标下的单词
--- 支持多种前缀: FLAGS_xxx, gflags_xxx, DYNC_xxx, 以及裸名
--- @param switch_map table
--- @param word string
--- @return table|nil info, string matched_key
local function lookup_switch(switch_map, word)
  -- 1. 直接查找
  if switch_map[word] then
    return switch_map[word], word
  end

  -- 2. 如果是裸名, 尝试加前缀
  local prefixes = { "FLAGS_", "gflags_", "DYNC_" }
  for _, prefix in ipairs(prefixes) do
    local key = prefix .. word
    if switch_map[key] then
      return switch_map[key], key
    end
  end

  -- 3. 如果是带前缀的, 尝试去掉前缀换其他前缀
  local stripped = word:match("^FLAGS_(.+)")
      or word:match("^gflags_(.+)")
      or word:match("^DYNC_(.+)")
  if stripped then
    for _, prefix in ipairs(prefixes) do
      local key = prefix .. stripped
      if switch_map[key] then
        return switch_map[key], key
      end
    end
  end

  return nil, word
end

--- 在光标所在单词上显示开关信息浮窗
--- @param parsed table 解析结果
function M.show_hover(parsed)
  if not parsed or not parsed.switch_map then
    vim.notify("[bdswitch] 未加载开关数据", vim.log.levels.WARN)
    return
  end

  local word = vim.fn.expand("<cword>")
  local info, key = lookup_switch(parsed.switch_map, word)

  if not info then
    vim.notify("[bdswitch] '" .. word .. "' 不是已知的开关", vim.log.levels.INFO)
    return
  end

  local status_icon = info.on and "✅" or "❌"
  local status_text = info.on and "ON (开启)" or "OFF (关闭)"

  local lines = {
    "## " .. key,
    "",
    "**状态:** " .. status_icon .. " " .. status_text,
    "**值:**   `" .. tostring(info.value) .. "`",
    "**来源:** " .. (info.source == "gflags" and "GFlags 配置" or "动态开关"),
  }

  vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    focusable = true,
    focus = false,
    max_width = 60,
    max_height = 10,
  })
end

--- 列出所有开关 (QuickFix)
--- @param parsed table 解析结果
function M.list_switches(parsed)
  if not parsed or not parsed.switch_map then
    vim.notify("[bdswitch] 未加载开关数据", vim.log.levels.WARN)
    return
  end

  local items = {}
  local seen = {}

  for _, flag in ipairs(parsed.on_gflags or {}) do
    if not seen[flag.name] then
      seen[flag.name] = true
      items[#items + 1] = string.format("● [ON ] [gflags] FLAGS_%-40s = %s", flag.name, flag.value)
    end
  end
  for _, flag in ipairs(parsed.off_gflags or {}) do
    if not seen[flag.name] then
      seen[flag.name] = true
      items[#items + 1] = string.format("○ [OFF] [gflags] FLAGS_%-40s = %s", flag.name, flag.value)
    end
  end
  for _, dync in ipairs(parsed.on_dync or {}) do
    if not seen[dync.name] then
      seen[dync.name] = true
      items[#items + 1] = string.format("● [ON ] [dync  ] %-46s = %s", dync.name, dync.value)
    end
  end
  for _, dync in ipairs(parsed.off_dync or {}) do
    if not seen[dync.name] then
      seen[dync.name] = true
      items[#items + 1] = string.format("○ [OFF] [dync  ] %-46s = %s", dync.name, dync.value)
    end
  end

  if #items == 0 then
    vim.notify("[bdswitch] 没有找到开关", vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, " ", {
    title = "BdSwitch - 所有开关列表",
    lines = items,
  })
  vim.cmd("copen")
end

--- 搜索当前光标下单词在配置文件中的定义
--- @param parsed table 解析结果
--- @param service_config table 服务配置
--- 根据标识符类型确定搜索范围
--- FLAGS_xxx / gflags_xxx → 只在 gflags 文件中搜索
--- DYNC_xxx             → 只在 dync 文件中搜索
--- 其他                  → 所有 conf_globs
local function get_search_globs(word, service_config)
  local globs = {}

  if word:match("^FLAGS_") or word:match("^gflags_") then
    -- 只在 gflags 文件中搜索
    local files = service_config.gflags_files or { service_config.gflags_file }
    for _, f in ipairs(files) do
      if f then globs[#globs + 1] = config.get_conf_path(f) end
    end
  elseif word:match("^DYNC_") then
    -- 只在 dync 文件中搜索
    local files = service_config.dync_files or { service_config.dync_file }
    for _, f in ipairs(files) do
      if f then globs[#globs + 1] = config.get_conf_path(f) end
    end
  else
    -- 搜索所有配置目录
    local conf_globs = service_config.conf_globs or { service_config.conf_glob }
    for _, g in ipairs(conf_globs) do
      if g then globs[#globs + 1] = config.get_conf_path(g) end
    end
  end

  return globs
end

--- 搜索当前光标下单词在配置文件中的定义
--- FLAGS_xxx → 只在 gflags.conf 中搜
--- DYNC_xxx  → 只在 switches.conf 中搜
--- @param parsed table 解析结果
--- @param service_config table 服务配置
function M.search_conf(parsed, service_config)
  if not service_config then
    vim.notify("[bdswitch] 未检测到服务类型", vim.log.levels.WARN)
    return
  end

  local word = vim.fn.expand("<cword>")

  -- 确定搜索名和搜索范围
  local search_word = word
  local stripped = word:match("^FLAGS_(.+)") or word:match("^gflags_(.+)")
  if stripped then
    search_word = stripped  -- 在 gflags.conf 中, 开关名没有 FLAGS_ 前缀
  end

  local globs = get_search_globs(word, service_config)
  local glob_str = table.concat(globs, " ")

  -- 直接搜索
  local ok, _ = pcall(vim.cmd, 'noautocmd vimgrep /\\<' .. search_word .. '\\>/gj ' .. glob_str)
  if ok and #vim.fn.getqflist() > 0 then
    vim.cmd("copen")
    return
  end

  -- 如果失败, 用原始 word 再试一次 (用原名搜索所有 conf)
  if search_word ~= word then
    ok, _ = pcall(vim.cmd, 'noautocmd vimgrep /\\<' .. word .. '\\>/gj ' .. glob_str)
    if ok and #vim.fn.getqflist() > 0 then
      vim.cmd("copen")
      return
    end
  end

  -- 最后手段: 在全部 conf_globs 中搜索
  local all_globs = service_config.conf_globs or { service_config.conf_glob }
  local all_str = ""
  for _, g in ipairs(all_globs) do
    if g then all_str = all_str .. " " .. config.get_conf_path(g) end
  end
  ok, _ = pcall(vim.cmd, 'noautocmd vimgrep /\\<' .. word .. '\\>/gj ' .. all_str)
  if ok and #vim.fn.getqflist() > 0 then
    vim.cmd("copen")
    return
  end

  -- 尝试通过 REGCFG 宏找到配置名
  local regcfg_pattern = 'REGCFG.*"\\(\\w\\+\\)"\\s*,\\s*\\n*\\s*&*' .. word .. '.*'
  local search_dirs = "common/** src/** include/** strategy/**"
  ok, _ = pcall(vim.cmd, 'noautocmd vimgrep /' .. regcfg_pattern .. '/gj ' .. search_dirs)
  if ok then
    local qf = vim.fn.getqflist()
    if #qf == 1 then
      local confname_regex = 'REGCFG.*"([%w_]+)"'
      local conf_name = qf[1].text:match(confname_regex)
      if conf_name then
        pcall(vim.cmd, 'noautocmd vimgrep /\\<' .. conf_name .. '\\>/gj ' .. all_str)
        if #vim.fn.getqflist() > 0 then
          vim.cmd("copen")
          return
        end
      end
    elseif #qf > 1 then
      vim.cmd("copen")
      return
    end
  end

  vim.notify("[bdswitch] 未找到 '" .. word .. "' 的配置", vim.log.levels.INFO)
end

return M