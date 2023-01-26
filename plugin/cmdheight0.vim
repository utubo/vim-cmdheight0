vim9script

def AtStart()
  if ! exists('g:nocmdline.at_start') || g:nocmdline.at_start !=# 0
    nocmdline#Init()
  endif
enddef

augroup nocmdline_atstart
  au!
  au VimEnter * AtStart()
augroup END

