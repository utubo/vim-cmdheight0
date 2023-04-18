" emulate `%{expr}` of statusline
function! cmdheight0_legacy#WinExecute(winid, expr)
  try
    return win_execute(a:winid, a:expr)
  catch
    let g:cmdheight0.lasterror = v:exception
    return ''
  endtry
endfunction
