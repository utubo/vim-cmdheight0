vim9script

# --------------------
# Utils
# --------------------

# silent with echo
def Silent(F: func)
  try
    F()
  catch
    augroup nocmdline
      au!
    augroup END
    g:nocmdline = get(g:, 'nocmdline', {})
    g:nocmdline.lasterror = v:exception
    g:nocmdline.initialized = 0
    echoe 'vim-nocmdline was stopped for safety. ' ..
      'You can `:call nocmdline#Init()` to restart. ' ..
      $'Exception:{v:exception}'
    throw v:exception
  endtry
enddef

# get bottom windows
var bottomWinIds = []

def GetBottomWinIds(layout: any): any
  if layout[0] ==# 'col'
    return GetBottomWinIds(layout[1][-1])
  elseif layout[0] ==# 'row'
    var rows = []
    for r in layout[1]
       rows += GetBottomWinIds(r)
    endfor
    return rows
  else
    return [layout[1]]
  endif
enddef

def UpdateBottomWinIds()
  bottomWinIds = GetBottomWinIds(winlayout())
enddef

# others
def NVL(v: any, default: any): any
  return empty(v) ? default : v
enddef

def Truncate(s: string, vc: number): string
  if vc <= 0
    return ''
  endif
  if strdisplaywidth(s) <= vc
    return s
  endif
  if vc ==# 1
    return '<'
  endif
  const a = s->split('.\zs')->reverse()->join('')
  const b = '<' .. printf($'%.{vc - 1}S', a)->split('.\zs')->reverse()->join('')
  return printf($'%.{vc}S', b)
enddef

# --------------------
# Setup
# --------------------

export def Init()
  const override = get(g:, 'nocmdline', {})
  g:nocmdline = {
    format: '%t %m%r %=%|%3l:%-2c ',
    tail: '',
    tail_style: 'NONE',
    sep: '',
    sep_style: 'NONE',
    sub: '|',
    sub_style: 'NONE',
    horiz: '-',
    mode: {
      n:    'Normal',
      v:    'Visual',
      V:    'V-Line',
      '^V': 'V-Block',
      s:    'Select',
      S:    'S-Line',
      '^S': 'S-Block',
      i:    'Insert',
      R:    'Replace',
      c:    'Command',
      r:    'Prompt',
      t:    'Terminal',
      '!':  'Shell',
      '*':  ' ',
      'NC': '------',
    },
    zen: 0,
    delay: &updatetime / 1000,
  }
  g:nocmdline->extend(override)
  w:nocmdline = { m: '' }
  set noruler
  set noshowcmd
  set laststatus=0
  augroup nocmdline
    au!
    au ColorScheme * Silent(Invalidate)
    au WinNew,WinClosed,TabLeave * g:nocmdline.winupdated = 1
    au WinEnter * Silent(Update)|SaveWinSize() # for check scroll
    au WinLeave * Silent(ClearMode)|Silent(Invalidate)
    au WinScrolled * Silent(OnSizeChangedOrScrolled)
    au ModeChanged [^c]:* Silent(UpdateMode)|Silent(Invalidate)
    au ModeChanged c:* timer_start(g:nocmdline.delay, 'nocmdline#Invalidate')
    au TabEnter * Silent(Invalidate)
    au OptionSet fileencoding,readonly,modifiable Silent(Invalidate)
    au CursorMoved * Silent(CursorMoved)
  augroup END
  if maparg('n', 'n')->empty()
    nnoremap <script> <silent> n n
  endif
  if maparg('N', 'n')->empty()
    nnoremap <script> <silent> N N
  endif
  g:nocmdline.initialized = 1
  Update()
enddef

# Scroll event
def SaveWinSize()
  w:nocmdline_wsize = [winwidth(0), winheight(0)]
enddef

def OnSizeChangedOrScrolled()
  const new_wsize = [winwidth(0), winheight(0)]
  if w:nocmdline_wsize ==# new_wsize
    EchoStl()
    # prevent flickering
    augroup nocmdline_invalidate
      au!
      au SafeState * ++once EchoStl()
    augroup END
  else
    w:nocmdline_wsize = new_wsize
    Invalidate()
  endif
