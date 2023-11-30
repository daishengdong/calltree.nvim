local tree = require("calltree.tree")
local st = require("calltree.session_type")

local M = {}
local sessions = {}

local function make_buffer(session)
    local symbol = session.tree_root.symbol
    local current_window = vim.api.nvim_get_current_win()
    local current_layout = vim.api.nvim_get_current_tabpage()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    vim.cmd('botright new')

    local new_window = vim.api.nvim_get_current_win()
    new_window = new_window -- make lsp happy

    vim.cmd('vertical resize ' .. math.floor(vim.o.columns * 0.2))
    vim.cmd('resize ' .. math.floor(vim.o.lines * 0.2))
    vim.o.number = false
    vim.o.relativenumber = false

    local new_buffer = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(new_buffer, "__CALLTREE__." .. symbol.ctx .. "." .. st.stringify(session.type))
    vim.api.nvim_buf_set_option(new_buffer, "filetype", "calltree")
    vim.api.nvim_set_current_win(current_window)
    vim.api.nvim_win_set_cursor(0, cursor_pos)
    vim.api.nvim_set_current_tabpage(current_layout)

    return new_buffer, new_window
end

M.refresh_ui = function(session, entry_maker)
    if session.call_tree_buffer == nil then
        session.call_tree_buffer, session.call_tree_window = make_buffer(session)
    end

    session.line_nr_to_tree_node = {}
    local char_graph = tree.char_graph(session.tree_root, entry_maker, session.line_nr_to_tree_node)
    vim.api.nvim_buf_set_option(session.call_tree_buffer, "modifiable", true)
    vim.api.nvim_buf_set_lines(session.call_tree_buffer, 0, -1, false, char_graph)
    vim.api.nvim_buf_set_option(session.call_tree_buffer, "modifiable", false)
    vim.api.nvim_set_current_win(session.call_tree_window)
end

M.buf_to_session = function(buf)
    for _, session in pairs(sessions) do
        if session.call_tree_buffer == buf then
            return session
        end
    end

    return nil
end

M.close_session = function(key)
    local session = sessions[key]

    vim.api.nvim_buf_delete(session.call_tree_buffer, { force = true })

    sessions[key] = nil
end

M.show_session = function(session)
    vim.api.nvim_set_current_win(session.call_tree_window)
end

M.jump_to_session = function(key)
    M.show_session(sessions[key])
end

M.close_all_sessions = function()
    for _, session in pairs(sessions) do
        vim.api.nvim_buf_delete(session.call_tree_buffer, { force = true })
    end

    sessions = {}
end

M.keys_of_all_sessions = function()
    local keys = {}

    for key, _ in pairs(sessions) do
        table.insert(keys, key)
    end

    return keys
end

M.is_root_symbol = function(session, symbol)
    return session.tree_root.symbol == symbol
end

M.is_root_multi_defination = function(session)
    return #session.root_definations > 1
end

M.root_definations = function(session)
    return session.root_definations
end

local function find_session(type, the_symbol)
    for key, session in pairs(sessions) do
        if key.symbol.ctx == the_symbol.ctx and key.type == type then
            return session
        end
    end

    return nil
end

M.new_session = function(parser, type, symbol, root_definations)
    local existing_session = find_session(type, symbol)

    if existing_session ~= nil then
        return existing_session, true
    end

    local session = {}
    local key = {}

    session.tree_root = tree.make_node(symbol)
    session.type = type
    session.parser = parser
    if type == st.type.CALLER_TREE then
        session.find_func = parser.find_caller
    else
        session.find_func = parser.find_callee
    end
    session.root_definations = root_definations
    session.line_nr_to_tree_node = {}
    session.call_tree_window = nil
    session.call_tree_buffer = nil

    key.symbol = symbol
    key.type = type

    sessions[key] = session

    return session, false
end

M.add_symbol_to_root = function(session, symbol)
    local node = tree.make_node(symbol)

    tree.add_child(session.tree_root, node)
end

M.add_symbol_to_parent = function(session, parent, symbol)
    session = session -- make lsp happy
    local node = tree.make_node(symbol)

    tree.add_child(parent, node)
end

M.line_nr_to_tree_node = function(session, line_nr)
    if line_nr >= 1 and line_nr <= #session.line_nr_to_tree_node then
        return session.line_nr_to_tree_node[line_nr]
    end

    return nil
end

return M
