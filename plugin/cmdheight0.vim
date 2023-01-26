vim9script

def AtStart()
  if ! exists('g:cmdheight0.at_start') || g:cmdheight0.at_start !=# 0
    cmdheight0#Init()
  endif
enddef

augroup cmdheight0_atstart
  au!
  au VimEnter * AtStart()
augroup END

