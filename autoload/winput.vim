"=============================================================================
" vim-winput - Open a window to input text and use it how you want
" Copyright (c) 2013 Scheakur <http://scheakur.com/>
" License: MIT license
"=============================================================================

function! winput#open(name, func, ...)
	let opts = (a:0 > 0) ? get(a:000, '0', {}) : {}
	call s:open(a:name, a:func, opts)
endfunction


function! winput#escape(text)
	let escaped = substitute(a:text, '"', '\\"', 'g')
	return '"' . escaped . '"'
endfunction

let s:buf_nr = {}
let s:buf_nr_min = 0
let s:buf_nr_base = {}


function! s:open(name, func, opts)
	let buf_nr = s:get_buf_nr(a:name)
	let win_height = get(a:opts, 'win_height', 5)

	call s:open_window(a:name, buf_nr, win_height)
	call s:setup_buffer(a:name)
	call s:setup_commands_and_keys(a:name, a:func,
	\	get(a:opts, 'on_validate', function('s:no_validate')))

	call get(a:opts, 'on_open', function('s:nop'))()

	redraw!
endfunction


function! s:nop(...)
	" No operation
endfunction


function! s:no_validate(...)
	return [1, ""]
endfunction


function! s:get_buf_nr(name)
	if !has_key(s:buf_nr_base, a:name)
		let s:buf_nr_min -= 1
		let s:buf_nr_base[a:name] = s:buf_nr_min
		let s:buf_nr[a:name] = s:buf_nr_min
	endif

	return s:buf_nr[a:name]
endfunction


function! s:open_window(name, buf_nr, height)
	if !bufexists(a:buf_nr)
		execute 'belowright' a:height . 'new'
		file `="[" . a:name . "]"`
		let s:buf_nr[a:name] = bufnr('%')
		call feedkeys('i', 'n')
		return
	endif

	if bufwinnr(a:buf_nr) == -1
		execute 'belowright' a:height . 'split'
		execute a:buf_nr . 'buffer'
		call feedkeys('i', 'n')
		return
	endif

	if bufwinnr(a:buf_nr) != bufwinnr('%')
		execute bufwinnr(a:buf_nr) . 'wincmd w'
		return
	endif
endfunction


function! s:setup_buffer(name)
	execute 'setlocal filetype=' . a:name
	setlocal bufhidden=delete
	setlocal buftype=nofile
	setlocal noswapfile
	setlocal nobuflisted
	setlocal modifiable
endfunction


function! s:setup_commands_and_keys(name, func, validate)
	let set_command = printf(
	\	'command! -buffer -nargs=0 Write  call s:write("%s", %s, %s)',
	\	a:name, string(a:func), string(a:validate))

	execute set_command

	nnoremap <buffer> <silent> <C-CR>  :Write<CR>
	inoremap <buffer> <silent> <C-CR>  <ESC>:Write<CR>
	nnoremap <buffer> q  <C-w>c

	let reset_buf_nr = printf(
	\	'autocmd BufHidden <buffer>  let <SID>buf_nr["%s"] = <SID>buf_nr_base["%s"]',
	\	a:name, a:name)

	execute reset_buf_nr
endfunction


function! s:write(name, func, validate)
	let text = join(getbufline('%', 1, '$'), "\n")
	" remove trailing line breaks
	let text = substitute(text, '\n\+$', '', '')

	let [ok, msg] = a:validate(text)

	if !ok
		echohl WarningMsg
		echomsg msg
		echohl None
		return
	endif

	call a:func(text)
	call s:after_write(a:name)
endfunction


function! s:after_write(name)
	let on_write = get(g:, 'winput_on_write#' . a:name, 'close')

	if on_write ==# 'clear'
		call feedkeys('ggdG', 'n')
	else
		call feedkeys("\<C-w>c", 'n')
	endif
endfunction
