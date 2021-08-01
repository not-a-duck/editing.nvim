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
}

return defaults
