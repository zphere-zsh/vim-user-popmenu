" ·•« User Menu Plugin »•· ·•« zphere-zsh/vim-user-popmenu »•·
" Copyright (c) 2020 « Sebastian Gniazdowski ».
" License: « Gnu GPL v3 ».
" 
" Example user-menu «list» of «dictionaries»:
" 
" let g:user_menu = [
"     \ [ "Reload",      #{ type: "cmds", body: ":edit!" } ],
"     \ [ "Quit Vim",    #{ type: "cmds", body: ":qa!" } ],
"     \ [ "New Window",  #{ type: "keys", body: "\<C-w>n" } ],
"     \ [ "Load passwd", #{ type: "expr", body: "LoadPasswd()" } ]
" \ ]
" 
" The "syntax" of the user-menu «list» of «dictionaries» is:
" [ 
"     \ [ "Item text …", #{ type: "type-kind", body: "the command body" } ],
"       ···
"       ···
"     \ [ "Item N text …", #{ <configuration 2> } ]
" \ ]
" 
" The meaning of the dictionary keys:
"
" – The "type" is one of: "cmds", "expr", "norm", "keys", "other-item".
"
" – The "{command body}" is either:
"   – A Ex command, like ":w" or "w". Type: "cmds" causes such command to be
"     run.
"   – An expression code, like, e.g.: "MyFunction()". Type: "expr".
"   – A sequence of norm commands, like, e.g.: "\<C-W>gf". Type: "norm" and
"     "norm!".
"   – A sequence of keys to feed into the editor simulating input, like, e.g.:
"     "\<C-w>n". Type: "keys".
"   – An item text or an ID of the other user menu entry, e.g.: "Open …" or "1".
"     Type "other-item" will cause the given other menu item to be run, only. 
"   
" There are also some optional, advanced keys of the dictionary:
" [ [ "…", #{ …,
"     \   opts: "options",
"     \   smessage: "start-message-text",
"     \   message: "message-text",
"     \   prompt: "prompt-text",
"     \   chain: "text-or-id",
"     \   body2: "additional command body of type <cmds>",
"     \   predic: "expression",
"     \ }
" \ ] ]
"   
" – The "options" is a comma- or space-separated list of subset of these
"   options: "keep-menu-open", "only-in-normal", "only-in-insert",
"   "only-in-visual", "only-in-cmds", "only-in-sh", "always-show",
"   "exit-to-norm".
"
"   – The "keep-menu-open" option causes the menu to be reopened immediately
"     after the selected command will finish executing.
"   – The "only-in-…" options show the item only if the menu is started in the
"     given mode, for example when inserting text, unless also the "always-show"
"     option is specified, in which case the item is being always displayed,
"     however it's executed *only* in the given mode (an error is displayed if
"     the mode is wrong).
"   – The "exit-to-norm" option causes the currently typed-in command (i.e.:
"     the text: ":… text …" in the command line window) to be discarded when the
"     menu is started (otherwise the text/the command is being always restored
"     after the menu closes → right before executing the selected command; this
"     allows to define a menu item that does something with the command, e.g.:
"     quotes slashes within it).
"
" – The "text-or-id" is either the text of the other user-menu item (the one to
"   chain-up/run after the edited item) or an ID of it.
"
" – The "start-message-text" is a message text to be shown *before* running the
"   command. It can start with a special string: "hl:<HL-group>:…" to show the
"   message in a specified color. There are multiple easy to use hl-groups, like
"   green,lgreen,yellow,lyellow,lyellow2,blue,blue2,lblue,lblue2,etc.
"
" – The "message-text" is a message text to be shown after running the command.
"
" – The "prompt-text" is a prompt-message text to be show when asking for the
"   user input (which is then assigned to the g:user_menu_prompt_input).
"
" – The "additional command body" is an Ex command to be run immediately after
"   executing the main body ↔ the main command part.
" 

