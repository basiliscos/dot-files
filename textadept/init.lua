ui.set_theme('dark', {font = 'Monospace', fontsize = 12})
_M.file_browser = require 'file_browser'
textadept.editing.AUTOCOMPLETE_ALL = true
textadept.editing.STRIP_TRAILING_SPACES = true

local _last_buff_idx = -1
events.connect(events.BUFFER_BEFORE_SWITCH, function(name)
   _last_buff_idx = _BUFFERS[_G.buffer]
end)


keys.ca, keys.cA = buffer.vc_home, buffer.vc_home_extend
keys.ce, keys.cE = buffer.line_end, buffer.line_end_extend
keys.ck, keys.cK = buffer.line_delete
keys.cd, keys.cD = buffer.clear
keys.aw, keys.aW = buffer.copy
keys.cy, keys.cY = buffer.paste
keys.c_          = buffer.undo
keys["c`"]       = function() _G.view:goto_buffer(_last_buff_idx, false) end
-- {view.goto_buffer, view, _last_buff_idx, false}

