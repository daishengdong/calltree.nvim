local utils = require("calltree.utils")
local sm = require("calltree.session_manager")
local st = require("calltree.session_type")
local cscope = require("calltree.cscope")
local lsp = require("calltree.lsp")
local debug = require("calltree.debug")

local M = {}

-- Configurable options
M.opts = {
    prefix = "<leader>o", -- keep consistent with cscope_maps

    -- brief: only shows a symbol's name
    -- detailed: shows just more details
    -- detailed_paths: shows filename and line number
    tree_style = "brief", -- alternatives: detailed, detailed_paths
}

local function entry_maker(symbol)
    if M.opts.tree_style == "brief" then
        return symbol.ctx
    elseif M.opts.tree_style == "detailed" then
        return symbol.ctx .. " [" .. symbol.text .. "] +" .. symbol.lnum
    elseif M.opts.tree_style == "detailed_paths" then
        return symbol.ctx .. " [" .. symbol.filename .. ":" .. symbol.lnum .. "]"
    end
end

local function cword()
    local word
    local visual = vim.fn.mode() == "v"

    if visual == true then
        local saved_reg = vim.fn.getreg "v"
        vim.cmd [[noautocmd sil norm "vy]]
        local sele = vim.fn.getreg "v"
        vim.fn.setreg("v", saved_reg)
        word = sele
    else
        word = vim.fn.expand "<cword>"
    end

    return word
end

local function call_tree_helper(parser, session_type)
    local symbol_name = cword()
    if symbol_name == nil then
        return
    end

    local definations = parser.find_defination(symbol_name)
    if #definations == 0 then
        vim.notify("no legal defination for " .. symbol_name)
        return
    end

    local session, is_existing = sm.new_session(parser, session_type, definations[1], definations)

    if is_existing then
        sm.show_session(session)
        return
    end

    for _, symbol in pairs(session.find_func(nil, symbol_name)) do
        sm.add_symbol_to_root(session, symbol)
    end

    sm.refresh_ui(session, entry_maker)
end

local function CallerTreeCscope()
    call_tree_helper(cscope, st.type.CALLER_TREE)
end

local function CalleeTreeCscope()
    call_tree_helper(cscope, st.type.CALLEE_TREE)
end

local function CallerTreeLsp()
    call_tree_helper(lsp, st.type.CALLER_TREE)
end

local function CalleeTreeLsp()
    call_tree_helper(lsp, st.type.CALLEE_TREE)
end

local function CallTreeClose()
    local keys = sm.keys_of_all_sessions()

    if next(keys) == nil then
        return
    end

    vim.ui.select(keys, {
        prompt = "select session to close",
        format_item = function(key)
            return key.symbol.ctx .. " [" .. st.stringify(key.type) .. "] +" .. key.symbol.lnum
        end,
    }, function (choice)
            if choice then
                sm.close_session(choice)
            end
        end)
end

local function CallTreeCloseAll()
    sm.close_all_sessions()
end

local function CallTreeSwitch()
    local keys = sm.keys_of_all_sessions()

    if next(keys) == nil then
        return
    end

    vim.ui.select(keys, {
        prompt = "select session to switch",
        format_item = function(key)
            return key.symbol.ctx .. " [" .. st.stringify(key.type) .. "] +" .. key.symbol.lnum
        end,
    }, function (choice)
            if choice then
                sm.jump_to_session(choice)
            end
        end)
end

local function user_command()
    vim.api.nvim_create_user_command("CallerTreeCscope", function()
        CallerTreeCscope()
    end, {})
    vim.api.nvim_create_user_command("CalleeTreeCscope", function()
        CalleeTreeCscope()
    end, {})
    vim.api.nvim_create_user_command("CallerTreeLsp", function()
        CallerTreeLsp()
    end, {})
    vim.api.nvim_create_user_command("CalleeTreeLsp", function()
        CalleeTreeLsp()
    end, {})
    vim.api.nvim_create_user_command("CallTreeClose", function()
        CallTreeClose()
    end, {})
    vim.api.nvim_create_user_command("CallTreeCloseAll", function()
        CallTreeCloseAll()
    end, {})
    vim.api.nvim_create_user_command("CallTreeSwitch", function()
        CallTreeSwitch()
    end, {})
end

local function refresh_tree()
    local current_buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]
    local session = sm.buf_to_session(current_buf)

    if session == nil then
        return
    end

    local tree_node = sm.line_nr_to_tree_node(session, cursor_line)

    if tree_node == nil then
        vim.notify("invalid tree_node with line_nr: " .. tostring(cursor_line))
        return
    end

    if #tree_node.children ~= 0 then
        return
    end

    for _, symbol in pairs(session.find_func(tree_node.symbol, tree_node.symbol.ctx)) do
        sm.add_symbol_to_parent(session, tree_node, symbol)
    end

    sm.refresh_ui(session, entry_maker)
end

local function relative_path(path)
    local cwd = vim.loop.fs_realpath(".")
    return string.gsub(path, cwd .. "/", "")
end

local function jump2symbol()
    local current_buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]
    local previous_window = utils.get_previous_window()
    local session = sm.buf_to_session(current_buf)

    if session == nil then
        vim.notify("invalid session for current_buf")
        return
    end

    local symbol = sm.line_nr_to_tree_node(session, cursor_line).symbol
    if symbol == nil then
        vim.notify("invalid symbol with line_nr: " .. tostring(cursor_line))
        return
    end

    if sm.is_root_symbol(session, symbol) and sm.is_root_multi_defination(session) then
        local symbols = sm.root_definations(session)

        vim.ui.select(symbols, {
            prompt = "select defination to jump",
            format_item = function(the_symbol)
                return the_symbol.ctx .. " [" .. st.stringify(session.type) .. "] ".. relative_path(the_symbol.filename) .. " +" .. the_symbol.lnum
            end,
        }, function (choice)
                if choice then
                    utils.symbol_open(previous_window, choice)
                end
            end)
        return
    end

    utils.symbol_open(previous_window, symbol)
end

local function auto_command()
    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "__CALLTREE__*",
        callback = function()
            vim.keymap.set("n", "r", refresh_tree,
                { silent = true, noremap = true, buffer = true })

            vim.keymap.set("n", "<Tab>", refresh_tree,
                { silent = true, noremap = true, buffer = true })

            vim.keymap.set("n", "<CR>", jump2symbol,
                { silent = true, noremap = true, buffer = true })
        end
    })
end

local function init_keymaps(prefix)
    local ok, wk = pcall(require, "which-key")
    if ok then
        wk.register({ [prefix] = { name = "+cscope" } })
    end
    vim.keymap.set("n", prefix .. "r", function() CallerTreeCscope() end, { desc = "Caller tree(cscope)" })
    vim.keymap.set("n", prefix .. "R", function() CalleeTreeCscope() end, { desc = "Callee tree(cscope)" })
    vim.keymap.set("n", prefix .. "l", function() CallerTreeLsp() end, { desc = "Caller tree(lsp)" })
    vim.keymap.set("n", prefix .. "L", function() CalleeTreeLsp() end, { desc = "Callee tree(lsp)" })
    vim.keymap.set("n", prefix .. "x", function() CallTreeClose() end, { desc = "Close call tree" })
    vim.keymap.set("n", prefix .. "X", function() CallTreeCloseAll() end, { desc = "Close all call trees" })
    vim.keymap.set("n", prefix .. "w", function() CallTreeSwitch() end, { desc = "Switch call tree" })
end

M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)

    user_command()
    auto_command()
    init_keymaps(M.opts.prefix)

    debug.setup()
end

return M