" FUNCTION: UserMenu_Start() {{{
func! UserMenu_Start()
    let s:cmds = UserMenu_BufOrSesVar("user_menu_cmode_cmd", getcmdline())
    PRINT °°° UserMenu_Start °°° Mode: mode() ((!empty(s:cmds)) ? '←·→ Cmd: '.string(s:cmds):'')

    call UserMenu_EnsureInit()

    let [opr,ops] = [ '(^|[[:space:]]+|,)', '([[:space:]]+|,|$)' ]

    " The source of the menu…
    let menu = deepcopy(get(g:,'user_menu', s:default_user_menu))
    " … and the temporary (it'll exist till the selection), built effect of it.
    let s:current_menu[bufnr()] = []
    " The list of items passed to popup_menu()
    let items = []
    for entry in menu
        " Fetch the options of the item.
	let opts_key = get(entry[1], 'opts', '')
	let opts_in = (type(opts_key) == 3) ? opts_key : split(opts_key, '\v(\s+|,)')
	call add(entry, {})
	call filter( opts_in, "!empty(extend(entry[2], { v:val : 1 }))" )
	let opts = entry[2]
'
        " The item shown only when the menu started in insert mode?
        if has_key(l:opts, 'only-in-insert') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^(R[cvx]=|i[cx]=)' | continue | endif
        endif
        " The item shown only when the menu started in normal mode?
        if has_key(l:opts, 'only-in-normal') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^n(|o|ov|oV|oCTRL-V|iI|iR|iV).*' | continue | endif
        endif
        " The item shown only when the menu started in visual mode?
        if has_key(l:opts, 'only-in-visual') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^([vV]|CTRL-V|[sS]|CTRL-S)$' | continue | endif
        endif
        " The item shown only when the menu started when entering commands?
        if has_key(l:opts, 'only-in-ex') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^c[ve]=' | continue | endif
        endif
        " The item shown only when the menu started when a job is running?
        if has_key(l:opts, 'only-in-sh') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^[\!t]$' | continue | endif
        endif

        " Support embedding variables in the text via {var}.
        let entry[0] = UserMenu_ExpandVars(entry[0])
        call add( items, entry[0] )
        call add( s:current_menu[bufnr()], entry )
    endfor

    " Special actions needed for command mode.
    if mode() =~# '\v^c[ve]='
        call UserMenu_BufOrSesVarSet("user_menu_cmode_cmd", ':'.getcmdline())
        call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode", 1)
        call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode_once", "once")
        call feedkeys("\<Up>","n")
    endif

    call popup_menu( items, #{ 
                \ callback: 'UserMenu_MainCallback',
                \ filter: 'UserMenu_KeyFilter',
                \ filtermode: "a",
                \ time: 30000,
                \ mapping: 0,
                \ border: [ ],
                \ fixed: 0,
                \ flip: 1,
                \ title: ' VIM User Menu ',
                \ drag: 1,
                \ resize: 1,
                \ close: 'button',
                \ highlight: 'UMPmenu',
                \ cursorline: 1,
                \ borderhighlight: [ 'um_yellow', 'um_yellow', 'um_yellow', 'um_yellow' ],
                \ padding: [ 1, 1, 1, 1 ] } )
    redraw

    return !empty(UserMenu_BufOrSesVar("user_menu_cmode_cmd")) ?
		\ 'echo "'.escape(UserMenu_BufOrSesVar("user_menu_cmode_cmd"),'"')."\"" : ""
