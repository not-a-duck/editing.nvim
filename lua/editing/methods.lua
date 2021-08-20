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
  local delta_col = col
  local left, right = string.find(string.sub(line, col + 1), pattern)

  if (left ~= nil) and (right ~= nil) then
    -- Fix off by one indexing on columns
    left = left - 1 + delta_col
    if (not strict) and (col == left) then
      -- Do nothing
      return
    end

    -- Move to the start of the found match
    vim.api.nvim_win_set_cursor(0, {row, left})
    return
  end

  -- Modulo buffer contents loop
  local buffer_contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local index = row + 1
  repeat
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
    -- Modulo for 1-based indexing ...
    if index > #buffer_contents then
      index = 1
    end
  until index == row
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

  -- TODO (Low priority) make the used macro a function argument with a
  -- settings.default_macro instead of a hard-coded q

  -- the macro runs in reverse sorted order (from bottom to top), to avoid the
  -- most obvious bugs when adding newlines during multimacro execution
  local sorted_positions = {}
  -- Naive copy
  for i, p in ipairs(positions) do
    sorted_positions[i] = p
  end
  table.sort(sorted_positions, function(x, y) return x.row > y.row end)

  -- TODO check register q for contents, if nothing is seen, display an error
  -- message
  -- if not register('q') then
  --   Error("We need something to work with")
  -- end

  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_row = current_pos[1]
  local current_col = current_pos[2]

  -- Skip current position if it's in the stored positions
  for index, position in ipairs(sorted_positions) do
    -- TODO nvim_win_set_cursor does not work for whatever reason ...
    local row = position.row
    local col = position.col
    -- vim.api.nvim_win_set_cursor(0, {row, col})
    vim.api.nvim_input(':' .. row .. '<CR>')
    vim.api.nvim_input(':norm! |<CR>')
    if col > 0 then
      vim.api.nvim_input(':norm! ' .. col .. 'l<CR>')
    end
    vim.api.nvim_input(':norm! @q<CR>')
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
    for _, position in ipairs(positions) do
      local row = position.row
      local col = position.col
      local prefix = row .. " : "
      -- We want to show which character the cursor is stored on
      col = col + #prefix
      local lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
      if not lines[1] then
        -- Lines have been deleted, which messed up the positions (i.e.
        -- positions do not match with the original intent anymore)
        -- TODO possibly just delete the positions, or do something smart with
        -- autocmd
        Error("One of the positions is off, all positions will be deleted to avoid bigger problems")
        positions = nil
        -- Recursive call is kind of ugly, but since positions is now set to
        -- nil, we can pull this off without any worries
        methods.UpdateWindow()
        return
      end
      -- TODO I would like the cursor hinting to be non-ASCII art (i.e. bold
      -- character or coloured character) but for now this will do
      -- Fix preview indentation by replacing all tabs with tabstop * space
      local tabstop = vim.api.nvim_get_option("tabstop")
      local _, num_tabs = string.gsub(string.sub(lines[1], 0, col + 1), '\t', '')
      local line = prefix .. lines[1]:gsub('\t', string.rep(' ', tabstop))
      local hint = string.rep(' ', col + num_tabs) .. "^" .. string.rep(" ", #line - col - 1)
      index = #table + 1
      table[index] = line
      table[index + 1] = hint
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
