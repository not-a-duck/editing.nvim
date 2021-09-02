local methods = require('editing.methods')

local plugin = {
  -- Multi-cursor editing re-imagined to encourage vim-style macros until
  -- these training wheels are no longer needed
  MultiMacro = methods.MultiMacro,
  AddPosition = methods.AddPosition,
  ClearPositions = methods.ClearPositions,

  -- Movement
  MoveNextBrace = methods.MoveNextBrace,
  MoveNextBracket = methods.MoveNextBracket,
  MoveNextParenthesis = methods.MoveNextParenthesis,
  MoveNextAngleBracket = methods.MoveNextAngleBracket,
  MoveNextDoubleQuote = methods.MoveNextDoubleQuote,
  MoveNextSingleQuote = methods.MoveNextSingleQuote,
  MoveNextBacktick = methods.MoveNextBacktick,
  MoveNextDoubleAngle = methods.MoveNextDoubleAngle,
  MoveNextNumeric = methods.MoveNextNumeric,
  MoveNextAlphaNumeric = methods.MoveNextAlphaNumeric,

  -- Generic functions, user may supply Lua-style patterns
  MoveNext = methods.MoveNext,
  SelectSlash = methods.SelectSlash,

  -- Window
  UpdateWindow = methods.UpdateWindow,
  ToggleWindow = methods.ToggleWindow,

  setup = methods.Setup,
}

return plugin
