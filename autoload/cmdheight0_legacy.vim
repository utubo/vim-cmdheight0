" emulate `%{expr}` of statusline
function! nocmdline_legacy#WinExecute(winid, expr)
	return win_execute(a:winid, a:expr)
endfunction
