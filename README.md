# calltree.nvim

Disclaimer: I straight-up copied much of the code in this plugin from [cscope_maps.nvim](https://github.com/dhananjaylatkar/cscope_maps.nvim), even this README. I want to give credits to the author of cscope_maps.nvim for writing awesome code and thank him for using the MIT licence.

Support the `Source Insight` style reference dependency tree.

Has a dependency of cscope_maps.nvim plugin.

[calltree.nvim.webm](https://github.com/daishengdong/calltree.nvim/assets/4813738/3033497d-54d7-4370-b6f5-63e28b69490d)

## Features

- Opens results in another bottom window.
- Has [which-key.nvim](https://github.com/folke/which-key.nvim) hints.

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

    -- brief style only shows a symbol's name
    -- detailed style shows .. just more details
    -- see entry_maker()
    tree_style = "brief", -- alternatives: detailed
}
```

## Keymaps

### Default Keymaps

`<prefix>` can be configured using `prefix` option. Default value for prefix
is `<leader>o`.

| Keymaps           | Description                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `<prefix>r`       | draw relation tree of the callers of the token under cursor                                   |
| `<prefix>R`       | draw relation tree of the callees of the token under cursor                                   |
| `<prefix>x`       | close the relation tree of a certain token with a select prompt                               |
| `<prefix>X`       | close all the relation trees                                                                  |
| `<prefix>w`       | switch to the view of relation tree of a certain token with a select prompt                   |
| enter             | `enter` key pressing in the relation tree jumps to the token in the certain line              |
| r                 | `r` key pressing in the relation tree expands the relation of the token in the certain line   |
| tab               | `tab` key pressing in the relation tree expands the relation of the token in the certain line |

#### Using `:Cscope` command

| Command           | Description                                                         |
| ----------------- | ------------------------------------------------------------------- |
| :CallerTree       | draw relation tree of the callers of the token under cursor         |
| :CalleeTree       | draw relation tree of the callees of the token under cursor         |
| :CallTreeClose    | close the relation tree of a certain token with a select prompt     |
| :CallTreeCloseAll | close all the relation trees                                        |
| :CallTreeSwitch   | switch to the relation tree of a certain token with a select prompt |

## known issues

- When opening multiple call trees, the layout of the display windows becomes messed up.

I am a beginner in Neovim plugin development and not very proficient in window layout management. I would greatly appreciate your help in resolving this issue.
