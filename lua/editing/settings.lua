local defaults = {
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

return defaults
