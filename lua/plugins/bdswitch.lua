return {
    dir = "~/.config/nvim/bdswitch.nvim",
    ft = { "c", "cpp" },
    opts = {
        conf_root = vim.fn.expand("~/.config/bdswitch/asconf"),
        show_virtual_text = true,
        git_repo = "ssh://yangshuo21@icode.baidu.com:8235/baidu/ecom-release/im-prod",
        git_user = "yangshuo21",
        git_email = "yangshuo21@baidu.com",
    },
    keys = {
        { "<leader>bh", "<cmd>BdSwitchHover<cr>", desc = "开关详情" },
        { "<leader>bt", "<cmd>BdSwitchList<cr>", desc = "开关列表" },
        { "<leader>bs", "<cmd>BdSwitchSearch<cr>", desc = "搜索配置" },
        { "<leader>bu", "<cmd>BdSwitchRefresh<cr>", desc = "刷新开关" },
        { "<leader>bv", "<cmd>BdSwitchToggleVirt<cr>", desc = "切换虚拟文本" },
        { "<leader>bU", "<cmd>BdSwitchUpdate<cr>", desc = "更新配置仓库" },
    },
}
