vim9script

# --------------------
# Global variables
# --------------------

# never statusline
var zen = 0
# cache strings
var fmt_lt = ''
var fmt_rt = ''
var sub_lt = ''
var sub_rt = ''

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
    laststatus: 2,
    delay: &updatetime / 1000,
  }
  g:cmdheight0->extend(override)
  w:cmdheight0 = { m: '', m_row: 'n' }
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
    au ModeChanged c:* Silent(OverwriteEchoWithDelay)
    au TabEnter * Silent(Invalidate)
    au OptionSet fileencoding,readonly,modifiable,number,relativenumber,signcolumn Silent(Invalidate)
    au CursorMoved * Silent(CursorMoved)
  augroup END
  # prevent to echo search word
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
  else
    w:cmdheight0_wsize = new_wsize
    Update()
  endif
  # prevent flickering
  augroup cmdheight0_invalidate
    au!
    au SafeState * ++once EchoStl()
  augroup END
enddef

# Other events
def CursorMoved()
  if zen ==# 0 || &number || &relativenumber || g:cmdheight0.delay < 0
    EchoStl()
  endif
enddef

def OverwriteEchoWithDelay()
  if g:cmdheight0.delay ==# 0
    Invalidate()
  elseif g:cmdheight0.delay > 0
    timer_start(g:cmdheight0.delay, 'cmdheight0#Invalidate')
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
  if zen ==# 1
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
# Statusline
# --------------------

def SetupStl()
  if zen ==# 1
    &statusline = '%#CmdHeight0Horiz#%{cmdheight0#HorizLine()}'
    return
  endif
  const mode   = '%#CmdHeight0_md#%{w:cmdheight0.m}%#CmdHeight0_mdst#%{w:cmdheight0.sep}'
  const modeNC = '%#CmdHeight0ModeNC#%{w:cmdheight0.mNC}%#CmdHeight0_ncst#%{w:cmdheight0.sepNC}'
  const tail   = '%#CmdHeight0_stnm#%{g:cmdheight0.tail}'
  const format = '%#CmdHeight0#%<' .. SubForStl(fmt_lt, sub_lt) .. '%=' .. SubForStl(fmt_rt, sub_rt)
  &statusline = $'{mode}{modeNC}{format}{tail}%#Normal# '
enddef

def SubForStl(fmt: string, sub: string): string
  return fmt
    ->substitute('%\@<!%|', sub, 'g')
    ->substitute('%\@<!%{\([^}]*\)|}', (m) =>
      '%{g:cmdheight0#ExpandFunc(0, 0, "' ..
      escape(m[1], '"') ..
      '", "' .. sub .. '")}', 'g')
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
    m_row: get(w:, 'cmdheight0', {})->get('m_row', 'n'),
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
    m_row: m,
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

  # for Terminal
  if m ==# 't'
    nnoremap <buffer> <script> <silent> a :call cmdheight0#Invalidate()<CR>a
    nnoremap <buffer> <script> <silent> i :call cmdheight0#Invalidate()<CR>i
  endif
enddef


# --------------------
# Echo Statusline
# --------------------

export def ExpandFunc(winid: number, buf: number, expr_: string, sub: string): string
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

def ExpandT(buf: number): string
  var ts = term_getstatus(buf)
  if !ts
    return bufname(buf)
  endif
  if ts ==# 'running,normal'
    ts = 'Terminal'
  endif
  return fnamemodify(bufname(buf), ':t') .. ' [' .. ts .. ']'
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
    ->substitute('%\@<!%t', ExpandT(buf), 'g')
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
  for winid in bottomWinIds
    if has_prev
      # vert split
      if !zen
        echon ' '
      endif
      echoh StatusLine
      echon ' '
    endif
    EchoStlWin(winid)
    has_prev = true
  endfor
enddef

def WinGetLn(winid: number, linenr: number, com: string): string
  return win_execute(winid, $'echon {com}({linenr})')
