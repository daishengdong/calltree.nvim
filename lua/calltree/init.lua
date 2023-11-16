local session_mgr = require("calltree.session_manager")
local st = require("calltree.session_type")
local cscope = require("calltree.cscope")
local debug = require("calltree.debug")

local M = {}

-- Configurable options
M.opts = {
    prefix = "<leader>o", -- keep consistent with cscope_maps

    -- brief style only shows a symbol's name
    -- detailed style shows .. just more details
    -- see entry_maker()
    tree_style = "brief", -- alternatives: detailed
}

local function entry_maker(symbol)
    if M.opts.tree_style == "brief" then
        return symbol.ctx
    elseif M.opts.tree_style == "detailed" then
        return symbol.ctx .. " [" .. symbol.text .. "] +" .. symbol.lnum
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

local function call_tree_helper(session_type)
    local symbol_name = cword()
    if symbol_name == nil then
        return
    end

    local definations = cscope.find_defination(symbol_name)
    if #definations == 0 then
        vim.notify("no legal defination for " .. symbol_name)
        return
    end

    local session, is_existing = session_mgr.new_session(session_type, definations[1], definations)

    if is_existing then
        session_mgr.show_session(session)
        return
    end

    local find_func
    if session.type == st.type.CALLER_TREE then
        find_func = cscope.find_caller
    else
        find_func = cscope.find_callee
    end

    for _, symbol in pairs(find_func(symbol_name)) do
        session_mgr.add_symbol_to_root(session, symbol)
    end

    session_mgr.refresh_ui(session, entry_maker)
end

local function CallerTree()
    call_tree_helper(st.type.CALLER_TREE)
end

local function CalleeTree()
    call_tree_helper(st.type.CALLEE_TREE)
end

local function CallTreeClose()
    local keys = session_mgr.keys_of_all_sessions()

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
                session_mgr.close_session(choice)
            end
        end)
end

local function CallTreeCloseAll()
    session_mgr.close_all_sessions()
end

local function CallTreeSwitch()
    local keys = session_mgr.keys_of_all_sessions()

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
                session_mgr.jump_to_session(choice)
            end
        end)
end

local function user_command()
    vim.api.nvim_create_user_command("CallerTree", function()
        CallerTree()
    end, {})
    vim.api.nvim_create_user_command("CalleeTree", function()
        CalleeTree()
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
    local session = session_mgr.buf_to_session(current_buf)

    if session == nil then
        return
    end

    local tree_node = session_mgr.line_nr_to_tree_node(session, cursor_line)

    if tree_node == nil then
        vim.notify("invalid tree_node with line_nr: " .. tostring(cursor_line))
        return
    end

    if #tree_node.children ~= 0 then
        return
    end

    local symbol_name = tree_node.symbol.ctx
    local find_func
    if session.type == st.type.CALLER_TREE then
        find_func = cscope.find_caller
    else
        find_func = cscope.find_callee
    end

    for _, symbol in pairs(find_func(symbol_name)) do
        session_mgr.add_symbol_to_parent(session, tree_node, symbol)
    end

    session_mgr.refresh_ui(session, entry_maker)
end

local function get_previous_window()
    vim.cmd(":wincmd p")
    local previous_window = vim.api.nvim_get_current_win()
    vim.cmd(":wincmd p")
    return previous_window
end

local function file_open(window, filename, lnum)
    -- vim.cmd(":wincmd p")
    vim.api.nvim_set_current_win(window)
    vim.cmd("e " .. filename)
    vim.api.nvim_win_set_cursor(0, { tonumber(lnum), 0 })
end

local function symbol_open(window, symbol)
    local filename = symbol.filename
    local lnum = symbol.lnum

    file_open(window, filename, lnum)
end

local function relative_path(path)
    local cwd = vim.loop.fs_realpath(".")
    return string.gsub(path, cwd .. "/", "")
end

local function jump2symbol()
    local current_buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]
    local previous_window = get_previous_window()
    local session = session_mgr.buf_to_session(current_buf)
    local symbol = session_mgr.line_nr_to_tree_node(session, cursor_line).symbol

    if session == nil or symbol == nil then
        vim.notify("invalid symbol with line_nr: " .. tostring(cursor_line))
        return
    end

    if session_mgr.is_root_symbol(session, symbol) and session_mgr.is_root_multi_defination(session) then
        local symbols = session_mgr.root_definations(session)

        vim.ui.select(symbols, {
            prompt = "select defination to jump",
            format_item = function(the_symbol)
                return the_symbol.ctx .. " [" .. st.stringify(session.type) .. "] ".. relative_path(the_symbol.filename) .. " +" .. the_symbol.lnum
            end,
        }, function (choice)
                if choice then
                    symbol_open(previous_window, choice)
                end
            end)
        return
    end

    symbol_open(previous_window, symbol)
end

local function auto_command()
    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "__CALL_TREE__*",
        callback = function()
            vim.keymap.set("n", "r", refresh_tree,
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
    vim.keymap.set("n", prefix .. "r", function() CallerTree() end, { desc = "caller tree" })
    vim.keymap.set("n", prefix .. "R", function() CalleeTree() end, { desc = "callee tree" })
    vim.keymap.set("n", prefix .. "x", function() CallTreeClose() end, { desc = "close call tree" })
    vim.keymap.set("n", prefix .. "X", function() CallTreeCloseAll() end, { desc = "close all call trees" })
    vim.keymap.set("n", prefix .. "w", function() CallTreeSwitch() end, { desc = "switch call tree" })
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