" yankstack.vim - keep track of your history of yanked/killed text
"
" Maintainer:   Max Brunsfeld <https://github.com/maxbrunsfeld>
" Version:      1.0
" Todo:
"
" - make :Yanks command display number of lines in yank
"
" - investigate whether an s: variable is the best way to
"   scope the yankstack_tail
"
" - support repeat.vim
"

let s:yankstack_tail = []
let g:yankstack_size = 30
let s:last_paste = { 'changedtick': -1, 'key': '', 'mode': 'normal' }
call yankstack#setup()

function! s:yank_with_key(key)
  call s:yankstack_before_add()
  return a:key
endfunction

function! s:paste_with_key(key, mode)
  if a:mode == 'visual'
    call s:yankstack_before_add()
    call s:yankstack_rotate(1)
  endif
  let s:last_paste = { 'changedtick': b:changedtick+1, 'key': a:key, 'mode': a:mode }
  return a:key
endfunction

function! s:substitute_paste(offset)
  if b:changedtick != s:last_paste.changedtick
    echo 'Last change was not a paste'
    return
  endif
  silent undo
  call s:yankstack_rotate(a:offset)
  call s:paste_from_yankstack()
endfunction

function! s:yankstack_before_add()
  let head = s:get_yankstack_head()
  if !empty(head.text) && (empty(s:yankstack_tail) || (head != s:yankstack_tail[0]))
    call insert(s:yankstack_tail, head)
    let s:yankstack_tail = s:yankstack_tail[: g:yankstack_size]
  endif
endfunction

function! s:yankstack_rotate(offset)
  if empty(s:yankstack_tail) | return | endif
  let offset_left = a:offset
  while offset_left != 0
    let head = s:get_yankstack_head()
    if offset_left > 0
      let entry = remove(s:yankstack_tail, 0)
      call add(s:yankstack_tail, head)
      let offset_left -= 1
    elseif offset_left < 0
      let entry = remove(s:yankstack_tail, -1)
      call insert(s:yankstack_tail, head)
      let offset_left += 1
    endif
    call s:set_yankstack_head(entry)
  endwhile
endfunction

function! s:paste_from_yankstack()
  let [&autoindent, save_autoindent] = [0, &autoindent]
  let s:last_paste.changedtick = b:changedtick+1
  if s:last_paste.mode == 'insert'
    silent exec 'normal! a' . s:last_paste.key
  elseif s:last_paste.mode == 'visual'
    let head = s:get_yankstack_head()
    silent exec 'normal! gv' . s:last_paste.key
    call s:set_yankstack_head(head)
  else
    silent exec 'normal!' s:last_paste.key
  endif
  let &autoindent = save_autoindent
endfunction

function! s:get_yankstack_head()
  return { 'text': getreg('"'), 'type': getregtype('"') }
endfunction

function! s:set_yankstack_head(entry)
  call setreg('"', a:entry.text, a:entry.type)
endfunction

function! s:show_yanks()
  echohl WarningMsg | echo "--- Yanks ---" | echohl None
  let i = 0
  for yank in [s:get_yankstack_head()] + s:yankstack_tail
    let i += 1
    echo s:format_yank(yank.text, i)
  endfor
endfunction
command! -nargs=0 Yanks call s:show_yanks()

function! s:format_yank(yank, i)
  let line = printf("%-4d %s", a:i, a:yank)
  return split(line, '\n')[0][: 80]
endfunction

function! s:define_mappings()
  let yank_keys  = ['x', 'y', 'd', 'c', 'X', 'Y', 'D', 'C', 'p', 'P']
  let paste_keys = ['p', 'P']
  for key in yank_keys
    exec 'nnoremap <expr> <Plug>yankstack_' . key '<SID>yank_with_key("' . key . '")'
    exec 'xnoremap <expr> <Plug>yankstack_' . key '<SID>yank_with_key("' . key . '")'
  endfor
  for key in paste_keys
    exec 'nnoremap <expr> <Plug>yankstack_' . key '<SID>paste_with_key("' . key . '", "normal")'
    exec 'xnoremap <expr> <Plug>yankstack_' . key '<SID>paste_with_key("' . key . '", "visual")'
  endfor

  nnoremap <silent> <Plug>yankstack_substitute_older_paste  :<C-u>call <SID>substitute_paste(v:count1)<CR>
  nnoremap <silent> <Plug>yankstack_substitute_newer_paste  :<C-u>call <SID>substitute_paste(-v:count1)<CR>
  inoremap <silent> <Plug>yankstack_substitute_older_paste  <C-o>:<C-u>call <SID>substitute_paste(v:count1)<CR>
  inoremap <silent> <Plug>yankstack_substitute_newer_paste  <C-o>:<C-u>call <SID>substitute_paste(-v:count1)<CR>
  inoremap <expr>   <Plug>yankstack_insert_mode_paste       <SID>paste_with_key('<C-g>u<C-r>"', 'insert')
endfunction
call s:define_mappings()

if !exists('g:yankstack_map_keys') || g:yankstack_map_keys
  nmap [p    <Plug>yankstack_substitute_older_paste
  nmap ]p    <Plug>yankstack_substitute_newer_paste
  imap <M-y> <Plug>yankstack_substitute_older_paste
  imap <M-Y> <Plug>yankstack_substitute_newer_paste
  imap <C-y> <Plug>yankstack_insert_mode_paste
endif

