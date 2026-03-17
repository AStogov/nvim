-- bdswitch.nvim 解析器模块
-- 负责解析 gflags.conf 和动态开关配置文件

local config = require("bdswitch.config")

local M = {}

--- 读取文件内容, 返回行数组
--- @param filepath string 文件绝对路径
--- @return string[]|nil
local function read_lines(filepath)
  local path = vim.fn.expand(filepath)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local lines = {}
  for line in io.lines(path) do
    lines[#lines + 1] = line
  end
  return lines
end

--- 解析 gflags.conf
--- @param filepath string
--- @return table on_flags, table off_flags
function M.parse_gflags(filepath)
  local on_flags = {}
  local off_flags = {}

  local lines = read_lines(filepath)
  if not lines then
    return on_flags, off_flags
  end

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == "" or trimmed:sub(1, 1) == "#" then
      goto continue
    end

    -- 匹配 --noflag_name (关闭)
    -- 注意: Lua 的 %w 不含下划线, 必须用 [%w_]
    local off_name = trimmed:match("^%-%-no([%w_]+)")
    if off_name then
      off_flags[#off_flags + 1] = {
        name = off_name,
        value = "false",
        on = false,
        raw = trimmed,
      }
      goto continue
    end

    -- 匹配 --flag_name 或 --flag_name=value (开启)
    local on_name, eq_val = trimmed:match("^%-%-([%w_]+)(=?.*)")
    if on_name then
      local value = "true"
      if eq_val and eq_val:sub(1, 1) == "=" then
        value = eq_val:sub(2)
      end
      on_flags[#on_flags + 1] = {
        name = on_name,
        value = value,
        on = true,
        raw = trimmed,
      }
    end

    ::continue::
  end

  return on_flags, off_flags
end

--- 解析 switches.conf / yacl 格式 (key: value 或 key:value)
--- @param filepath string
--- @param skip_erb boolean 是否跳过 ERB 模板标记
--- @return table on_dync, table off_dync
function M.parse_dync(filepath, skip_erb)
  local on_dync = {}
  local off_dync = {}

  local lines = read_lines(filepath)
  if not lines then
    return on_dync, off_dync
  end

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == "" or trimmed:sub(1, 1) == "#" then
      goto continue
    end
    if skip_erb and trimmed:match("^<%%-?") then
      goto continue
    end

    -- 匹配 DYNC_xxx : value 或 DYNC_xxx:value
    local name, value = trimmed:match("^([%w_]+)%s*:%s*(.+)")
    if name and value then
      value = vim.trim(value)
      local is_on = (value == "1" or value:lower() == "true")
      local is_off = (value == "0" or value:lower() == "false")

      local entry = {
        name = name,
        value = value,
        on = is_on,
        raw = trimmed,
      }

      if is_off then
        off_dync[#off_dync + 1] = entry
      else
        -- ON 或非 bool 值都归入 on
        if not is_on then entry.on = true end
        on_dync[#on_dync + 1] = entry
      end
    end

    ::continue::
  end

  return on_dync, off_dync
end

--- 主解析入口: 根据服务配置解析所有开关
--- 构建精确的查找表: 只包含代码中实际使用的带前缀标识符
--- @param service_config table 服务配置
--- @return table result
function M.parse_service(service_config)
  local result = {
    on_gflags = {},
    off_gflags = {},
    on_dync = {},
    off_dync = {},
    --- 精确查找表: 标识符 -> { on, value, source, display_name }
    --- 只包含 FLAGS_xxx, gflags_xxx, DYNC_xxx 这些代码中实际出现的前缀标识符
    switch_map = {},
  }

  -- 解析所有 gflags 文件 (支持列表)
  local gflags_files = service_config.gflags_files or { service_config.gflags_file }
  local seen_gflag = {} -- 按名字去重, 前面的文件优先
  for _, rel_path in ipairs(gflags_files) do
    if rel_path then
      local abs_path = config.get_conf_path(rel_path)
      local on, off = M.parse_gflags(abs_path)
      for _, flag in ipairs(on) do
        if not seen_gflag[flag.name] then
          seen_gflag[flag.name] = true
          result.on_gflags[#result.on_gflags + 1] = flag
        end
      end
      for _, flag in ipairs(off) do
        if not seen_gflag[flag.name] then
          seen_gflag[flag.name] = true
          result.off_gflags[#result.off_gflags + 1] = flag
        end
      end
    end
  end

  -- 解析所有动态开关文件 (支持列表)
  local dync_files = service_config.dync_files or { service_config.dync_file }
  local skip_erb = (service_config.dync_format == "yacl")
  local seen_dync = {}
  for _, rel_path in ipairs(dync_files) do
    if rel_path then
      local abs_path = config.get_conf_path(rel_path)
      local on, off = M.parse_dync(abs_path, skip_erb)
      for _, dync in ipairs(on) do
        if not seen_dync[dync.name] then
          seen_dync[dync.name] = true
          result.on_dync[#result.on_dync + 1] = dync
        end
      end
      for _, dync in ipairs(off) do
        if not seen_dync[dync.name] then
          seen_dync[dync.name] = true
          result.off_dync[#result.off_dync + 1] = dync
        end
      end
    end
  end

  -- 构建查找表: 只放带前缀的标识符
  -- gflags: FLAGS_xxx 和 gflags_xxx (只在 gflags.conf 中有)
  for _, flag in ipairs(result.on_gflags) do
    local info = { on = true, value = flag.value, source = "gflags", display_name = flag.name }
    result.switch_map["FLAGS_" .. flag.name] = info
    result.switch_map["gflags_" .. flag.name] = info
  end
  for _, flag in ipairs(result.off_gflags) do
    local info = { on = false, value = "false", source = "gflags", display_name = flag.name }
    result.switch_map["FLAGS_" .. flag.name] = info
    result.switch_map["gflags_" .. flag.name] = info
  end

  -- 动态开关: DYNC_xxx (只在 switches.conf 中有)
  for _, dync in ipairs(result.on_dync) do
    result.switch_map[dync.name] = {
      on = dync.on,
      value = dync.value,
      source = "dync",
      display_name = dync.name,
    }
  end
  for _, dync in ipairs(result.off_dync) do
    result.switch_map[dync.name] = {
      on = false,
      value = dync.value,
      source = "dync",
      display_name = dync.name,
    }
  end

  return result
end

return M