endfunc " }}}
" FUNCTION: UserMenu_MainCallback() {{{
func! UserMenu_MainCallback(id, result)
    " Carefully establish the selection and its data.
    let [s:it,s:got_it,s:result,s:type,s:body] = [ [ "", {} ], 0, a:result, "", "" ]
    if a:result > 0 && a:result <= len(s:current_menu[bufnr()])
        let [s:it,s:got_it] = [s:current_menu[bufnr()][a:result - 1], 1]
        let [s:type,s:body] = [s:it[1]['type'],s:it[1]['body']]
    endif

    " Important, base debug log.
    2PRINT °° Callback °° °id° ≈≈ s:result ←·→ (s:got_it ? string(s:it[0]).' ←·→ TPE ·'.s:type.'· BDY ·'.s:body.'·' : '≠')

    " Should restore the command line?
    let had_cmd = 0
    if !empty(UserMenu_BufOrSesVar("user_menu_cmode_cmd"))
	" TODO2: timer, aby przetworzyć te klawisze przed wywołaniem komendy
        call UserMenu_RestoreCmdLineFrom(UserMenu_BufOrSesVar("user_menu_cmode_cmd"))
	let had_cmd = 1
    endif
    call UserMenu_BufOrSesVarSet("user_menu_cmode_cmd", "")
    call UserMenu_CleanupSesVars()

    " The menu has been canceled? (ESC, ^C, cursor move)
    if !s:got_it
        if a:result > len(a:result)
            PRINT! Error: the index is too large →→ ••• s:result > len(s:current_menu) •••
        endif

        return
    endif

    " Output message before the command?
    call UserMenu_DeployUserMessage(s:it[1], 'smessage', -1)

    " Read the attached action specification and perform it.
    if s:type == 'cmds'
        exe s:body
    elseif s:type == 'expr'
        call eval(s:body)
    elseif s:type =~# '\v^norm(\!|)$'
        exe s:type s:body
    elseif s:type == 'keys'
        call feedkeys(s:body,"n")
    else
        PRINT! Unrecognized ·item· type: • s:type •
    endif

    " Output message after the command?
    call UserMenu_DeployUserMessage(s:it[1], 'message', 1)

    let l:opts = s:it[2]

    " Reopen the menu?
    if has_key(l:opts, 'keep-menu-open')
        call add(s:timers, timer_start(500, function("s:deferedMenuStart")))
    endif

    " Cancel ex command?
    if has_key(l:opts, 'exit-to-norm') && had_cmd
	call feedkeys("\<C-U>\<BS>","n")
    endif

endfunction
" }}}
" FUNCTION: UserMenu_InitFT() {{{
" A function that's called when a new buffor is created.
func! UserMenu_InitBufAdd() 
    let b:user_menu_cmode_cmd = ""
    let s:current_menu = {}
    let s:current_menu[bufnr()] = []
endfunc
" }}}
" FUNCTION: UserMenu_EnsureInit() {{{
func! UserMenu_EnsureInit()
    if !exists("b:user_menu_cmode_cmd")
        2PRINT No \b:var detected °° calling: °° « \UserMenu_InitBufAdd() » …
        call UserMenu_InitBufAdd()
        return 0
    endif
    return 1
endfunc
" }}}
" FUNCTION: UserMenu_InitFileType() {{{
" A funcion that's called when the buffer is loaded.
func! UserMenu_InitFileType()
    call UserMenu_InitBufAdd()
endfunc
" }}}

