local settings = require('editing.settings')

-- Store all cursor positions from which editing should take place
-- simultaneously (multi-cursor)
local BUFFER_POSITIONS = {}

-- Small window to display information
local BUFFER_WINDOWS = {}

-- Re-use the same buffer for every potential tab, it is refilled on every
-- cursor movement anyway
local info_buffer = vim.api.nvim_create_buf(false, true)

-- All local functions
----------------------

local function Error(message)
  vim.api.nvim_err_writeln(message)
end

local function GetBufferNumber()
  return vim.api.nvim_buf_get_number(0)
end

local function parse_dots( ... )
  local pt = {}
  for i, e in ipairs({ ... }) do
    pt[i] = e
  end

  -- Accept all arguments as one large string
  return table.concat(pt, "")
end

local function find_next(pattern, strict)
  -- Returns either nil or {row, col} where
  -- row index is 1-based
  -- col index is 0-based

  strict = strict or settings.strict
  local curpos = vim.api.nvim_win_get_cursor(0)
  local row = curpos[1]
  local col = curpos[2]

  -- NOTE: Maybe this is just horribly inefficient
  -- First we try to find it on the current line
  local line = vim.api.nvim_get_current_line()
  -- Left and right columns
  local left = nil
  local right = nil

  -- Can we find the pattern on the current line?
  left, right = string.find(line, pattern, col + 1)
  if (left == nil) or (right == nil) then
    goto continue
  end

  -- If we found it, we may still need to go to the next occurrence
  if strict and left == (col + 1) then
    left, right = string.find(line, pattern, right + 1)
  end

  if (left ~= nil) and (right ~= nil) then
    return {row, left - 1}
  end

  ::continue::

  -- Modulo buffer contents loop
  local buffer_contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local crow = row + 1
  if crow > #buffer_contents then
    crow = 1
  end
  repeat
    local line = buffer_contents[crow]
    -- Search current line
    local result = string.find(line, pattern)
    if result then
      -- If not nil, we have indices
      local left, right = result
      -- Fix off by one indexing on columns
      return {crow, left - 1}
    end

    crow = crow + 1
    -- Modulo for 1-based indexing ...
    if crow > #buffer_contents then
      crow = 1
    end
  until crow == row

  return nil
end

-- Move the cursor to the next character sequence (or single character) without
-- cluttering the search register
-- @pattern single character, or a sequence of characters, or an actual pattern
-- @strict if the cursor is on the to-be-found pattern already, should we still
-- jump to the next?
local function move_to_next(pattern, strict)
  position = find_next(pattern, strict)
  if position ~= nil then
    -- Move to the start of the found match
    vim.api.nvim_win_set_cursor(0, position)
  end
end

-- The behaviour we want, but the other one uses Lua-style patterns
local function move_to_next_trivial(pattern, strict)
  strict = strict or settings.strict
  -- Blocking
  vim.api.nvim_feedkeys("/" .. pattern .. "<CR>", "n", false)
  -- Non blocking
  vim.api.nvim_input("/" .. pattern .. "/<CR>")
end

-- Exported functions
---------------------

local methods = {}

function methods.AddPosition()
  local buffer_nr = GetBufferNumber()
  local positions = BUFFER_POSITIONS[buffer_nr]

  -- Set positions for multi-cursor editing
  if not positions then
    -- Initialize positions table if deleted
    positions = {}
    BUFFER_POSITIONS[buffer_nr] = positions
  end

  local index = #positions + 1
  local current_pos = vim.api.nvim_win_get_cursor(0)
  positions[index] = { row = current_pos[1], col = current_pos[2] }

  -- TODO Add highlighting for all cursor positions -> Visual feedback
  -- Currently the visual feedback is resolved by a little pop-up window
  methods.UpdateWindow()
end

-- Clear multi-cursor macro buffer positions
function methods.ClearPositions()
  local buffer_nr = GetBufferNumber()
  BUFFER_POSITIONS[buffer_nr] = {}
  methods.UpdateWindow()
end

