" emulate `%{expr}` of statusline
function! cmdheight0_legacy#WinExecute(winid, expr)
	return win_execute(a:winid, a:expr)
endfunction
