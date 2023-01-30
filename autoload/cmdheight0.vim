vim9script

# --------------------
# Utils
# --------------------

# silent with echo
def Silent(F: func)
  try
    F()
  catch
    augroup cmdheight0
      au!
    augroup END
    g:cmdheight0 = get(g:, 'cmdheight0', {})
    g:cmdheight0.lasterror = v:exception
    g:cmdheight0.initialized = 0
    echoe 'vim-cmdheight0 was stopped for safety. ' ..
      'You can `:call cmdheight0#Init()` to restart. ' ..
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
  const override = get(g:, 'cmdheight0', {})
  g:cmdheight0 = {
    format: '%t %m%r %=%|%3l:%-2c ',
    tail: '',
    tail_style: 'NONE',
    sep: '',
    sep_style: 'NONE',
    sub: ['|', '|'],
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
  g:cmdheight0->extend(override)
  w:cmdheight0 = { m: '' }
  set noruler
  set noshowcmd
  set laststatus=0
  augroup cmdheight0
    au!
    au ColorScheme * Silent(Invalidate)
    au WinNew,WinClosed,TabLeave * g:cmdheight0.winupdated = 1
    au WinEnter * Silent(Update)|SaveWinSize() # for check scroll
    au WinLeave * Silent(ClearMode)|Silent(Invalidate)
    au WinScrolled * Silent(OnSizeChangedOrScrolled)
    au ModeChanged [^c]:* Silent(UpdateMode)|Silent(Invalidate)
    au ModeChanged c:* timer_start(g:cmdheight0.delay, 'cmdheight0#Invalidate')
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
  g:cmdheight0.initialized = 1
  Update()
enddef

# Scroll event
def SaveWinSize()
  w:cmdheight0_wsize = [winwidth(0), winheight(0)]
enddef

def OnSizeChangedOrScrolled()
  const new_wsize = [winwidth(0), winheight(0)]
  if w:cmdheight0_wsize ==# new_wsize
    EchoStl()
    # prevent flickering
    augroup cmdheight0_invalidate
      au!
      au SafeState * ++once EchoStl()
    augroup END
  else
    w:cmdheight0_wsize = new_wsize
    Invalidate()
  endif
enddef

def CursorMoved()
  if g:cmdheight0.zen ==# 0
    EchoStl()
  endif
enddef

# --------------------
# Color
# --------------------

const colors = {
  #       Name                    Default color
  '=':  ['CmdHeight0',            'StatusLine'],
  n:    ['CmdHeight0Normal',      'ToolBarButton'],
  v:    ['CmdHeight0Visual',      'Visual'],
  V:    ['CmdHeight0VisualLine',  'VisualNOS'],
  '^V': ['CmdHeight0VisualBlock', 'link to CmdHeight0VisualLine'],
  s:    ['CmdHeight0Select',      'DiffChange'],
  S:    ['CmdHeight0SelectLine',  'link to CmdHeight0Select'],
  '^S': ['CmdHeight0SelectBlock', 'link to CmdHeight0Select'],
  i:    ['CmdHeight0Insert',      'DiffAdd'],
  R:    ['CmdHeight0Replace',     'DiffChange'],
  c:    ['CmdHeight0Command',     'WildMenu'],
  r:    ['CmdHeight0Prompt',      'Search'],
  t:    ['CmdHeight0Term',        'StatusLineTerm'],
  '!':  ['CmdHeight0Shell',       'StatusLineTermNC'],
  '_':  ['CmdHeight0ModeNC',      'StatusLineNC'],
  '*':  ['CmdHeight0Other',       'link to CmdHeight0ModeNC'],
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
  if g:cmdheight0.zen ==# 1
    silent! hi default link CmdHeight0Horiz VertSplit
    return
  endif
  const colorscheme = get(g:cmdheight0, 'colorscheme', get(g:, 'colors_name', ''))
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
  const st = GetFgBg('CmdHeight0')
  const nc = GetFgBg('CmdHeight0ModeNC')
  execute $'hi! CmdHeight0_stnm {x}fg={st.bg} {x}bg={nm.bg} {x}={g:cmdheight0.tail_style}'
  execute $'hi! CmdHeight0_ncst {x}fg={nc.bg} {x}bg={st.bg} {x}={g:cmdheight0.sep_style}'
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
  elseif !g:cmdheight0.mode->has_key(m)
    return '*'
  else
    return m
  endif
enddef

def ClearMode()
  w:cmdheight0 = {
    m: '',
    sep: '',
    mNC: g:cmdheight0.mode.NC,
    sepNC: g:cmdheight0.sep,
  }
enddef

def UpdateMode()
  const m = GetMode()
  const mode_name = g:cmdheight0.mode[m]
  w:cmdheight0 = {
    m: mode_name,
    sep: g:cmdheight0.sep,
    mNC: '',
    sepNC: '',
  }

  # Color
  const mode_color = colors[m][0]
  execute $'hi! link CmdHeight0_md {mode_color}'
  const st = GetFgBg('StatusLine')
  const mc = GetFgBg(mode_color)
  const x = has('gui') ? 'gui' : 'cterm'
  execute $'hi! CmdHeight0_mdst {x}fg={mc.bg} {x}bg={st.bg} {x}={g:cmdheight0.sep_style}'
enddef


# --------------------
# Echo Statusline
# --------------------

def ExpandFunc(winid: number, buf: number, expr_: string, sub: string): string
  var expr = expr_->trim('|')->substitute('^[]a-zA-Z_\.[]\+$', 'g:\0', '')
  var result = cmdheight0_legacy#WinExecute(winid, $'echon {expr}')
  if !result
    return result
  endif
  if expr_[0] ==# '|'
    result = sub .. result
  endif
  if expr_[len(expr_) - 1] ==# '|'
    result ..= sub
  endif
  return result
enddef

def Expand(fmt: string, winid: number, winnr: number, sub: string): string
  const buf = winbufnr(winnr)
  return fmt
    ->substitute('%\@<!%\(-*\d*\)c', (m) => printf($'%{m[1]}d', getcurpos(winid)[2]), 'g')
    ->substitute('%\@<!%\(-*\d*\)l', (m) => printf($'%{m[1]}d', line('.', winid)), 'g')
    ->substitute('%\@<!%\(-*\d*\)L', (m) => printf($'%{m[1]}d', line('$', winid)), 'g')
    ->substitute('%\@<!%r', (getbufvar(buf, '&readonly') ? '[RO]' : ''), 'g')
    ->substitute('%\@<!%m', (getbufvar(buf, '&modified') ? getbufvar(buf, '&modifiable') ? '[+]' : '[+-]' : ''), 'g')
    ->substitute('%\@<!%|', sub, 'g')
    ->substitute('%\@<!%t', bufname(winbufnr(winnr)), 'g')
    ->substitute('%\@<!%{\([^}]*\)}', (m) => ExpandFunc(winid, buf, m[1], sub), 'g')
    ->substitute('%%', '%', 'g')
enddef

def EchoStl(opt: any = { redraw: false })
  const m = mode()[0]
  if m ==# 'c' || m ==# 'r'
    return
  endif
  if g:cmdheight0.winupdated ==# 1
    UpdateBottomWinIds()
    g:cmdheight0.winupdated = 0
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
  if g:cmdheight0.zen
    EchoNextLine(winid, winnr)
    return
  endif

  # Echo Mode
  var mode_name = winnr() ==# winnr ? w:cmdheight0.m : g:cmdheight0.mode.NC
  const minwidth = strdisplaywidth(
    mode_name ..
    g:cmdheight0.sep ..
    g:cmdheight0.tail
  )
  if ww <= minwidth
    if winnr() ==# winnr
      echoh CmdHeight0_md
    else
      echoh CmdHeight0ModeNC
    endif
    echo printf($'%.{ww - 1}S', mode_name)
    return
  endif

  const ss = getwinvar(winnr, 'cmdheight0')
  if winnr() ==# winnr
    echoh CmdHeight0_md
    echon mode_name
    echoh CmdHeight0_mdst
    echon g:cmdheight0.sep
  else
    echoh CmdHeight0ModeNC
    echon mode_name
    echoh CmdHeight0_ncst
    echon g:cmdheight0.sep
  endif

  const left_right = g:cmdheight0.format->split('%=')
  var left = Expand(left_right[0], winid, winnr, g:cmdheight0.subs[0])
  var right = Expand(get(left_right, 1, ''), winid, winnr, g:cmdheight0.subs[1])

  # Right
  const maxright = ww - minwidth - 1
  right = Truncate(right, maxright)

  # Left
  var maxleft = max([0, maxright - strdisplaywidth(right)])
  left = Truncate(left, maxleft)

  # Middle spaces
  left = printf($'%-{maxleft}S', left)

  # Echo content
  echoh CmdHeight0
  echon left .. right

  # Echo tail
  echoh CmdHeight0_stnm
  echon g:cmdheight0.tail
  echoh Normal
enddef

def Update()
  if get(g:cmdheight0, 'initialized', 0) ==# 0
    Init()
    return
  endif
  g:cmdheight0.winupdated = 1
  if type(g:cmdheight0.sub) ==# type('foo')
    g:cmdheight0.subs = [g:cmdheight0.sub, g:cmdheight0.sub]
  else
    g:cmdheight0.subs = g:cmdheight0.sub
  endif
  SaveWinSize()
  SetupColor()
  UpdateMode()
  EchoStl({ redraw: true })
  redrawstatus # This flicks the screen on gvim.
enddef

# --------------------
# API
# --------------------

export def Invalidate(timer: any = 0)
  if ! exists('w:cmdheight0')
    ClearMode()
  endif
  augroup cmdheight0_invalidate
    au!
    au SafeState * ++once Silent(Update)
  augroup END
enddef

export def ToggleZen(flg: number = -1)
  if get(g:cmdheight0, 'initialized', 0) !=# 1
    Init()
    return
  endif
  g:cmdheight0.zen = flg !=# -1 ? flg : g:cmdheight0.zen !=# 0 ? 0 : 1
  Update()
enddef

export def HorizLine(): string
  const width = winwidth(0)
  return printf($"%.{width}S", repeat(g:cmdheight0.horiz, width))
enddef