enddef

def EchoNextLine(winid: number, winnr: number)
  const ch0 = getwinvar(winnr, 'cmdheight0')
  if ch0.m_row ==# 't'
    redraw
    echo ""
    return
  endif
  var width = winwidth(winnr)
  if winid ==# bottomWinIds[-1]
    width -= 1
  endif
  # TODO: The line is dolubled when botline is wrapped.
  var linenr = line('w$', winid)
  const fce = WinGetLn(winid, linenr, 'foldclosedend')
  if fce !=# '-1'
    linenr = str2nr(fce)
  endif
  linenr += 1
  # end of buffer
  if linenr > line('$', winid)
    echoh EndOfBuffer
    echon printf($'%-{width}S', NVL(matchstr(&fcs, '\(eob:\)\@<=.'), '~'))
    echoh Normal
    return
  endif
  const textoff = getwininfo(winid)[0].textoff
  # sign & line-number
  if textoff !=# 0
    echoh SignColumn
    const rnu = getwinvar(winnr, '&relativenumber')
    if getwinvar(winnr, '&number') || rnu
      const nw = max([2, getwinvar(winnr, '&numberwidth')])
      const linestr = printf($'%{nw - 1}d ', rnu ? abs(linenr - line('.')) : linenr)
      echon repeat(' ', textoff - len(linestr))
      echoh LineNr
      echon linestr
    else
      echon repeat(' ', textoff)
    endif
  endif
  width -= textoff
  # folded
  if WinGetLn(winid, linenr, 'foldclosed') !=# '-1'
    echoh Folded
    echon printf($'%.{width}S', WinGetLn(winid, linenr, 'foldtextresult'))->printf($'%-{width}S')
    return
  endif
  # tab
  const ts = getwinvar(winnr, '&tabstop')
  var text = NVL(getbufline(winbufnr(winnr), linenr), [''])[0]
  var i = 1
  var v = 0
  for c in split(text, '\zs')
    execute 'echoh ' .. (synID(linenr, i, 1)->synIDattr('name') ?? 'Normal')
    var vc = c
    if vc ==# "\t"
      vc = repeat(' ', ts - v % ts)
    endif
    var vw = strdisplaywidth(vc)
    if width <= v + vw
      echoh NonText
      echon '>'
      v += 1
      break
    endif
    echon vc
    i += len(c)
    v += vw
  endfor
  echoh Normal
  echon repeat(' ', width - v)
enddef

def EchoStlWin(winid: number)
  const winnr = win_id2win(winid)
  const ww = winwidth(winnr)
  if ww <= 1
    return
  endif

  # Zen
  if zen
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

  var left = Expand(fmt_lt, winid, winnr, sub_lt)
  var right = Expand(fmt_rt, winid, winnr, sub_rt)

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
  if g:cmdheight0.laststatus ==# 0
    zen = 1
  elseif g:cmdheight0.laststatus ==# 1
    zen = winnr('$') ==# 1 ? 1 : 0
  else
    zen = 0
  endif
  g:cmdheight0.winupdated = 1
  if type(g:cmdheight0.sub) ==# type('foo')
    sub_lt = g:cmdheight0.sub
    sub_rt = g:cmdheight0.sub
  else
    [sub_lt, sub_rt] = g:cmdheight0.sub
  endif
  const lt_rt = g:cmdheight0.format->split('%=')
  fmt_lt = lt_rt[0]
  fmt_rt = get(lt_rt, 1, '')
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
  if flg ==# 1
    g:cmdheight0.laststaus = 0
  elseif flg ==# 0
    g:cmdheight0.laststatus = 2
  else
    g:cmdheight0.laststatus = g:cmdheight0.laststatus ==# 0 ? 2 : 0
  endif
  Update()
enddef

export def HorizLine(): string
  const width = winwidth(0)
  return printf($"%.{width}S", repeat(g:cmdheight0.horiz, width))
enddef