enddef

def CursorMoved()
  if g:nocmdline.zen ==# 0
    EchoStl()
  endif
enddef

# --------------------
# Color
# --------------------

const colors = {
  #       Name                    Default color
  '=':  ['NoCmdline',            'StatusLine'],
  n:    ['NoCmdlineNormal',      'ToolBarButton'],
  v:    ['NoCmdlineVisual',      'Visual'],
  V:    ['NoCmdlineVisualLine',  'VisualNOS'],
  '^V': ['NoCmdlineVisualBlock', 'link to NoCmdlineVisualLine'],
  s:    ['NoCmdlineSelect',      'DiffChange'],
  S:    ['NoCmdlineSelectLine',  'link to NoCmdlineSelect'],
  '^S': ['NoCmdlineSelectBlock', 'link to NoCmdlineSelect'],
  i:    ['NoCmdlineInsert',      'DiffAdd'],
  R:    ['NoCmdlineReplace',     'DiffChange'],
  c:    ['NoCmdlineCommand',     'WildMenu'],
  r:    ['NoCmdlinePrompt',      'Search'],
  t:    ['NoCmdlineTerm',        'StatusLineTerm'],
  '!':  ['NoCmdlineShell',       'StatusLineTermNC'],
  '_':  ['NoCmdlineModeNC',      'StatusLineNC'],
  '*':  ['NoCmdlineOther',       'link to NoCmdlineModeNC'],
}

def GetFgBg(name: string): any
  const id = hlID(name)->synIDtrans()
  var fg = NVL(synIDattr(id, 'fg#'), 'NONE')
  var bg = NVL(synIDattr(id, 'bg#'), 'NONE')
  if synIDattr(id, 'reverse') ==# '1'
    return { fg: bg, bg: fg }
  else
    return { fg: fg, bg: bg }
  endif
enddef

def SetupColor()
  if g:nocmdline.zen ==# 1
    silent! hi default link NoCmdlineHoriz VertSplit
    return
  endif
  const colorscheme = get(g:nocmdline, 'colorscheme', get(g:, 'colors_name', ''))
  if !empty(colorscheme)
    const colorscheme_vim = $'{expand("<stack>:p:h")}/colors/{colorscheme}.vim'
    if filereadable(colorscheme_vim)
      source colorscheme_vim
    endif
  endif
  const x = has('gui') ? 'gui' : 'cterm'
  for [k,v] in colors->items()
    if !hlexists(v[0]) || get(hlget(v[0]), 0, {})->get('cleared', false)
        if v[1] =~# '^link to'
          silent! execute $'hi default link {v[0]} {v[1]->substitute("link to", "", "")}'
        else
          const lnk = GetFgBg(v[1])
          execute $'hi {v[0]} {x}fg={lnk.fg} {x}bg={lnk.bg} {x}=bold'
        endif
      endif
  endfor
  const nm = GetFgBg('Normal')
  const st = GetFgBg('NoCmdline')
  const nc = GetFgBg('NoCmdlineModeNC')
  execute $'hi! NoCmdline_stnm {x}fg={st.bg} {x}bg={nm.bg} {x}={g:nocmdline.tail_style}'
  execute $'hi! NoCmdline_ncst {x}fg={nc.bg} {x}bg={st.bg} {x}={g:nocmdline.sep_style}'
enddef

# --------------------
# Statusline
# --------------------

def SetupStl()
  if g:nocmdline.zen ==# 1
    &statusline = '%#NoCmdlineHoriz#%{nocmdline#HorizLine()}'
    return
  endif
  const mode   = '%#NoCmdline_md#%{w:nocmdline.m}%#NoCmdline_mdst#%{w:nocmdline.sep}'
  const modeNC = '%#NoCmdlineModeNC#%{w:nocmdline.mNC}%#NoCmdline_ncst#%{w:nocmdline.sepNC}'
  const tail   = '%#NoCmdline_stnm#%{g:nocmdline.tail}'
  const format = '%#NoCmdline#%<' .. g:nocmdline.format->substitute('%\@<!%|', '%{nocmdline.sub}', 'g')
  &statusline = $'{mode}{modeNC}{format}{tail}%#Normal# '
