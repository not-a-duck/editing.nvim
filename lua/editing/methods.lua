local settings = require('editing.settings')

-- Store all cursor positions from which editing should take place
-- simultaneously (multi-cursor)
local positions = nil

-- Small window to display information
local info_buffer = vim.api.nvim_create_buf(false, true)
local info_window = nil

-- All local functions
----------------------

local function Error(message)
  vim.api.nvim_err_writeln(message)
end

-- Move the cursor to the next character sequence (or single character) without
-- cluttering the search register
-- @pattern
-- single character or a sequence of characters
-- @strict
-- if the cursor is on the to-be-found pattern already, should we still jump to
-- the next?
local function move_to_next(pattern, strict)
  strict = strict or settings.strict
  -- row index is 1-based
  -- col index is 0-based
  local curpos = vim.api.nvim_win_get_cursor(0)
  local row = curpos[1]
  local col = curpos[2]

  -- NOTE: Maybe this is just horribly inefficient
  -- First we try to find it on the current line
  local line = vim.api.nvim_get_current_line()
  local left, right = string.find(line, pattern)
  if (left ~= nil) and (right ~= nil) then
    -- Fix off by one indexing on columns
    left = left - 1
    if (not strict) and (col == left) then
      -- Do nothing
      return
    end

    -- Move to the start of the found match
    vim.api.nvim_win_set_cursor(0, {row, left})
    return
  end

  -- Start from the next line until the end
  local buffer_contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local index = row + 1
  while index < #buffer_contents do
    local line = buffer_contents[index]
    -- Search current line
    local result = string.find(line, pattern)
    if result then
      -- If not nil, we have indices
      local left, right = result
      -- Fix off by one indexing on columns
      left = left - 1
      -- Move the cursor
      vim.api.nvim_win_set_cursor(0, {index, left})
      return
    end
    index = index + 1
  end

  -- Still not found, try from the start until the cursor row
  local index = 1
  while index < row do
    local line = buffer_contents[index]
    -- Search current line
    local result = string.find(line, pattern)
    if result then
      -- If not nil, we have indices
      local left, right = result
      -- Fix off by one indexing on columns
      left = left - 1
      -- Move the cursor
      vim.api.nvim_win_set_cursor(0, {index, left})
      return
    end
    index = index + 1
  end
end

-- The behaviour we want, but the other one uses Lua-style patterns
local function move_to_next_trivial(pattern, strict)
  strict = strict or settings.strict
  -- Blocking
  vim.api.nvim_feedkeys("/" .. pattern .. "<CR>")
  -- Non blocking
  vim.api.nvim_input("/" .. pattern .. "<CR>")
end

-- Exported functions
---------------------

local methods = {}

function methods.AddPosition()
  -- Set positions for multi-cursor editing
  if not positions then
    -- Initialize positions table if deleted
    positions = {}
  end

  local index = #positions + 1
  local current_pos = vim.api.nvim_win_get_cursor(0)
  positions[index] = { row = current_pos[1], col = current_pos[2] }
  -- TODO Add highlighting for all cursor positions -> Visual feedback
  -- Currently the visual feedback is resolved by a little pop-up window
  methods.UpdateWindow()
end

-- Clear positions for multi-cursor editing
function methods.ClearPositions()
  positions = nil
  methods.UpdateWindow()
end

-- Start multi-cursor editing mode
function methods.MultiMacro()
  if not positions then
    Error("There are no positions!")
    return
  end

  -- TODO check register q for contents, if nothing is seen, display an error
  -- message
  -- if not register('q') then
  --   Error("We need something to work with")
  -- end

  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_row = current_pos[1]
  local current_col = current_pos[2]

  -- Skip current position if it's in the stored positions
  for index, position in ipairs(positions) do
    -- TODO nvim_win_set_cursor does not work for whatever reason ...
    local row = position.row
    local col = position.col
    -- vim.api.nvim_win_set_cursor(0, {row, col})
    vim.api.nvim_input(':' .. row .. '<CR>')
    vim.api.nvim_input(':norm! |<CR>')
    if col > 0 then
      vim.api.nvim_input(':norm! ' .. (col - 1) .. 'l<CR>')
    end
    vim.api.nvim_input(':norm! @q<CR>')

    if settings.update_positions then
      local updated_position = vim.api.nvim_win_get_cursor(0)
      positions[index] = { row = updated_position[1] , col = updated_position[2] }
    end
  end

  -- Reset the cursor position
  vim.api.nvim_win_set_cursor(0, {current_row, current_col})
end

-- Potentially common movement patterns
---------------------------------------

function methods.MoveNextParenthesis()
  move_to_next("[()]", settings.strict)
end

function methods.MoveNextBracket()
  move_to_next("[%[%]]", settings.strict)
end

function methods.MoveNextBrace()
  move_to_next("[{}]", settings.strict)
end

function methods.MoveNextAngleBracket()
  move_to_next("[<>]", settings.strict)
end

function methods.MoveNextDoubleQuote()
  move_to_next('"', settings.strict)
end

function methods.MoveNextSingleQuote()
  move_to_next("'", settings.strict)
end

function methods.MoveNextDoubleAngle()
  move_to_next("[«»]", settings.strict)
end

-- Pop-up window
----------------

function methods.UpdateWindow()
  if not info_window then
    return
  end

  -- update buffer contents
  local table = {}

  -- override window width
  local max_length = 0

  if positions ~= nil then
    for index, position in ipairs(positions) do
      local row = position.row
      local col = position.col
      local lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
      if not lines[1] then
        -- Lines have been deleted, which messed up the positions (i.e.
        -- positions do not match with the original intent anymore)
        return
      end
      local line = row .. " : " .. lines[1]
      table[index] = line
      max_length = math.max(#line, max_length)
    end
  end

  vim.api.nvim_buf_set_lines(info_buffer, 0, -1, false, table)
  -- update window position
  window_config = settings.window_config
  if settings.window_auto_size then
    window_config.width = math.max(max_length, 1)
    window_config.height = math.max(#table, 1)
  end
  vim.api.nvim_win_set_config(info_window, window_config)
end

function methods.ToggleWindow()
  if not info_window then
    info_window = vim.api.nvim_open_win(info_buffer, false, settings.window_config)

    -- Call the update
    methods.UpdateWindow()

    -- Set the autocmd for automatic update calls
    vim.cmd([[
    augroup EDITINGWINDOW
    autocmd!
    autocmd CursorMoved,CursorMovedI * :lua require'editing'.UpdateWindow()
    augroup END
    ]])
  else
    -- Remove window gracefully
    vim.cmd("autocmd! EDITINGWINDOW")
    vim.api.nvim_win_close(info_window, true)
    vim.api.nvim_buf_set_lines(info_buffer, 0, -1, false, {})
    info_window = nil
  end
end

-- Simply override default settings with whatever is given in the update table
function methods.Setup(update)
  settings = setmetatable(update, { __index = settings })
end

return methods
