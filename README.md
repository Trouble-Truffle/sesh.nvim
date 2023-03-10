<!--toc:start-->

- [Sesh.nvim](#seshnvim)
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Telescope Integration](#telescope-integration)
    - [Enabling](#enabling)
    - [Bindings](#bindings)
  - [Exposed Functions](#exposed-functions)
    - [sesh.save()](#seshsave)
    - [sesh.delete()](#seshdelete)
    - [sesh.load()](#seshload)
    - [sesh.switch()](#seshswitch)
    - [sesh.read_sessions_info()](#seshreadsessionsinfo)
    - [sesh.opened_session()](#seshopenedsession)
    - [sesh.read_opts()](#seshreadopts)
    - [sesh.list()](#seshlist)
    - [sesh.update_sessions_info()](#seshupdatesessionsinfo)
- [Special Thanks to](#special-thanks-to)
<!--toc:end-->

# Sesh.nvim

![Usage](./data/Sample.gif)

## Installation

Telescope is optional but is recommended

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
  {"Trouble-Truffle/sesh.nvim", dependencies = {"nvim-telescope/telescope.nvim"}}
```

[packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
  use {"Trouble-Truffle/sesh.nvim", requires = {"nvim-telescope/telescope.nvim"}}"}
```

## Configuration

```lua
  require("sesh").setup({
      autosave = {
        enable = false -- Autosave on writes and exit
        autocmds = {} -- Save on additional autocmds
      }
      autoload = false -- Load a session if `cwd` matches
      autoswitch {
        enable = false -- Close buffers in current session before loading
        exclude_ft = {} -- Disable certain buffers from being closed
      }
      sessions_info = vim.fn.stdpath('data') .. "/session-info.json"
        -- Location of the json file containing session infos
      session_path = vim.fn.stdpath('data') .. "/sesions"
        -- Location of stored session files
      post_load_hook = function() end 
        -- Run functions on load
      exclude_name = {} -- Automatically remove buffers with this name, see ## Exclude Name
      -- ^ USE THIS OPTION WITH CAUTION
    })
```

## Exclude Name

the `exclude_name` option automatically removes buffers of that name from created session files.

### Caveats

- This option is highly dangerous as it simply removes all lines containing names listed. When a name consisting of a vim command i.e. `bufadd`, `edit`, etc. is passed then loading them may be fail or be broken.

- This option does not close the windows of the deleted buffers. When loading you may see multiple blank windows.

- This is a hacky solution but it can be used to automatically close all empty buffers on load
```lua 
post_load_hook = function()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if ("" == vim.api.nvim_buf_get_option(buf, "filetype")) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end
```

- When using [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) and [symbols-outline.nvim](https://github.com/simrat39/symbols-outline.nvim) you can use 
```lua
exclude_name = {'NvimTree_1', 'OUTLINE'}
```
as well as the `post_load_hook` defined above.

## Telescope Integration

![Telescope](./data/Telescope.png)

### Enabling

```lua
  require("telescope").load_extension('sesh')
```

From there you can call `Telescope sesh` or via lua `require('telescope').extensions.sesh.sesh()`

### Bindings

| mode | bind    | action                             |
| ---- | ------- | ---------------------------------- |
| `n`  | `x`     | calls `sesh.delete()` on selection |
| `i`  | `<A-x>` | calls `sesh.delete()` on selection |
| `*`  | `<CR>`  | calls `sesh.load()` on selection   |

## Exposed Functions

### sesh.save()

Saves a session from the current working directory. When not in a session it Calls `vim.ui.input` to get the name. Otherwise it launches a y/n prompt

### sesh.delete()

Deletes the provided session. If called without arguments it launches `vim.ui.select` to choose.

### sesh.load()

Loads the provided session. If called without arguments it launches `vim.ui.select` to choose. If `autoswitch` is enabled it calls upon `sesh.switch()`

### sesh.switch()

Simillar to `sesh.load` but instead it requires an argument. Switching closes all current buffers before sourcing a session.

### sesh.read_sessions_info()

Returns the contents of `session-info.json`

### sesh.opened_session()

Returns the current sourced session

### sesh.read_opts()

Returns current configuration

### sesh.list()

Returns a list of all sessions in `session_path`

### sesh.update_sessions_info()

Updates `session-info.json`

# Special Thanks to

- [leap.nvim](https://github.com/ggandor/leap.nvim) for their `make.py`