enddef

# --------------------
# Mode
# --------------------

def GetMode(): string
  var m = mode()[0]
  if m ==# "\<C-v>"
    return '^V'
  elseif m ==# "\<C-s>"
    return '^S'
  elseif !g:nocmdline.mode->has_key(m)
    return '*'
  else
    return m
  endif
enddef

def ClearMode()
  w:nocmdline = {
    m: '',
    sep: '',
    mNC: g:nocmdline.mode.NC,
    sepNC: g:nocmdline.sep,
  }
enddef

def UpdateMode()
  const m = GetMode()
  const mode_name = g:nocmdline.mode[m]
  w:nocmdline = {
    m: mode_name,
    sep: g:nocmdline.sep,
    mNC: '',
    sepNC: '',
  }

  # Color
  const mode_color = colors[m][0]
  execute $'hi! link NoCmdline_md {mode_color}'
  const st = GetFgBg('StatusLine')
  const mc = GetFgBg(mode_color)
  const x = has('gui') ? 'gui' : 'cterm'
  execute $'hi! NoCmdline_mdst {x}fg={mc.bg} {x}bg={st.bg} {x}={g:nocmdline.sep_style}'
enddef


# --------------------
# Echo Statusline
# --------------------

def ExpandFunc(winid: number, buf: number, expr_: string): string
  var expr = expr_->substitute('^[]a-zA-Z_\.[]\+$', 'g:\0', '')
  return nocmdline_legacy#WinExecute(winid, $'echon {expr}')
enddef

def Expand(fmt: string, winid: number, winnr: number): string
  const buf = winbufnr(winnr)
  return fmt
    ->substitute('%\@<!%\(-*\d*\)c', (m) => printf($'%{m[1]}d', getcurpos(winid)[2]), 'g')
    ->substitute('%\@<!%\(-*\d*\)l', (m) => printf($'%{m[1]}d', line('.', winid)), 'g')
    ->substitute('%\@<!%\(-*\d*\)L', (m) => printf($'%{m[1]}d', line('$', winid)), 'g')
    ->substitute('%\@<!%r', (getbufvar(buf, '&readonly') ? '[RO]' : ''), 'g')
    ->substitute('%\@<!%m', (getbufvar(buf, '&modified') ? getbufvar(buf, '&modifiable') ? '[+]' : '[+-]' : ''), 'g')
    ->substitute('%\@<!%|', g:nocmdline.sub, 'g')
    ->substitute('%\@<!%t', bufname(winbufnr(winnr)), 'g')
    ->substitute('%\@<!%{\([^}]*\)}', (m) => ExpandFunc(winid, buf, m[1]), 'g')
    ->substitute('%%', '%', 'g')
enddef

def EchoStl(opt: any = { redraw: false })
  const m = mode()[0]
  if m ==# 'c' || m ==# 'r'
    return
  endif
  if g:nocmdline.winupdated ==# 1
    UpdateBottomWinIds()
    g:nocmdline.winupdated = 0
  endif

  if opt.redraw
    redraw # This flicks the screen on gvim.
  else
    echo "\r"
  endif

  var has_prev = false
  for winnr in bottomWinIds
    if has_prev
      # vert split
      echon ' '
      echoh StatusLine
      echon ' '
    endif
    EchoStlWin(winnr)
    has_prev = true
  endfor
enddef

def WinGetLn(winid: number, linenr: number, com: string): string
  return win_execute(winid, $'echon {com}({linenr})')
enddef

