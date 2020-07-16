buffer:set_theme('dark', {font = 'Monospace', fontsize = 12})
textredux = require 'textredux'

events.connect(events.LEXER_LOADED, function(lang)
    local w = (lang == 'elixir') and 2 or 4
    buffer.tab_width = w
    buffer.wrap_mode = buffer.WRAP_WORD
end)


textadept.editing.autocomplete_all_words = true
textadept.editing.strip_trailing_spaces = true
textadept.editing.auto_pairs[string.byte('<')] = '>'
textadept.editing.brace_matches[string.byte('<')] = true
textadept.editing.brace_matches[string.byte('>')] = true

textadept.file_types.extensions.ipp = 'cpp'

-- disable syntax check for perl
-- textadept.run.syntax_commands.perl = nil

textadept.run.run_commands['t'] = function()
   local root = io.get_project_root()
   if (root) then
      local cmd = 'cd "' .. root .. '"; prove -l %p'
      return cmd
   end
   end


local _last_buff_idx = -1
events.connect(events.BUFFER_BEFORE_SWITCH, function(name)
  _last_buff_idx = _G._BUFFERS[_G.buffer]
end)

local switch_to_buffer = function()
    -- print(" => " .. _last_buff_idx)
    _G.view:goto_buffer(_G._BUFFERS[_last_buff_idx], false)
end

local _save_all = function()
  local idx = _last_buff_idx
  io.save_all_files()
  _last_buff_idx = idx
end

keys.ca, keys.cA = buffer.vc_home, buffer.vc_home_extend
keys.ce, keys.cE = buffer.line_end, buffer.line_end_extend
keys.ck, keys.cK = buffer.line_delete
keys.cd, keys.cD = buffer.clear
keys.aw, keys.aW = buffer.copy
keys.ch		 = textadept.editing.highlight_word
keys.cw          = buffer.cut
keys.cW          = io.close_buffer
keys.cs          = _save_all
keys.cy, keys.cY = buffer.paste
keys.c_          = buffer.undo
keys["c`"]       = switch_to_buffer
keys.cO          = textredux.fs.open_file
keys.co          = io.open_file

