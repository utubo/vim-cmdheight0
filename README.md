# vim-cmdheight0

⚠ THIS HAS MANY BUGS !  
📜 Powered by vim9script

## INTRODUCTION
cmdheight0 is a Vim plugin emulates statusline with `echo`.  
So, it looks like `cmdheight=0`.

<img width="600" src="https://user-images.githubusercontent.com/6848636/190131571-b58d55a4-c258-42d9-bf4a-379cc8106490.png">

also, Zen mode (emulates the next line). 🧘

<img width="600" src="https://user-images.githubusercontent.com/6848636/190131844-dd95d5d4-0f18-44c1-a50b-35bddec8e1c6.png">

## USAGE
### Requirements
- vim9script

### Installation
- Example of `.vimrc`
  ```vim
  vim9script
  ⋮
  dein# add('utubo/vim-cmdheight0')
  ⋮
  g:cmdheight0 = {}
  g:cmdheight0.format = '%t %m%r %=%`%3l:%-2c%`%{&ff} %{&fenc} %L'
  # require nerd fonts
  g:cmdheight0.sep  = "\ue0b8"
  g:cmdheight0.sub  = ["\ue0bf", "\ue0bb"]
  g:cmdheight0.tail = "\ue0b8"
  nnoremap ZZ <ScriptCmd>cmdheight0#ToggleZen()<CR>
  # You can disable cmdheight0 at VimEnter
  #g:cmdheight0.at_start = 0
  ```


## INTERFACE

### API
#### `cmdheight0#Invalidate()`
Update statusline.

#### `cmdheight0#ToggleZen([{enable}])`
Toggle Zen mode.  
Zen echos the next line instead of statusline.  
(sorry, Zen don't support conceal and others...)  
`enable` is number.  
`0`: disable Zen mode  
`1`: enable Zen mode.  
none: toggle Zen mode.

### VARIABLES
#### `g:cmdheight0`
`g:cmdheight0` is dictionaly.  

- `at_start`  
  number.  
  `0`: disable cmdheight0 at VimEnter.  
  `1`: enable cmdheight0 at VimEnter.  
  `default` is `1`.  
- `delay`  
  number.  
  seconds of show statusline when return from Command-mode.  
  default is `&updatetime` / 1000.  
  n(> 0): delay n seconds.  
  0: no delay.  
  n(< 0): show statusline on cursor moved.
- `laststatus`  
  number.  
  You can use this instead of `&laststatus`.  
  status line:  
    `0`: never(Zen mode)  
    `1`: only if there are at least two windows  
    `2`: always  
  default is `2`.
- `tail`  
  the char of right of statusline.
- `sep`  
  the char of the separator of the mode.
- `sub`  
  the list of the sub-separators as `[left, right]`.  
  default is `['|', '|']`
- `tail_style`, `sep_style`, `sub_style`  
  the highlight style of serpators.  
  default is `NONE`.
- `horiz`  
  the char of the horizontal line on zen mode.  
  default is `─`.
- `horiznr`  
  the char of the horizontal line on LineNr.  
  default is empty.
- `format`  
  the format of statusline.
- `mode`  
  the names of mode.
- `exclude`  
  the exclude bufnames.  
  default is `['ControlP']`.

#### `g:cmdheight0.format`
see `:help statusline`.
cmdheight0 supports these only.

```
t S   File name (tail) of file in the buffer.
m F   Modified flag, text is "[+]"; "[-]" if 'modifiable' is off.
r F   Readonly flag, text is "[RO]".
l N   Line number.
L N   Number of lines in buffer.
c N   Column number (byte index).
{ NF  Evaluate expression between '%{' and '}' and substitute result.
= -   Separation point between left and right aligned items.
# -   Set highlight group.
* -   Set highlight group to User{N}.
      Restore normal highlight with %* or %0*.
```

Specials for vim-cmdheight0
```
| -   Sub-separator
```

`%{expr|}` Append the sub-separator when expr is not empty.

`%{expr}` Evalute expr with legacy vimscript. (not vim9script)  
The global variables need `g:`.


#### `g:cmdheight0.mode`
see `:help mode()`.

```vim
# default
g:cmdheight0.mode = {
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
  'NC': ' - ', # Not-current
}
```

### COLORS
Base

|Highlight group       |Default color                |Note                |
|----------------------|------------------------------|--------------------|
|CmdHeight0            |same as StatusLine            |                    |
|CmdHeightHoriz        |link to VertSpirt             |Horizontal separator|
|CmdHeight0HorizNr     |link to LineNr                |Horizontal separator on LineNr column|
|CmdHeight0Info        |same foreground as Title      |                    |
|CmdHeight0Warn        |same foreground as WarningMsg |                    |
|CmdHeight0Error       |same foreground as ErrorMsg   |                    |

the mode colors.

|Highlight group       |Default color                 |Note                |
|----------------------|------------------------------|--------------------|
|CmdHeight0Normal      |same as Normal Reverse        |                    |
|CmdHeight0Visual      |same as Visual                |                    |
|CmdHeight0VisualLine  |same as VisualNOS             |                    |
|CmdHeight0VisualBlock |link to CmdHeight0VisualLine  |                    |
|CmdHeight0Select      |same as DiffChange            |                    |
|CmdHeight0SelectLine  |link to CmdHeight0Select      |                    |
|CmdHeight0SelectBlock |link to CmdHeight0Select      |                    |
|CmdHeight0Insert      |same as DiffAdd               |                    |
|CmdHeight0Replace     |same as DiffChange            |                    |
|CmdHeight0Command     |same as WildMenu              |                    |
|CmdHeight0Prompt      |same as Search                |                    |
|CmdHeight0Term        |same as StatusLineTerm        |                    |
|CmdHeight0Shell       |same as StatusLineTermNC      |                    |
|CmdHeight0ModeNC      |same as StatusLineNC          |for not-current     |
|CmdHeight0Other       |link to CmdHeight0ModeNC      |for unknown mode    |