"""""""""""""""""" HELPER FUNCTIONS {{{

" FUNCTION: UserMenu_DeployUserMessage() {{{
func! UserMenu_DeployUserMessage(dict,key,init,...)
    if a:init > 0
        let [s:msgs, s:msg_idx] = [ [], 0 ]
        let [s:pauses, s:pause_idx] = [ [], 0 ]
    endif
    if has_key(a:dict,a:key) 
        let [s:pause,s:msg] = UserMenu_GetPrefixValue('p%[ause]',a:dict[a:key])
        if a:init >= 0
            call add(s:msgs, s:msg)
            call add(s:pauses, s:pause)
            call add(s:timers, timer_start(a:0 ? a:1 : 150, function("s:deferedUserMessage")))
        else
            7PRINT UserMenu_ExpandVars(s:msg)
            redraw
            if s:pause =~ '\v^\d+$' && s:pause > 0
                call UserMenu_PauseAllTimers(1, s:pause * 1000 + 40)
                exe "sleep" s:pause
            endif
        endif
    endif
endfunc
" }}}
" FUNCTION: UserMenu_KeyFilter() {{{
func! UserMenu_KeyFilter(id,key)
    redraw
    let s:tryb = UserMenu_BufOrSesVar("user_menu_init_cmd_mode")
    let s:key = a:key
    if mode() =~# '\v^c[ve]=' | call add(s:timers, timer_start(250, function("s:redraw"))) | endif
    if s:tryb > 0
        if a:key == "\<CR>"
            call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode", 0)
            3PRINT mode() ←←← <CR> →→→ end-passthrough ··· user_menu_init_cmd_mode s:tryb ···
        elseif UserMenu_BufOrSesVar("user_menu_init_cmd_mode_once") == "once"
            call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode_once", "already-ran")
            3PRINT mode() ←←← s:key →→→ echo/fake-cmd-line ··· user_menu_init_cmd_mode s:tryb ···
            PRINT Setting command line to •→ appear ←• as: UserMenu_BufOrSesVar('user_menu_cmode_cmd')
            call feedkeys("\<CR>","n")
        else
            3PRINT mode() ←←← s:key →→→ passthrough…… ··· user_menu_init_cmd_mode s:tryb ···
        endif
        " Don't consume the key – pass it through, unless it's <Up>.
        redraw
        return (a:key == "\<Up>") ? popup_filter_menu(a:id, a:key) : 0
    else
        let s:result = popup_filter_menu(a:id, a:key)
        3PRINT mode() ←←← s:key →→→ filtering-path °°° user_menu_init_cmd_mode
                    \ s:tryb °°° ret ((mode()=~#'\v^c[ve]=') ? 'forced-1' : s:result) °°°
        redraw
        return (mode() =~# '\v^c[ve]=') ? 1 : s:result
    endif
endfunc " }}}
" FUNCTION: s:msg(hl,...) {{{
" 0 - error         LLEV=0 will show only them
" 1 - warning       LLEV=1
" 2 - info          …
" 3 - notice        …
" 4 - debug         …
" 5 - debug2        …
func! s:msg(hl, ...)
    " Log only warnings and errors by default.
    if a:hl != 7 && a:hl > get(g:,'user_menu_log_level', 1) || a:0 == 0
        return
    endif

    " Make a copy of the input.
    let args = deepcopy(type(a:000[0]) == 3 ? a:000[0] : a:000)
    if a:hl == 7 | let args = args[1:] | endif
    let hl = a:hl == 7 ? 4 : a:hl

    " Expand any variables and concatenate separated atoms wrapped in parens.
    let start_idx = -1
    let new_args = []
    for idx in range(len(args))
        let arg = args[idx]
        " Unclosed paren?
        " Discriminate two special cases: (mode() and (mode(sub())
        if arg =~# '\v^\(.*([^)]|\([^)]*\)|\([^(]*\([^)]*\)[^)]*\))$'
            let start_idx = idx
        " A free, closing paren?
        elseif start_idx >= 0 && arg =~# '\v^[^(].*\)$' && arg !~ '\v\([^)]*\)$'
            call add(new_args,eval(join(args[start_idx:idx])))
            let start_idx = -1
            continue
        endif
    
        if start_idx == -1
            " A variable?
            if arg =~# '\v^\s*[sgb]:[a-zA-Z_][a-zA-Z0-9_]*\s*$'
                let arg = eval(arg)
            " A function call or an expression wrapped in parens?
            elseif arg =~# '\v^\s*([a-zA-Z_][a-zA-Z0-9_-]*)=\s*\(.*\)\s*$'
                let arg = eval(arg)
            " A \-quoted atom?
            elseif arg[0] == '\'
                let arg = arg[1:]
            endif

            " Store/save the element.
            call add(new_args, arg)
        endif
    endfor
    let args = new_args

    " Finally: detect any hl:…: prefix, select the color, output the message.
    let c = ["Error", "WarningMsg", "um_gold", "um_green3", "um_blue", "None"]
    let mres = matchlist(args[0],'\v^hl:([^:]+):(.*)$')
    let [hl,a1] = !empty(mres) ? [ (mres[1] =~# '^\d\+$' ? c[mres[1]] : mres[1]), mres[2] ]
                \ : [ c[hl], args[0] ]
    let hl = (hl !~# '\v^(\d+|um_[a-z0-9]+|WarningMsg|Error)$') ? 'um_'.hl : hl
    exe 'echohl ' . hl
    echom join( Flatten( ( len(args) > 1 ) ? [a1,args[1:]] : [a1]) )
    echohl None 
endfunc
" }}}
" FUNCTION: s:msgcmdimpl(hl,...) {{{
func! s:msgcmdimpl(hl, bang, linenum, ...)
    let hl = !empty(a:bang) ? 0 : a:hl
    call s:msg(hl, extend(["[".a:linenum."]"], a:000))
endfunc
" }}}
" FUNCTION: s:redraw(timer) {{{
func! s:redraw(timer)
    call filter( s:timers, 'v:val != a:timer' )
    6PRINT △ redraw called △
    redraw
endfunc
" }}}
" FUNCTION: s:deferedMenuStart(timer) {{{
func! s:deferedMenuStart(timer)
    call filter( s:timers, 'v:val != a:timer' )
    call UserMenu_Start()
    echohl um_lyellow
    echom "Opened again the menu."
    echohl None
    redraw
endfunc
" }}}
" FUNCTION: s:deferedUserMessage(timer) {{{
func! s:deferedUserMessage(timer)
    call filter( s:timers, 'v:val != a:timer' )
    7PRINT UserMenu_ExpandVars(s:msgs[s:msg_idx])
    let pause = s:pauses[s:pause_idx]
    let [s:msg_idx, s:pause_idx] = [s:msg_idx+1, s:pause_idx+1]
    redraw
    if pause =~ '\v^\d+$' && pause > 0
        call UserMenu_PauseAllTimers(1, pause * 1000 + 10)
        exe "sleep" pause
    endif
endfunc
" }}}
" FUNCTION: UserMenu_BufOrSesVar() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_BufOrSesVar(var_to_read,...)
    let s:tmp = a:var_to_read
    if exists("s:" . a:var_to_read)
        return get( s:, a:var_to_read, a:0 ? a:1 : '' )
    elseif exists("b:" . a:var_to_read)
        return get( b:, a:var_to_read, a:0 ? a:1 : '' )
    else
        6PRINT ·• Warning «Get…» •· →→ non-existent parameter given: ° s:tmp °
        return a:0 ? a:1 : ''
    endif
endfunc
" }}}
" FUNCTION: UserMenu_CleanupSesVars() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_CleanupSesVars()
    if has_key(s:,'user_menu_init_cmd_mode')
        call remove(s:,'user_menu_init_cmd_mode')
    endif
    if has_key(s:,'user_menu_init_cmd_mode_once')
        call remove(s:,'user_menu_init_cmd_mode_once')
    endif
    if has_key(s:,'user_menu_cmode_cmd')
        call remove(s:,'user_menu_cmode_cmd')
    endif
endfunc
" }}}
" FUNCTION: UserMenu_BufOrSesVarSet() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_BufOrSesVarSet(var_to_set, value_to_set)
    let s:tmp = a:var_to_set
    if exists("s:" . a:var_to_set)
        let s:[a:var_to_set] = a:value_to_set
    else
        if exists("b:" . a:var_to_set)
            let b:[a:var_to_set] = a:value_to_set
            return 1
        else
            6PRINT ·• Warning «Set…» •· →→ non-existent parameter given: ° s:tmp °
            let b:[a:var_to_set] = a:value_to_set
            if exists("b:" . a:var_to_set)
                let b:[a:var_to_set] = a:value_to_set
                return 1
            else
                let s:[a:var_to_set] = a:value_to_set
                return 0
            endif
        endif
    endif
endfunc
" }}}
" FUNCTION: UserMenu_ExpandVars {{{
func! UserMenu_ExpandVars(text)
    return substitute(a:text, '\v\{([sgb]\:[a-zA-Z_][a-zA-Z0-9_]*)\}', '\=eval(submatch(1))', '')
endfunc
" }}}
" FUNCTION: UserMenu_GetPrefixValue(pfx,msg) {{{
func! UserMenu_GetPrefixValue(pfx,msg)
    let mres = matchlist(a:msg,'\v^'.a:pfx.':([^:]*):(.*)$')
    return empty(mres) ? [a:msg,0] : mres[1:2]
endfunc
" }}}
" FUNCTION: UserMenu_RestoreCmdLineFrom() {{{
func! UserMenu_RestoreCmdLineFrom(cmds)
    call feedkeys(a:cmds,"n")
endfunc
" }}}

" FUNCTION: UserMenu_PauseAllTimers() {{{
func! UserMenu_PauseAllTimers(pause,time)
    for t in s:timers
        call timer_pause(t,a:pause)
    endfor

    if a:pause && a:time > 0
        " Limit the amount of time of the pause.
        call add(s:timers, timer_start(a:time, function("UserMenu_UnPauseAllTimersCallback")))
    endif
endfunc
" }}}

" FUNCTION: UserMenu_UnPauseAllTimersCallback() {{{
func! UserMenu_UnPauseAllTimersCallback(timer)
    call filter( s:timers, 'v:val != a:timer' )
    for t in s:timers
        call timer_pause(t,0)
    endfor
endfunc
" }}}

"""""""""""""""""" THE END OF THE HELPER FUNCTIONS }}}

"""""""""""""""""" UTILITY FUNCTIONS {{{

func! Flatten(list)
    let new_list = []
    for el in a:list
        if type(el) == 3
            call extend(new_list, el)
        else
            call add(new_list, el)
        endif
    endfor
    return new_list
endfunc

func! Mapped(fn, l)
    let new_list = deepcopy(a:l)
    call map(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunc

func! Filtered(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunc

func! FilteredNot(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, '!'.string(a:fn) . '(v:val)')
    return new_list
endfunc

func! CreateEmptyList(name)
    eval("let ".a:name." = []")
endfunc

"""""""""""""""""" THE END OF THE UTILITY FUNCTIONS }}}

"""""""""""""""""" THE SCRIPT BODY {{{

augroup UserMenu_InitGroup
    au!
    au BufAdd * call UserMenu_InitBufAdd()
    au BufRead * call UserMenu_InitFileType()
augroup END

inoremap <expr> <F12> UserMenu_Start()
nnoremap <expr> <F12> UserMenu_Start()
vnoremap <expr> <F12> UserMenu_Start()
cnoremap <F12> <C-\>eUserMenu_Start()<CR>
" Following doesn't work as expected…'
onoremap <expr> <F12> UserMenu_Start()
command! -nargs=+ -count=4 -bang -bar PRINT call s:msgcmdimpl(<count>,<q-bang>,expand("<sflnum>"),<f-args>)
hi def um_norm ctermfg=7
hi def um_blue ctermfg=27
hi def um_blue1 ctermfg=32
hi def um_blue2 ctermfg=75
hi def um_lblue ctermfg=50
hi def um_lblue2 ctermfg=75 cterm=bold
hi def um_orange ctermfg=172
hi def um_gold ctermfg=220
hi def um_yellow ctermfg=190
hi def um_lyellow ctermfg=yellow cterm=bold
hi def um_lyellow2 ctermfg=221
hi def um_lyellow3 ctermfg=226
hi def um_green ctermfg=green
hi def um_lgreen ctermfg=lightgreen
hi def um_green2 ctermfg=35
hi def um_lgreen2 ctermfg=82
hi def um_green3 ctermfg=40
hi def um_orange ctermfg=172
hi def UMPmenu ctermfg=220 ctermbg=darkblue
hi PopupSelected ctermfg=220 ctermbg=blue
hi PmenuSel ctermfg=220 ctermbg=blue

let s:timers = []
let s:default_user_menu = [
            \ [ "° Save [insert]",
                       \ #{ type: 'expr', body: 'UserMenu_SaveFile()',
                            \ opts: "only-in-insert", message: "hl:2:File {g:save_result}" } ],
            \ [ "° Toggle completion mode ≈ {g:vichord_search_in_let} ≈ ",
                        \ #{ type: 'expr', body: 'extend(g:, #{ vichord_search_in_let :
                            \ !g:vichord_search_in_let })', opts: "only-in-normal keep-menu-open",
                            \ message: "p:2:hl:lblue2:Current state: {g:vichord_search_in_let}." } ],
            \ [ "° Open [Exp,vis]…",
                        \ #{ type: 'cmds', body: 'Ex', opts: "only-in-visual"} ],
            \ [ "° Other… [Exp,s-msg]",
                        \ #{ type: 'cmds', body: 'Ex', opts: "always-show",
                            \ smessage: "p:2:hl:lblue2:Launching file explorer… In 2 seconds…",
                            \ message: "p:2:hl:gold:Explorer started correctly."} ],
            \ [ "° SomeExp [exit-ex,keep]",
                        \ #{ type: 'cmds', body: 'Ex', opts: "exit-to-norm keep-menu-open"} ],
            \ [ "° NEW [type:norm,exit-ex]",
                        \ #{ type: 'norm', body: "\<C-W>n", opts: "exit-to-norm",
                            \ message: "p:4:hl:2:New buffer created."} ],
            \ [ "° NEW [type:keys,keep,msg]",
                        \ #{ type: 'keys', body: "\<C-bslash>\<C-N>\<C-W>n", 
                            \ message: "p:4:hl:2:New buffer created.", opts: "keep-menu-open"} ],
            \ [ "° Upcase Letters",
                        \ #{ type: 'norm', body: "U", opts: "only-in-visual",
                            \ smessage:"p:3:All selected letters will soon be upcase…",
                            \ message:"p:3:All selected letters are now upcase."} ],
            \ [ "° Escape The Command Line",
                        \ #{ type: 'keys', body: "\<C-bslash>eescape(getcmdline(), ' \\')\<CR>",
                            \ opts: ['only-in-ex'] } ]
            \ ]

"""""""""""""""""" THE END OF THE SCRIPT BODY }}}

"""""""""""""""""" EXPERIMENTAL FUNCTIONS

" FUNCTION: UserMenu_SaveFile()
func! UserMenu_SaveFile()
    let s:save_buf = bufnr()
    let s:prompt_buf = bufadd('SaveFile')
    call feedkeys("\<C-w>n", "n")
    call bufload(s:prompt_buf)
    set bt=prompt
    call prompt_setcallback(s:prompt_buf, function('s:UserMenu_SaveFileCallback'))
    startinsert
endfunc
" }}}
func! s:UserMenu_SaveFileCallback(text)
    if a:text =~ '\v^\s*$'
        call append(line('$') - 1, 'Please enter a file path to which to save the bufer.')
        startinsert
    else
        call feedkeys("\<C-w>w", "n")
        exe 'w!' a:text
        call feedkeys("\<C-w>w", "n")
        call append(line('$') - 1, 'Stored under: "' . a:text . '"')
        " Reset 'modified' to allow the buffer to be closed.
        set nomodified
        let s:buf_to_close = s:prompt_buf
        call add(s:timers, timer_start(2000, function("s:SaveFile_CloseBufferCallback")))
    endif
endfunc

func! s:UserMenu_CloseBufferCallback(timer)
    call filter( s:timers, 'v:val != a:timer' )
    exe 'bw!' s:buf_to_close
endfunc

" vim:set ft=vim tw=80 et sw=4 sts=4 foldmethod=marker:
