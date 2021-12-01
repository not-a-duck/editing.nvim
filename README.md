# Editing

The _raison d'être_ of this plugin is mostly my own degeneracy.

In short:

* Add position marks [\*] with `:AddPosition`.
* Display a window to display all position marks,
  `:ToggleWindow`.
* Apply the macro in register `q` starting from all marked positions with
  `:MultiMacro`.
* Clear all previously marked positions with `:ClearPositions`.

[\*] not actual nvim marks.

The `:AddPosition` and `:ToggleWindow` could also be used to simply stare at
the marked lines, if you are into weird !@#$ like that.

## Nota bene

Currently, the default behaviour of `:MultiMacro` is to run the macro one by
one in reverse sorted order. This is not a perfect solution and may produce
some unexpected outcomes when the macro moves around too much.

# Movement

By default, nvim supports slight horizontal jumps with `ci"`. I quite liked the
idea of immediate jumps, so I extended the range and the possibilities of the
jumps by adding some common enough movements. I have no idea whether the Lua
variant of these are any better than what I used to have in my old vim-style
keymaps, but it was fun making them and these do not mess with the search
history nor the jumplist.

In my personal init.vim I have the following keymaps, which allow me to quickly
jump to the next match, and edit whatever is inside.

```vim
nn <silent> c( :MoveNextParenthesis<CR>"_ci(
nn <silent> c) :MoveNextParenthesis<CR>"_ci)
nn <silent> c[ :MoveNextBracket<CR>"_ci[
nn <silent> c] :MoveNextBracket<CR>"_ci]
nn <silent> c{ :MoveNextBrace<CR>"_ci{
nn <silent> c} :MoveNextBrace<CR>"_ci}
nn <silent> c< :MoveNextAngleBracket<CR>"_ci<
nn <silent> c> :MoveNextAngleBracket<CR>"_ci>
nn <silent> c" :MoveNextDoubleQuote<CR>"_ci"
nn <silent> c' :MoveNextSingleQuote<CR>"_ci'
nn <silent> c` :MoveNextBacktick<CR>"_ci`
nn <silent> cn :MoveNextNumeric<CR>"_ciw
```

#

As a bonus. Here is something silly to consider when writing markdown, where
words between underscores or stars are emphasized. All other movement and
replacement commands are roughly similar, except that they can use vim built-in
change-inside-structure edit motions. Note that for the * symbol we have to
escape it with the % symbol, because the matching is done with Lua-style
regular expressions.

```vim
nn <silent> c_ :MoveNext _<CR>:SelectSlash _<CR>c
nn <silent> c* :MoveNext %*<CR>:SelectSlash %*<CR>c
```

I have been using a vimscript version of these keybindings so often I decided
to make it a little plugin instead of an ugly pure vimscript macro.  Now it is
an ugly Lua function. 😎

# Setup

The default settings are as of now [settings.lua](lua/editing/settings.lua)

```lua
require('editing').setup{
  -- Strict movement
  strict = false,

  -- Update all positions after applying macro
  update_positions = false,

  -- Relative window configuration
  window_auto_size = true,
  window_config = {
    relative = 'cursor',
    border = 'single',
    style = 'minimal',
    width = 40,
    height = 10,
    row = 2,
    col = 0,
    focusable = false,
  },

  -- When dealing with non-ASCII languages, and if Lua supports it, we could
  -- simply replace the symbols used in (Alpha)Numeric search
  lowercase = "abcdefghijklmnopqrstuvwxyz",
  uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  digits = "0123456789",

  -- The register from which we use the recorded macro in MultiMacro
  default_macro = 'q',
}
```

#
