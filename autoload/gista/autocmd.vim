let s:save_cpo = &cpo
set cpo&vim

function! s:on_BufReadCmd(apiname, gistid, filename) abort " {{{
  silent doautocmd BufReadPre
  call gista#command#read#edit({
        \ 'apiname': a:apiname,
        \ 'gistid': a:gistid,
        \ 'filename': a:filename,
        \ 'fresh': v:cmdbang,
        \ 'opener': 'inplace',
        \})
  silent doautocmd BufReadPost
endfunction " }}}
function! s:on_FileReadCmd(apiname, gistid, filename) abort " {{{
  doautocmd FileReadPre
  call gista#command#read#read({
        \ 'apiname': a:apiname,
        \ 'gistid': a:gistid,
        \ 'filename': a:filename,
        \ 'fresh': v:cmdbang,
        \})
  doautocmd FileReadPost
endfunction " }}}
function! s:on_BufWriteCmd(apiname, gistid, filename) abort " {{{
  silent doautocmd BufWritePre
  if v:cmdbang
    call gista#command#patch#call({
          \ 'apiname': a:apiname,
          \ 'gistid': a:gistid,
          \ 'filename': a:filename,
          \})
  else
    " Save a current content into a corresponding cache
    let client = gista#api#client({ 'apiname': a:apiname })
    if client.content_cache.has(a:gistid)
      let cached_content = client.content_cache.get(a:gistid)
      call extend(cached_content, { '_gista_modified': 1 })
      call extend(cached_content.files[a:filename], {
            \ 'content': getbufline(bufnr('<afile>'), 1, '$'),
            \})
      call gista#gist#update_entry_cache(
            \ client,
            \ client.get_authorized_username(),
            \ cached_content,
            \)
      call gista#gist#update_entry_cache(
            \ client,
            \ client.get_authorized_username() . '/starred',
            \ cached_content,
            \)
      call gista#util#prompt#warn(
            \ 'The content is saved to a corresponding cache only.',
            \ 'Use ":w!" to patch the content to API as well.',
            \)
    else
      call gista#util#prompt#warn(
            \ 'Use ":w!" to patch the content to API.',
            \)
    endif
  endif
  silent doautocmd BufWritePost
endfunction " }}}
function! s:on_FileWriteCmd(apiname, gistid, filename) abort " {{{
  doautocmd FileWritePre
  if v:cmdbang
    call gista#command#patch#call({
          \ 'apiname': a:apiname,
          \ 'gistid': a:gistid,
          \ 'filename': a:filename,
          \})
  else
    " Save a current content into a corresponding cache
    let client = gista#api#client({ 'apiname': a:apiname })
    if client.content_cache.has(a:gistid)
      let cached_content = client.content_cache.get(a:gistid)
      call extend(cached_content.files[a:filename], {
            \ 'content': getbufline(bufnr('<afile>'), 1, '$'),
            \})
      call gista#gist#update_entry_cache(
            \ client,
            \ client.get_authorized_username(),
            \ cached_content,
            \)
      call gista#gist#update_entry_cache(
            \ client,
            \ client.get_authorized_username() . '/starred',
            \ cached_content,
            \)
      call gista#util#prompt#warn(
            \ 'The content is saved to a corresponding cache only.',
            \ 'Use ":w!" to patch the content to API as well.',
            \)
    else
      call gista#util#prompt#warn(
            \ 'Use ":w!" to patch the content to API.',
            \)
    endif
  endif
  doautocmd FileWritePost
endfunction " }}}

function! gista#autocmd#call(name) abort " {{{
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    throw printf('vim-gista: No autocmd function "%s" is found.', fname)
  endif
  let meta = gista#gist#get_meta('<afile>')
  if empty(meta)
    return
  endif
  call call(fname, [meta.apiname, meta.gistid, meta.filename])
endfunction " }}}


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
