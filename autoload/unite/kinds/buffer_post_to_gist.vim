"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:post_to_gist = {
      \ 'is_selectable': 1,
      \ 'description': 'post a selected buffers to create a new gist',
      \}
function! s:post_to_gist.func(candidates) abort " {{{
  let filenames = []
  let contents = []
  let cbufnum = bufnr(expand('%'))
  let index = 1
  for candidate in a:candidates
    redraw | echo 'Constructing a gist to post ...' index . '/' . len(a:candidates)
    let bufnum = candidate.action__buffer_nr
    " change the buffer to <bufnum>
    execute bufnum . 'buffer'
    call add(contents, join(getline(1, line('$')), "\n"))
    call add(filenames,
          \ gista#utils#provide_filename(expand('%:t'), index))
    let index += 1
  endfor
  execute cbufnum . 'buffer'
  call gista#gist#api#post(filenames, contents)
endfunction " }}}

function! unite#kinds#buffer_post_to_gist#define() " {{{
  return {}
endfunction " }}}
call unite#custom#action('buffer', 'post_to_gist', s:post_to_gist)

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