-- Execute the default macro on all marked positions
function methods.MultiMacro()
  local buffer_nr = GetBufferNumber()
  local positions = BUFFER_POSITIONS[buffer_nr]

  if not positions then
    Error("There are no positions!")
    return
  end

  -- the macro runs in reverse sorted order (from bottom to top), to avoid the
  -- most obvious bugs when adding newlines during multimacro execution
  local sorted_positions = {}
  -- Naive copy
  for i, p in ipairs(positions) do
    sorted_positions[i] = p
  end

  local comparison = function(x, y)
    -- We also reverse sort from right to left, not just from bottom to top
    -- Assuming most edits only add characters, this should produce the least
    -- number of bugs
    if x.row == y.row then
      return x.col > y.col
    end

    return x.row > y.row
  end

  table.sort(sorted_positions, comparison)

  -- TODO check the default macro register's contents, display an error
  -- message if nothing is found?
  -- if not register(settings.default_macro) then
  --   Error("We need something to work with")
  -- end

  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_row = current_pos[1]
  local current_col = current_pos[2]

  -- Skip current position if it's in the stored positions
  for index, position in ipairs(sorted_positions) do
    local row = position.row
    local col = position.col

    -- TODO nvim_win_set_cursor does not work for whatever reason ...
    -- vim.api.nvim_win_set_cursor(0, {row, col})

    -- Ugly workaround
    vim.api.nvim_input(':' .. row .. '<CR>')
    vim.api.nvim_input(':norm! ' .. (col + 1) .. '|<CR>')

    -- Execute macro
    vim.api.nvim_input(':norm! @' .. settings.default_macro .. '<CR>')
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

function methods.MoveNextBacktick()
  move_to_next("`", settings.strict)
end

function methods.MoveNextDoubleAngle()
  move_to_next("[«»]", settings.strict)
end

function methods.MoveNextNumeric()
  local digits = settings.digits
  local pattern = "[" .. digits .. "]"
  move_to_next(pattern, settings.strict)
end

function methods.MoveNextAlphaNumeric()
  local lowercase = settings.lowercase
  local uppercase = settings.uppercase
  local digits = settings.digits
  local pattern = "[" .. lowercase .. uppercase .. digits .. "]+"
  move_to_next(pattern, settings.strict)
end

function methods.MoveNext( ... )
  local pattern = parse_dots( ... )
  move_to_next(pattern, true)
end

function methods.SelectSlash( ... )
  local pattern = parse_dots( ... )

  -- Find strictly next position, but with Lua-style patterns
  local current_position = vim.api.nvim_win_get_cursor(0)
  position = find_next(pattern, true)
  if position ~= nil then
    local crow = current_position[1]
    local ccol = current_position[2]
    local nrow = position[1]
    local ncol = position[2]
    -- TODO This does not work when text contains tabs, because the cursor
    -- position does not play well with tabs, the delta x and y do need to
    -- account for tabs.
    if nrow == crow then
      if ncol > ccol then
        vim.api.nvim_feedkeys("v" .. (ncol + 1) .. "|", "n", false)
        -- vim.api.nvim_win_set_cursor(0, position)
      end
    elseif nrow > crow then
      local drow = nrow - crow
      -- vim.api.nvim_win_set_cursor(0, position)
      vim.api.nvim_feedkeys("v" .. drow .. "j" .. (ncol + 1) .. "|", "n", false)
    end
  end
end

-- Pop-up window
----------------

function methods.UpdateWindow()
  local buffer_nr = GetBufferNumber()
  local info_window = BUFFER_WINDOWS[buffer_nr]

  if not info_window then
    return
  end

  -- update buffer contents
  local table = {}

  -- override window width
  local max_length = 0

  local positions = BUFFER_POSITIONS[buffer_nr]
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
        methods.ClearPositions()
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
  local buffer_nr = GetBufferNumber()
  local info_window = BUFFER_WINDOWS[buffer_nr]
  if not info_window then
    info_window = vim.api.nvim_open_win(info_buffer, false, settings.window_config)
    BUFFER_WINDOWS[buffer_nr] = info_window

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
    -- NOTE: If we delete the EDITINGWINDOW augroup, the floating windows in
    -- other tabs stop working.
    -- vim.cmd("autocmd! EDITINGWINDOW")
    -- vim.api.nvim_buf_set_lines(info_buffer, 0, -1, false, {})
    vim.api.nvim_win_close(info_window, true)
    BUFFER_WINDOWS[buffer_nr] = nil
  end
end

-- Simply override default settings with whatever is given in the update table
function methods.Setup(update)
  settings = setmetatable(update, { __index = settings })
end

return methods
