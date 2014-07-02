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
      \ 'description': 'post a selected files to create a new gist',
      \}
function! s:post_to_gist.func(candidates) abort " {{{
  let unreadables = []
  let filenames = []
  let contents = []
  let i = 1
  for candidate in a:candidates
    redraw | echo 'Constructing a gist to post ...' i . '/' . len(a:candidates)
    let path = candidate.action__path
    let filename = fnamemodify(path, ':t')
    let basename = fnamemodify(filename, ':r')
    let extension = fnamemodify(filename, ':e')
    if !filereadable(path)
      call add(unreadables, path)
      continue
    endif
    " find usable filename
    let j = 1
    while index(filenames, filename) > -1
      let filename = printf("%s-%d.%s", basename, j, extension)
      let j += 1
    endwhile
    call add(filenames, filename)
    call add(contents, join(readfile(path), "\n"))
    let i += 1
  endfor
  call gista#gist#api#post(filenames, contents)
  if len(unreadables) > 0
    echohl GistaWarning
    echo 'Skipped files'
    echohl None
    echo 'The following file could not be loaded thus not posted.'
    for path in unreadables
      echo '-' path
    endfor
  endif
endfunction " }}}

function! unite#kinds#file_post_to_gist#define() " {{{
  return {}
endfunction " }}}
call unite#custom#action('file', 'post_to_gist', s:post_to_gist)

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
