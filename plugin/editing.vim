if !has('nvim')
  finish
endif

command! AddPosition lua require 'editing'.AddPosition()
command! ClearPositions lua require 'editing'.ClearPositions()
command! EditingToggleWindow lua require 'editing'.ToggleWindow()
command! MultiMacro lua require 'editing'.MultiMacro()

command! MoveNextBrace lua require 'editing'.MoveNextBrace()
command! MoveNextBracket lua require 'editing'.MoveNextBracket()
command! MoveNextParenthesis lua require 'editing'.MoveNextParenthesis()
command! MoveNextAngleBracket lua require 'editing'.MoveNextAngleBracket()
command! MoveNextDoubleQuote lua require 'editing'.MoveNextDoubleQuote()
command! MoveNextSingleQuote lua require 'editing'.MoveNextSingleQuote()
command! MoveNextBacktick lua require 'editing'.MoveNextBacktick()
command! MoveNextDoubleAngle lua require 'editing'.MoveNextDoubleAngle()
command! MoveNextNumeric lua require 'editing'.MoveNextNumeric()
command! MoveNextAlphaNumeric lua require 'editing'.MoveNextAlphaNumeric()

" Generic functions, user may supply Lua-style patterns
" Escaping should be done with a % symbol, for the following characters
" ( ) . % + - * ? [ ^ $
command! -nargs=* MoveNext lua require 'editing'.MoveNext(<f-args>)
command! -nargs=* SelectSlash lua require 'editing'.SelectSlash(<f-args>)
