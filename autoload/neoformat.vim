function! neoformat#Start(user_formatter)
    let s:current_formatter_index = 0
    call neoformat#Neoformat(a:user_formatter)
endfunction

function! neoformat#Neoformat(user_formatter) abort
    let s:vim_jobcontrol = !has('nvim') && has('job') && has('patch-7-4-1590')
    if !(has('nvim') || s:vim_jobcontrol)
        return neoformat#utils#warn('Neovim, or Vim with job control, is currently required to run this plugin')
    endif

    if !empty(a:user_formatter)
        let formatter = a:user_formatter
    else
        let filetype = s:split_filetypes(&filetype)
        let formatters = s:get_enabled_formatters(filetype)
        if formatters == []
            call neoformat#utils#msg('formatter not defined for ' . filetype . ' filetype')
            return neoformat#format#BasicFormat()
        endif

        if s:current_formatter_index >= len(formatters)
            call neoformat#utils#msg('attempted all formatters available for current filetype')
            return neoformat#format#BasicFormat()
        endif

        let formatter = formatters[s:current_formatter_index]
    endif

    if exists('g:neoformat_' . filetype . '_' . formatter)
        let definition = g:neoformat_{filetype}_{formatter}
    elseif s:autoload_func_exists('neoformat#formatters#' . filetype . '#' . formatter)
        let definition =  neoformat#formatters#{filetype}#{formatter}()
    else
        call neoformat#utils#log('definition not found for formatter: ' . formatter)
        if !empty(a:user_formatter)
            call neoformat#utils#msg('formatter definition for ' . a:user_formatter . ' not found')
            return neoformat#format#BasicFormat()
        endif
        return neoformat#NextNeoformat()
    endif

    let cmd = neoformat#cmd#generate(definition, filetype)
    if cmd == {}
        if !empty(a:user_formatter)
            return neoformat#utils#log('user specified formatter failed')
        endif
        return neoformat#NextNeoformat()
    endif

    return neoformat#run#Neoformat(cmd)
endfunction

function! s:get_enabled_formatters(filetype) abort
    if exists('g:neoformat_enabled_' . a:filetype)
        return g:neoformat_enabled_{a:filetype}
    elseif s:autoload_func_exists('neoformat#formatters#' . a:filetype . '#enabled')
        return neoformat#formatters#{a:filetype}#enabled()
    endif
    return []
endfunction

function! neoformat#CompleteFormatters(ArgLead, CmdLine, CursorPos)
    if a:ArgLead =~ '[^A-Za-z0-9]'
        return []
    endif
    let filetype = s:split_filetypes(&filetype)
    return filter(s:get_enabled_formatters(filetype),
                \ "v:val =~? '^" . a:ArgLead ."'")
endfunction

function! neoformat#NextNeoformat() abort
    call neoformat#utils#log('trying next formatter')
    let s:current_formatter_index += 1
    return neoformat#Neoformat('')
endfunction

function! s:autoload_func_exists(func_name)
    try
        call eval(a:func_name . '()')
    catch /^Vim\%((\a\+)\)\=:E117/
        return 0
    endtry
    return 1
endfunction

function! s:split_filetypes(filetype)
    if a:filetype == ''
        return ''
    endif
    return split(a:filetype, '\.')[0]
endfunction