def EchoNextLine(winid: number, winnr: number)
  # TODO: The line is dolubled when botline is wrapped.
  var linenr = line('w$', winid)
  const fce = WinGetLn(winid, linenr, 'foldclosedend')
  if fce !=# '-1'
    linenr = str2nr(fce)
  endif
  linenr += 1
  const folded = WinGetLn(winid, linenr, 'foldclosed') !=# '-1'
  var text = folded ?
    WinGetLn(winid, linenr, 'foldtextresult') :
    NVL(getbufline(winbufnr(winnr), linenr), [''])[0]
  const ts = getwinvar(winnr, '&tabstop')
  text = text
    ->substitute('\(^\|\t\)\@<=\t', repeat(' ', ts), 'g')
    ->substitute('\(.*\)\t', (m) => (m[1] .. repeat(' ', ts - strdisplaywidth(m[1]) % ts)), 'g')
  const textoff = getwininfo(winid)[0].textoff
  var width = winwidth(winnr) - 2 - textoff
  # eob
  if linenr > line('$', winid)
    echoh NonText
    echon printf($'%-{winwidth(winnr) - 1}S', NVL(matchstr(&fcs, '\(eob:\)\@<=.'), '~'))
    echoh Normal
    return
  endif
  # sign & line-number
  if textoff !=# 0
    echoh SignColumn
    if getwinvar(winnr, '&number')
      const nw = max([2, getwinvar(winnr, '&numberwidth')])
      const linestr = printf($'%{nw - 1}d ', linenr)
      echon repeat(' ', textoff - len(linestr))
      echoh LineNr
      echon linestr
    else
      echon repeat(' ', textoff)
    endif
  endif
  # text
  if folded
    echoh Folded
  else
    echoh Normal
  endif
  if strdisplaywidth(text) <= width
    echon printf($'%-{width + 1}S', text)
  else
    echon printf($'%.{width}S', text)
    echoh NonText
    echon '>'
  endif
  echoh Normal
enddef

def EchoStlWin(winid: number)
  const winnr = win_id2win(winid)
  const ww = winwidth(winnr)
  if ww <= 1
    return
  endif

  # Zen
  if g:nocmdline.zen
    EchoNextLine(winid, winnr)
    return
  endif

  # Echo Mode
  var mode_name = winnr() ==# winnr ? w:nocmdline.m : g:nocmdline.mode.NC
  const minwidth = strdisplaywidth(
    mode_name ..
    g:nocmdline.sep ..
    g:nocmdline.tail
  )
  if ww <= minwidth
    if winnr() ==# winnr
      echoh NoCmdline_md
    else
      echoh NoCmdlineModeNC
    endif
    echo printf($'%.{ww - 1}S', mode_name)
    return
  endif

  const ss = getwinvar(winnr, 'nocmdline')
  if winnr() ==# winnr
    echoh NoCmdline_md
    echon mode_name
    echoh NoCmdline_mdst
    echon g:nocmdline.sep
  else
    echoh NoCmdlineModeNC
    echon mode_name
    echoh NoCmdline_ncst
    echon g:nocmdline.sep
  endif

  const left_right = g:nocmdline.format->split('%=')
  var left = Expand(left_right[0], winid, winnr)
  var right = Expand(get(left_right, 1, ''), winid, winnr)

  # Right
  const maxright = ww - minwidth - 1
  right = Truncate(right, maxright)

  # Left
  var maxleft = max([0, maxright - strdisplaywidth(right)])
  left = Truncate(left, maxleft)

  # Middle spaces
  left = printf($'%-{maxleft}S', left)

  # Echo content
  echoh NoCmdline
  echon left .. right

  # Echo tail
  echoh NoCmdline_stnm
  echon g:nocmdline.tail
  echoh Normal
enddef

def Update()
  if get(g:nocmdline, 'initialized', 0) ==# 0
    Init()
    return
  endif
  g:nocmdline.winupdated = 1
  SaveWinSize()
  SetupStl()
  SetupColor()
  UpdateMode()
  EchoStl({ redraw: true })
  redrawstatus # This flicks the screen on gvim.
enddef

# --------------------
# API
# --------------------

export def Invalidate(timer: any = 0)
  if ! exists('w:nocmdline')
    ClearMode()
  endif
  augroup nocmdline_invalidate
    au!
    au SafeState * ++once Silent(Update)
  augroup END
enddef

export def ToggleZen(flg: number = -1)
  if get(g:nocmdline, 'initialized', 0) !=# 1
    Init()
    return
  endif
  g:nocmdline.zen = flg !=# -1 ? flg : g:nocmdline.zen !=# 0 ? 0 : 1
  Update()
enddef

export def HorizLine(): string
  const width = winwidth(0)
  return printf($"%.{width}S", repeat(g:nocmdline.horiz, width))
enddef

