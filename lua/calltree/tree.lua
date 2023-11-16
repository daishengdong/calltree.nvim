local M = {}

M.make_node = function(symbol)
    local node = {}

    node.symbol = symbol
    node.children = {}
    node.parent = node

    return node
end

M.add_child = function(parent, child)
    table.insert(parent.children, child)
    child.parent = parent
end

local function do_char_graph(node, is_root, entry_maker, prefix, is_last_child, line_nr, line_nr_to_tree_node)
    local lines = {}
    local nr_descendants = 1

    if is_root then
        table.insert(lines, prefix .. entry_maker(node.symbol))
    else
        local line = ''

        if is_last_child then
            line = '└── '
        else
            line = '├── '
        end

        table.insert(lines, prefix .. line .. entry_maker(node.symbol))
    end

    line_nr_to_tree_node[line_nr] = node

    for i, child in ipairs(node.children) do
        local line = ''
        local is_last = false

        if is_root then
            if is_last_child then
                line = ''
            else
                line = '│ '
            end
        else
            if is_last_child then
                line = '    '
            else
                line = '│   '
            end
        end

        if i == #node.children then
            is_last = true
        end

        local new_prefix = prefix .. line
        local slines, snr_descendants = do_char_graph(child,false, entry_maker, new_prefix, is_last, line_nr + nr_descendants, line_nr_to_tree_node)
        nr_descendants = nr_descendants + snr_descendants
        for _, svalue in pairs(slines) do
            table.insert(lines, svalue)
        end
    end

    return lines, nr_descendants
end

M.char_graph = function(root, entry_maker, line_nr_to_tree_node)
    return do_char_graph(root, true, entry_maker, '', true, 1, line_nr_to_tree_node)
end

return M
