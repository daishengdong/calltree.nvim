# calltree.nvim

Disclaimer: I straight-up copied much of the code in this plugin from [cscope_maps.nvim](https://github.com/dhananjaylatkar/cscope_maps.nvim) and [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), even this README. I want to give credits to the authors of cscope_maps.nvim and telescope.nvim for writing awesome code and thank them for using the MIT licence.

Support the `Source Insight` style reference dependency tree.

Has a dependency of cscope_maps.nvim plugin(if use cscope as parser).

[calltree.nvim.webm](https://github.com/daishengdong/calltree.nvim/assets/4813738/3033497d-54d7-4370-b6f5-63e28b69490d)

## Features

- Opens results in another bottom window.
- Has [which-key.nvim](https://github.com/folke/which-key.nvim) hints.
- Supporting both LSP and cscope as parser for the invocation relationship.

## Installation

Install the plugin with your preferred package manager.
Following example uses [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "daishengdong/calltree.nvim",
  dependencies = {
    "dhananjaylatkar/cscope_maps.nvim",
    "folke/which-key.nvim", -- optional [for whichkey hints]
  },
  opts = {
    -- USE EMPTY FOR DEFAULT OPTIONS
    -- DEFAULTS ARE LISTED BELOW
  },
}
```

## Configuration

_calltree_ comes with following defaults:

```lua
{
    prefix = "<leader>o", -- keep consistent with cscope_maps

    -- brief: only shows a symbol's name
    -- detailed: shows just more details
    -- detailed_paths: shows filename and line number
    tree_style = "brief", -- alternatives: detailed, detailed_paths
}
```

## Keymaps

### Default Keymaps

`<prefix>` can be configured using `prefix` option. Default value for prefix
is `<leader>o`.

| Keymaps           | Description                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `<prefix>r`       | draw relation tree of the callers of the token under cursor, based on `cscope`                |
| `<prefix>R`       | draw relation tree of the callees of the token under cursor, based on `cscope`                |
| `<prefix>l`       | draw relation tree of the callers of the token under cursor, based on `LSP`                   |
| `<prefix>L`       | draw relation tree of the callees of the token under cursor, based on `LSP`                   |
| `<prefix>x`       | close the relation tree of a certain token with a select prompt                               |
| `<prefix>X`       | close all the relation trees                                                                  |
| `<prefix>w`       | switch to the view of relation tree of a certain token with a select prompt                   |
| enter             | `enter` key pressing in the relation tree jumps to the token in the certain line              |
| r                 | `r` key pressing in the relation tree expands the relation of the token in the certain line   |
| tab               | `tab` key pressing in the relation tree expands the relation of the token in the certain line |

#### Using `:Cscope` command

| Command           | Description                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------- |
| :CallerTreeCscope | draw relation tree of the callers of the token under cursor, based on `cscope`                |
| :CalleeTreeCscope | draw relation tree of the callees of the token under cursor, based on `cscope`                |
| :CallerTreeLsp    | draw relation tree of the callers of the token under cursor, based on `LSP`                   |
| :CalleeTreeLsp    | draw relation tree of the callees of the token under cursor, based on `LSP`                   |
| :CallTreeClose    | close the relation tree of a certain token with a select prompt                               |
| :CallTreeCloseAll | close all the relation trees                                                                  |
| :CallTreeSwitch   | switch to the relation tree of a certain token with a select prompt                           |

## known issues

- When opening multiple call trees, the layout of the display windows becomes messed up. I am a beginner in Neovim plugin development and not very proficient in window layout management. I would greatly appreciate your help in resolving this issue.
- In regard to using LSP as parser, I have only tested the C, Python, and Lua scenarios. It functions correctly in the C and Python scenarios, but due to significant differences in the parsing result patterns of Lua's LSP, it is unable to work properly(possibly as a future task).
- When using LSP as parser, the jumping behavior of symbols is different from that of cscope. As a parser, cscope's jumping behavior is consistent with `Source Insight`. The reason for this discrepancy is that the parsing results of LSP and cscope are different.
- When using LSP as a parser, there might be a slight lag. This is partly because of the less elegant handling approach of calltree for asynchronous calls, refer to `syn_call()` in lua/calltree/lsp.lua.
- Because when making a request to LSP, it is necessary to have a valid buffer and window as parameters (refer to calls() in lua/calltree/lsp.lua), it is required to open the symbols of the call tree nodes for expansion. To ensure that the display of the neovim window remains unchanged after expansion, some window restore operations have been implemented (refer to lua/calltree/lsp.lua). If the window before jumping to the calltree window is not an editing window (such as neo-tree), it will cause a display bug. So, it is best to close windows like neo-tree before invoking the calltree.
