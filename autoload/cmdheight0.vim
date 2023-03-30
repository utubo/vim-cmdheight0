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
var listchars = { tab: '  ', extends: '' }
var vertchar = '|'

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

def Truncate(text_hl: list<any>, width: number): list<any>
  if width <= 0
    return []
  elseif width ==# 1
    return ['<', '']
  endif
  var ret = []
  var w = width - 1
  for a in text_hl->reverse()
    const ww = strdisplaywidth(a[0])
    if ww <= w
      ret->insert(a)
      w -= ww
    else
      ret->insert([printf($'%.{w}S', a[0])->split('.\zs')->reverse()->join(''), a[1]])
      ret->insert(['<', ''])
      return ret
    endif
  endfor
  return ret
enddef

def GetWidth(text_hl: list<any>): number
  var s = ''
  for a in text_hl
    s ..= a[0]
  endfor
  return strdisplaywidth(s)
enddef

# --------------------
# Setup
# --------------------

export def Init()
  const override = get(g:, 'cmdheight0', {})
  g:cmdheight0 = {
    format: ' %t %m%r%=%3l:%-2c ',
    tail: '',
    tail_style: 'NONE',
    sep: '',
    sep_style: 'NONE',
    sub: ['|', '|'],
    sub_style: 'NONE',
    horiz: '─',
    horiznr: '',
    mode: {
      n:    ' N ', # Normal
      v:    ' v ', # Visual
      V:    ' V ', # V-Line
      '^V': '^V ', # V-Block
      s:    ' s ', # Select
      S:    ' S ', # S-Line
      '^S': '^S ', # S-Block
      i:    ' I ', # Insert
      R:    ' R ', # Replace
      c:    ' : ', # Command
      r:    ' > ', # Prompt
      t:    ' # ', # Terminal
      '!':  ' ! ', # Shell
      '*':  ' ? ', # Unknown
      'NC': ' - ', # Not current
    },
    zen: 0,
    laststatus: 2,
    delay: &updatetime / 1000,
    exclude: ['ControlP'],
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
    au WinScrolled * silent! OnSizeChangedOrScrolled()
    au ModeChanged [^c]:* Silent(UpdateMode)|Silent(Invalidate)
    au ModeChanged c:* Silent(UpdateMode)|Silent(OverwriteEchoWithDelay)
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
    timer_start(0, EchoStl)
  else
    w:cmdheight0_wsize = new_wsize
    Update()
  endif
  # prevent flickering
  augroup cmdheight0_invalidate
    au!
    au SafeState * ++once Silent(EchoStl)
  augroup END
enddef

# Other events
def CursorMoved()
  if zen ==# 0 || &number || &relativenumber || g:cmdheight0.delay < 0
    timer_start(0, EchoStl)
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
  n:    ['CmdHeight0Normal',      '!Normal'],
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
  var rv = name[0] ==# '!'
  const nm = rv ? name[1 : ] : name
  const id = hlID(nm)->synIDtrans()
  var fg = NVL(synIDattr(id, 'fg#'), 'NONE')
  var bg = NVL(synIDattr(id, 'bg#'), 'NONE')
  if synIDattr(id, 'reverse') ==# '1'
    rv = !rv
  endif
  if rv
    return { fg: bg, bg: fg }
  else
    return { fg: fg, bg: bg }
  endif
enddef

def SetupColor()
  if zen ==# 1
    silent! hi default link CmdHeight0Horiz VertSplit
    silent! hi default link CmdHeight0HorizNr LineNr
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
        execute $'hi {v[0]} {x}fg={lnk.fg} {x}bg={lnk.bg}'
      endif
    endif
  endfor
  const nm = GetFgBg('Normal')
  const st = GetFgBg('CmdHeight0')
  const nc = GetFgBg('CmdHeight0ModeNC')
  execute $'hi! CmdHeight0_stnm {x}fg={st.bg} {x}bg={nm.bg} {x}={g:cmdheight0.tail_style}'
  execute $'hi! CmdHeight0_ncst {x}fg={nc.bg} {x}bg={st.bg} {x}={g:cmdheight0.sep_style}'
  const title = GetFgBg('Title')
  const warn = GetFgBg('WarningMsg')
  const error = GetFgBg('ErrorMsg')
  execute $'hi! CmdHeight0Info {x}fg={title.fg} {x}bg={st.bg}'
  execute $'hi! CmdHeight0Warn {x}fg={warn.fg} {x}bg={st.bg}'
  execute $'hi! CmdHeight0Error {x}fg={error.fg} {x}bg={st.bg}'
enddef

# --------------------
# Statusline
# --------------------

def SetupStl()
  if zen ==# 1
    &statusline = '%{%cmdheight0#HorizLine()%}'
    return
  endif
  const mode   = '%#CmdHeight0_md#%{%cmdheight0#S("m")%}%#CmdHeight0_mdst#%{w:cmdheight0.sep}'
  const modeNC = '%#CmdHeight0ModeNC#%{%cmdheight0#S("mNC")%}%#CmdHeight0_ncst#%{w:cmdheight0.sepNC}'
  const tail   = '%#CmdHeight0_stnm#%{g:cmdheight0.tail}'
  const format = '%#CmdHeight0#%<' .. SubForStl(fmt_lt, sub_lt) .. '%=' .. SubForStl(fmt_rt, sub_rt)
  &statusline = $'{mode}{modeNC}{format}{tail}%#Normal# '
enddef

# prevent trim result of expr on statusline.
export def S(key: string): string
  const s = w:cmdheight0[key]
  return '%' .. strlen(s) .. '(' .. s->substitute('%', '%%', 'g') .. '%)'
enddef

def SubForStl(fmt: string, sub: string): string
  return fmt
    ->substitute('%\@<!%|', sub, 'g')
    ->substitute('%\@<!%{\([^}]*\)}', (m) =>
      '%{g:cmdheight0#ExpandBrace(0, "' ..
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

export def ExpandBrace(winid_: number, expr_: string, sub: string): string
  const winid = winid_ ==# 0 ? win_getid() : winid_
  var expr = expr_->trim('|')->substitute('^[]a-zA-Z_\.[]\+$', 'g:\0', '')
  var result = cmdheight0_legacy#WinExecute(winid, $'echon {expr}')
  if !result
    return result
  endif
  if expr_[0] ==# '|'
    result = sub .. result
  endif
  if expr_[-1] ==# '|'
    result ..= sub
  endif
  return result
enddef

def ExpandT(buf: number): string
  var ts = term_getstatus(buf)
  if !ts
    const n = bufname(buf)
    return !n ? '[No Name]' : n
  endif
  if ts ==# 'running,normal'
    ts = 'Terminal'
  endif
  return fnamemodify(bufname(buf), ':t') .. ' [' .. ts .. ']'
enddef

def ExpandM(buf: number): string
  return getbufvar(buf, '&modified') ? getbufvar(buf, '&modifiable') ? '[+]' : '[+-]' : ''
enddef

def Expand(fmt: string, winid: number, winnr: number, sub: string): list<any>
  const buf = winbufnr(winnr)
  var text_hl = []
  var text = ''
  var prefix = ''
  var percent = false
  var brace = 0
  var expr = ''
  var sharp = false
  var hl = ''
  var hl_back = ''
  for c in split(fmt, '\zs')
    if sharp
      if c ==# '#'
        text_hl->add([text, hl_back])
        hl_back = hl
        hl = ''
        text = ''
        sharp = false
      else
        hl ..= c
      endif
    elseif brace !=# 0
      if c ==# '{'
        brace += 1
      elseif c ==# '}'
        brace -= 1
      endif
      if brace ==# 0
        text ..= ExpandBrace(winid, expr, sub)
        expr = ''
      else
        expr ..= c
      endif
    elseif percent
      if c ==# '-' || '0' <= c && c <= '9'
        prefix ..= c
        continue
      elseif c ==# '%' | text ..= '%'
      elseif c ==# '|' | text ..= sub
      elseif c ==# 't' | text ..= ExpandT(buf)
      elseif c ==# 'm' | text ..= ExpandM(buf)
      elseif c ==# 'r' | text ..= getbufvar(buf, '&readonly') ? '[RO]' : ''
      elseif c ==# 'c' | text ..= printf($'%{prefix}d', getcurpos(winid)[2])
      elseif c ==# 'l' | text ..= printf($'%{prefix}d', line('.', winid))
      elseif c ==# 'L' | text ..= printf($'%{prefix}d', line('$', winid))
      elseif c ==# '{' | brace = 1
      elseif c ==# '#' | sharp = true
      elseif c ==# '*'
        text_hl->add([text, hl_back])
        text = ''
        hl_back = prefix ==# '' || prefix ==# '0' ? 'CmdHeight0' : $'User{prefix}'
      else
        text ..= '%' .. c
      endif
      percent = false
    elseif c ==# '%'
      percent = true
      prefix = ''
    else
      text ..= c
    endif
  endfor
  text_hl->add([text, hl_back])
  return text_hl
enddef

def EchoStl(timer: any = 0, opt: any = { redraw: false })
  if g:cmdheight0.exclude->index(bufname('%')) !=# -1
    return
  endif
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
        echoh StatusLine
        echon ' '
      else
        echoh VertSplit
        echon vertchar
      endif
    endif
    EchoStlWin(winid)
    has_prev = true
  endfor
enddef

def WinGetLn(winid: number, linenr: number, com: string): string
  return win_execute(winid, $'echon {com}({linenr})')
enddef

def SetupZen()
  if g:cmdheight0.laststatus ==# 0
    zen = 1
  elseif g:cmdheight0.laststatus ==# 1
    zen = winnr('$') ==# 1 ? 1 : 0
  else
    zen = 0
  endif
  if !zen
    return
  endif
  listchars = { tab: '  ', extends: '' }
  for kv in split(&listchars, ',')
    var [k, v] = split(kv, ':')
    listchars[k] = v
  endfor
  var p = &fillchars->stridx('vert:')
  vertchar = p !=# -1 ? &fillchars[p + 5] : '|'
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
  width -= textoff
  # sign & line-number
  if textoff !=# 0
    var w = textoff
    echoh SignColumn
    var snl = []
    silent! snl = sign_getplaced(winbufnr(winnr), { lnum: linenr, group: '*' })[0].signs
    if !!snl
      const sn = sign_getdefined(snl[0].name)[0]
      silent! execute 'echoh ' .. sn.texthl
      echon get(sn, 'text', '  ')
      w -= 2
    endif
    const rnu = getwinvar(winnr, '&relativenumber')
    if getwinvar(winnr, '&number') || rnu
      const nw = getwinvar(winnr, '&numberwidth')
      const linestr = printf($'%{nw - 1}d ', rnu ? abs(linenr - line('.')) : linenr)
      echon repeat(' ', w - len(linestr))
      echoh LineNr
      echon linestr
    else
      echon repeat(' ', w)
    endif
  endif
  # folded
  if WinGetLn(winid, linenr, 'foldclosed') !=# '-1'
    echoh Folded
    echon printf($'%.{width}S', WinGetLn(winid, linenr, 'foldtextresult'))->printf($'%-{width}S')
    return
  endif
  # tab
  const ts = getwinvar(winnr, '&tabstop')
  const expandtab = listchars.tab[0] .. repeat(listchars.tab[1], ts)
  var text = NVL(getbufline(winbufnr(winnr), linenr), [''])[0]
  var i = 1
  var v = 0
  win_execute(winid, $'call cmdheight0#GetHiNames({linenr})')
  for c in split(text, '\zs')
    var vc = c
    if vc ==# "\t"
      echoh SpecialKey
      if !listchars.tab[2] # string to bool
        vc = strpart(expandtab, 0, ts - v % ts)
      else
        vc = strpart(expandtab, 0, ts - v % ts - 1) .. listchars.tab[2]
      endif
    else
      execute 'echoh ' .. get(hi_names, i, 'Error')
    endif
    var vw = strdisplaywidth(vc)
    if width <= v + vw
      echoh SpecialKey
      echon listchars.extends ?? printf('%.1S', vc)
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

var hi_names = []
export def GetHiNames(l: number)
  hi_names = ['Normal']
  for c in range(1, getline(l)->printf($'%+{winwidth(0)}S')->len())
    hi_names += [synID(l, c, 1)->synIDattr('name') ?? 'Normal']
  endfor
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
  var maxleft = max([0, maxright - GetWidth(right)])
  left = Truncate(left, maxleft)

  # Middle spaces
  left->add([repeat(' ', maxleft - GetWidth(left)), ''])

  # Echo content
  echoh CmdHeight0
  for text_hl in left + right
    if text_hl[1] !=# ''
      execute 'echoh ' .. text_hl[1]
    endif
    echon text_hl[0]
  endfor

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
    sub_lt = g:cmdheight0.sub
    sub_rt = g:cmdheight0.sub
  else
    [sub_lt, sub_rt] = g:cmdheight0.sub
  endif
  const lt_rt = g:cmdheight0.format->split('%=')
  fmt_lt = lt_rt[0]
  fmt_rt = get(lt_rt, 1, '')
  SaveWinSize()
  SetupZen()
  SetupStl()
  SetupColor()
  UpdateMode()
  EchoStl(0, { redraw: true })
  redrawstatus # This flicks the screen on gvim.
enddef

# --------------------
# API
# --------------------

export def Invalidate(timer: any = 0)
  if ! exists('g:cmdheight0.initialized')
    Init()
  endif
  if ! exists('w:cmdheight0')
    ClearMode()
  endif
  augroup cmdheight0_invalidate
    au!
    au SafeState * ++once Silent(Update)
  augroup END
enddef

export def ToggleZen(flg: number = -1)
  if ! exists('g:cmdheight0.initialized')
    Init()
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
  var s = ''
  var width = winwidth(0)
  if g:cmdheight0.horiznr !=# ''
    const textoff = getwininfo(win_getid())[0].textoff
    const nr = printf($"%.{textoff}S", repeat(g:cmdheight0.horiznr, textoff))
    width -= strdisplaywidth(nr)
    s = '%#CmdHeight0HorizNr#' .. nr
  endif
  s ..= '%#CmdHeight0Horiz#'
  s ..= printf($"%.{width}S", repeat(g:cmdheight0.horiz, width))
  return s
enddef

