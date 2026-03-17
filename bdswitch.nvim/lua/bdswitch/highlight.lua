-- bdswitch.nvim 高亮模块
-- 使用 extmark 在 buffer 中高亮已知开关标识符并显示虚拟文本

local config = require("bdswitch.config")

local M = {}

-- Namespace
local NS = vim.api.nvim_create_namespace("bdswitch_hl")
local NS_VIRT = vim.api.nvim_create_namespace("bdswitch_virt")

-- 高亮组名称
M.HL_GROUPS = {
  on_gflags  = "BdSwitchOnGflags",
  off_gflags = "BdSwitchOffGflags",
  on_dync    = "BdSwitchOnDync",
  off_dync   = "BdSwitchOffDync",
  virt_on    = "BdSwitchVirtOn",
  virt_off   = "BdSwitchVirtOff",
  virt_value = "BdSwitchVirtValue",
}

--- 设置高亮组
function M.setup_highlights()
  local hl = config.options.highlights
  for key, group_name in pairs(M.HL_GROUPS) do
    local colors = hl[key]
    if colors then
      vim.api.nvim_set_hl(0, group_name, colors)
    end
  end
end

--- 清除指定 buffer 的所有 bdswitch 标记
--- @param bufnr number
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, NS_VIRT, 0, -1)
end

--- 判断给定标识符属于哪个高亮组
--- @param word string
--- @param info table { on, value, source }
--- @return string hl_group
local function get_hl_group(word, info)
  if info.source == "gflags" then
    return info.on and M.HL_GROUPS.on_gflags or M.HL_GROUPS.off_gflags
  else
    return info.on and M.HL_GROUPS.on_dync or M.HL_GROUPS.off_dync
  end
end

--- 生成虚拟文本片段
--- @param info table { on, value, source }
--- @return string text, string hl_group
local function make_virt_text(info)
  local val = info.value
  -- 非 bool 值: 显示实际值
  if val ~= "true" and val ~= "false" and val ~= "0" and val ~= "1" then
    return "⊙ " .. val, M.HL_GROUPS.virt_value
  end
  -- bool 值
  if info.on then
    return "● ON", M.HL_GROUPS.virt_on
  else
    return "○ OFF", M.HL_GROUPS.virt_off
  end
end

--- 扫描 buffer, 应用高亮 extmarks 和虚拟文本
--- 核心策略: 逐行扫描, 用 string.find 查找已知前缀标识符
--- @param bufnr number
--- @param parsed table 解析结果 (含 switch_map)
function M.apply(bufnr, parsed)
  if not parsed or not parsed.switch_map then
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- 清除旧标记
  M.clear(bufnr)

  local switch_map = parsed.switch_map
  local show_virt = config.options.show_virtual_text
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_count, false)

  for lnum, line in ipairs(lines) do
    local line_annotations = {} -- 每行最多显示的虚拟文本列表 (去重)
    local seen_base = {}        -- 用基础名去重 (防止 FLAGS_x 和 gflags_x 在同一行重复标注)
    local pos = 1

    while pos <= #line do
      -- 查找下一个标识符 (连续的字母数字下划线)
      local s, e = line:find("[%a_][%w_]*", pos)
      if not s then break end

      local word = line:sub(s, e)
      local info = switch_map[word]

      if info then
        -- 放置高亮 extmark
        local hl_group = get_hl_group(word, info)
        vim.api.nvim_buf_set_extmark(bufnr, NS, lnum - 1, s - 1, {
          end_col = e,
          hl_group = hl_group,
          priority = 200,
        })

        -- 收集虚拟文本 (按基础名去重)
        if show_virt then
          local base = info.display_name or word
          if not seen_base[base] then
            seen_base[base] = true
            local text, virt_hl = make_virt_text(info)
            line_annotations[#line_annotations + 1] = { " " .. text, virt_hl }
          end
        end
      end

      pos = e + 1
    end

    -- 添加行尾虚拟文本
    if show_virt and #line_annotations > 0 then
      local virt_text = { { "  ◆", M.HL_GROUPS.virt_value } }
      for _, ann in ipairs(line_annotations) do
        virt_text[#virt_text + 1] = ann
      end
      vim.api.nvim_buf_set_extmark(bufnr, NS_VIRT, lnum - 1, 0, {
        virt_text = virt_text,
        virt_text_pos = "eol",  -- 始终 eol, 避免 inline 造成混乱
        hl_mode = "combine",
      })
    end
  end
end

return M