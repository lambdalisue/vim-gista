let s:save_cpo = &cpo
set cpo&vim

function! s:on_SourceCmd(gistid, filename) abort " {{{
  let content = getbufline(expand('<amatch>'), 1, '$')
  try
    let tempfile = tempname()
    call writefile(content, tempfile)
    execute printf('source %s', tempfile)
  finally
    if filereadable(tempfile)
      call delete(tempfile)
    endif
  endtry
endfunction " }}}
function! s:on_BufReadCmd(gistid, filename) abort " {{{
  call gista#command#open#edit({
        \ 'gistid': a:gistid,
        \ 'filename': a:filename,
        \ 'fresh': v:cmdbang,
        \ 'opener': 'inplace',
        \})
endfunction " }}}
function! s:on_FileReadCmd(gistid, filename) abort " {{{
  call gista#command#open#read({
        \ 'gistid': a:gistid,
        \ 'filename': a:filename,
        \ 'fresh': v:cmdbang,
        \})
endfunction " }}}

function! s:on_BufWriteCmd(gistid, filename) abort " {{{
  let content = getbufline(expand('<amatch>'), 1, '$')
  if g:gista#autocmd#patch_on_write || v:cmdbang
    call gista#command#patch#call({
          \ 'gistid': a:gistid,
          \ 'filenames': [a:filename],
          \ 'contents': [content],
          \})
    setlocal nomodified
  else
    let client = gista#api#get_current_client()
    let gist = client.content_cache.get(a:gistid, {})
    if empty(gist)
      call gista#util#prompt#warn(
            \ 'Use ":w!" to patch the content to API.',
            \ 'See ":h g:gista#autoload#patch_on_write" if you prefer to patch',
            \ 'a content on ":w" command',
            \)
    else
      call extend(gist.files[a:filename], {
            \ 'content': content,
            \})
      call client.content_cache.set(
            \ a:gistid, 
            \ gista#gist#mark_modified(gist),
            \)
      call gista#gist#apply_to_entry_cache(
            \ client, a:gistid,
            \ function('gista#gist#mark_modified'),
            \)
      call gista#command#list#update_if_necessary()
      call gista#util#prompt#warn(
            \ 'The content is saved on a corresponding cache.',
            \ 'Use ":w!" to patch the content to API as well.',
            \ 'See ":h g:gista#autoload#patch_on_write" if you prefer to patch',
            \ 'a content on ":w" command',
            \)
      setlocal nomodified
    endif
  endif
endfunction " }}}
function! s:on_FileWriteCmd(gistid, filename) abort " {{{
  let content = getbufline(expand('<amatch>'), line("'["), line("']"))
  if g:gista#autocmd#patch_on_write || v:cmdbang
    call gista#command#patch#call({
          \ 'gistid': a:gistid,
          \ 'filenames': [a:filename],
          \ 'contents': [content],
          \})
  else
    let client = gista#api#get_current_client()
    let gist = client.content_cache.get(a:gistid, {})
    if empty(gist)
      call gista#util#prompt#warn(
            \ 'Use ":w!" to post the content to API.',
            \ 'See ":h g:gista#autoload#patch_on_write" if you prefer to patch',
            \ 'a content on ":w" command',
            \)
    else
      call extend(gist.files[a:filename], {
            \ 'content': content,
            \})
      call client.content_cache.set(
            \ a:gistid, 
            \ gista#gist#mark_modified(gist),
            \)
      call gista#gist#apply_to_entry_cache(
            \ client, a:gistid,
            \ function('gista#gist#mark_modified'),
            \)
      call gista#util#prompt#warn(
            \ 'The content is saved on a corresponding cache.',
            \ 'Use ":w!" to post the content to API as well.',
            \ 'See ":h g:gista#autoload#patch_on_write" if you prefer to patch',
            \ 'a content on ":w" command',
            \)
    endif
  endif
endfunction " }}}

function! gista#autocmd#call(name) abort " {{{
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call gista#util#prompt#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  let meta = gista#gist#get_meta('<afile>')
  if empty(meta)
    return
  endif
  try
    call gista#api#session_enter({
          \ 'apiname': meta.apiname,
          \ 'username': get(meta, 'username', 0),
          \})
    call call(fname, [meta.gistid, meta.filename])
  finally
    call gista#api#session_exit()
  endtry
endfunction " }}}

" Configure variables
call gista#define_variables('autocmd', {
      \ 'patch_on_write': 0,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
