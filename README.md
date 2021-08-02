# Editing

The _raison d'être_ of this plugin is mostly my own degeneracy.

In short:

* Add positions marks (\*) with `:AddPosition`.
* Display a window to display all position marks, that is updated live with
  `:ToggleWindow`.
* Apply the macro in register `q` starting from all marked positions with
  `:MultiMacro`.
* Clear all previously marked positions with `:ClearPositions`.

(\*) not actual nvim marks.

The `:AddPosition` and `:ToggleWindow` could also be used to simply stare at
the marked lines, if you are into weird !@#$ like that.

## Nota bene

As of right now the `:MultiMacro` _will_ produce buggy results if the q-macro
adds extra newlines to the buffer. As the positions are not updated on each
action, the macro will be reproduced at incorrect positions.
A workaround could be to simply not allow this behaviour, but I would rather
reverse-sort the positions to make it possible to do this.

# Movement

Apart from little features to help with editing I will also add common-enough
movements that are language agnostic which I myself use to quickly edit
documents. Such as `:MoveNextParenthesis`, `:MoveNextBracket`,
`:MoveNextDoubleQuote`, etc.

In my personal init.vim I have the following keymaps, which allow me to quickly
jump to the next matching tag, and editing whatever is inside the matching
pair, regardless of how many vertical space was between my initial cursor
position and the matching pair. Notice that the default behaviour of nvim
supports slight horizontal jumps when using `ci"`, I am merely extending the
range, extending the options, and shortening the shortcut.

```vim
nn c( :MoveNextParenthesis<CR>ci(
nn c) :MoveNextParenthesis<CR>ci(
nn c[ :MoveNextBracket<CR>ci[
nn c] :MoveNextBracket<CR>ci[
nn c{ :MoveNextBrace<CR>ci{
nn c} :MoveNextBrace<CR>ci{
nn c< :MoveNextAngleBracket<CR>ci<
nn c> :MoveNextAngleBracket<CR>ci<
nn c" :MoveNextDoubleQuote<CR>ci"
nn c' :MoveNextSingleQuote<CR>ci'
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
}
```

#
