"******************************************************************************
" API User Interface
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:get_buffer_name(...) abort " {{{
  return 'gista' . s:consts.DELIMITER . gista#vital#path_join(a:000)
endfunction " }}}
function! s:get_usable_buffer_name(name) abort " {{{
  if bufnr(a:name) == -1
    return a:name
  endif
  let index = 1
  let basename = fnamemodify(a:name, ':r')
  let extension = fnamemodify(a:name, ':e')
  let name = basename . index . extension
  while bufnr(name) == -1
    let index += 1
    let name = basename . index . extension
  endwhile
  return name
endfunction " }}}
function! s:get_gists() abort " {{{
  if !exists('s:gists')
    let s:gists = {}
  endif
  return s:gists
endfunction " }}}
function! s:get_gist(gistid) abort " {{{
  let gists = s:get_gists()
  if !has_key(gists, a:gistid)
    let res = gista#raw#get(a:gistid)
    if res.status != 200
      redraw
      echohl WarningMsg
      echo res.status . ' ' . res.statusText . '. '
      echohl None
      if has_key(res.content, 'message')
        echo 'Message: "' . res.content.message . '"'
      endif
      return {}
   endif
    let gists[a:gistid] = res.content
  endif
  return gists[a:gistid]
endfunction " }}}
function! s:set_gist(gistid, gist) abort " {{{
  let gists = s:get_gists()
  let gists[a:gistid] = a:gist
endfunction " }}}

function! s:format_gist_title(gist) abort " {{{
  let private_mark = g:gista#private_mark
  let public_mark = g:gista#public_mark
  let gistid = a:gist.id
  let publish_state = a:gist.public ? public_mark : private_mark
  let description = empty(a:gist.description) ? 'No description' : a:gist.description
  return printf("%s %s [%s]", description,publish_state,  gistid)
endfunction " }}}
function! s:format_gist_file(gist, filename) abort " {{{
  return printf("- %s", a:filename)
endfunction " }}}
function! s:open_list(lookup, settings) abort " {{{
  let bufname = s:get_buffer_name('list')
  let lookup = a:lookup
  let settings = extend({
        \ 'page': -1,
        \ 'since': '',
        \ 'recursive': -1,
        \ 'nocache': 0,
        \ 'anonymous': 0,
        \ 'opener': g:gista#list_opener,
        \}, empty(a:settings) ? getbufvar(bufname, 'settings', {}) : a:settings)
  let settings.action_settings = extend({
        \ 'opener': g:gista#gist_opener_in_action,
        \}, get(settings, 'action_settings', {}))
  let bufnum = bufnr(bufname)
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    silent execute 'noautocmd' settings.opener bufname
    if bufnum == -1
      " initialize list window
      let &l:filetype = s:consts.LISTWIN_FILETYPE
      setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
      setlocal nolist nowrap nospell nofoldenable textwidth=0 undolevels=-1
      setlocal colorcolumn=0

      if g:gista#enable_default_keymaps
        nmap <buffer> <C-l>      <Plug>(gista-action-update)
        nmap <buffer> <C-l><C-l> <Plug>(gista-action-update-nocache)
        nmap <buffer> <CR>       <Plug>(gista-action-open)
        nmap <buffer> r          <Plug>(gista-action-rename)
        nmap <buffer> D          <Plug>(gista-action-smart-delete)
        nmap <buffer> +          <Plug>(gista-action-star)
        nmap <buffer> -          <Plug>(gista-action-unstar)
        nmap <buffer> ?          <Plug>(gista-action-is-starred)
        nmap <buffer> F          <Plug>(gista-action-fork)
        nmap <buffer> <S-CR>     <Plug>(gista-action-browse)
      endif

      let b:links = []
      let b:gists = []
    endif
  else
    " focus window
    execute winnum . 'wincmd w'
  endif
  " check if the lookup condition is updated
  let b#lookup = get(b:, 'lookup', '')
  let b#settings = get(b:, 'settings', {})
  let is_condition_updated = (
        \ empty(b#settings) ||
        \ settings.nocache ||
        \ lookup != b#lookup ||
        \ settings.page != b#settings.page ||
        \ settings.recursive != b#settings.recursive ||
        \ settings.anonymous != b#settings.anonymous
        \)
  let b:lookup = lookup
  let b:settings = settings
  if is_condition_updated
    " lookup condition has changed, update is required
    call s:update_list(settings)
  endif
endfunction " }}}
function! s:update_list(settings) abort " {{{
  let bufname = s:get_buffer_name('list')
  return gista#util#call_on_buffer(
        \ bufname,
        \ function("<SID>update_list_buffer"),
        \ a:settings)
endfunction " }}}
function! s:update_list_buffer(settings) abort " {{{
  if !exists('b:lookup') || !exists('b:settings')
    return
  endif
  let lookup = b:lookup
  let settings = extend({
        \ 'page': -1,
        \ 'since': '',
        \ 'recursive': -1,
        \ 'nocache': 0,
        \ 'anonymous': 0,
        \}, empty(a:settings) ? b:settings : a:settings)
  " Download gist list
  let res = gista#raw#gets(lookup, copy(settings))
  if empty(res)
    " Authorization has failed or canceled
    bw!
    return
  elseif res.status != 200
    bw!
    redraw
    echohl WarningMsg
    echo res.status . ' ' . res.statusText . '. '
    echohl None
    if res.status == 404
      echo 'Gists of "' . lookup .'" could not be found. '
    endif
    return
  elseif empty(res.content)
    bw!
    redraw
    echohl WarningMsg
    echo 'No gists matched with "' . lookup .'" are found. '
    echohl None
    return
  endif

  " put gist lines and links
  let gists = copy(res.content)
  let lines = []
  let links = []
  for gist in gists
    call add(lines, s:format_gist_title(gist))
    call add(links, {'gist': gist, 'filename': ''})
    for [key, value] in items(gist.files)
      call add(lines, s:format_gist_file(gist, key))
      call add(links, {'gist': gist, 'filename': key})
    endfor
  endfor
  let b:gists = gists
  let b:links = links

  " remove entire content and rewriet the lines
  setlocal modifiable
  let save_cur = getpos(".")
  silent %delete _
  call setline(1, split(join(lines, "\n"), "\n"))
  call setpos('.', save_cur)
  setlocal nomodifiable
  setlocal nomodified

  " store settings (nocache should not be stored.)
  let b:settings = gista#vital#omit(settings, ['nocache'])

  redraw | echo len(res.loaded_gists) . ' gists are updated.'
endfunction " }}}
function! s:action_list_buffer(action) abort " {{{
  if !exists('b:lookup') || !exists('b:settings')
    return
  endif
  let settings = extend({
        \ 'opener': g:gista#gist_opener_in_action,
        \}, get(b:settings, 'action_settings', {}))

  let cursorline = line('.')
  let link = get(b:links, cursorline - 1, {})
  if empty(link)
    return
  endif

  if a:action == 'update'
    call s:update_list_buffer(b:settings)
  elseif a:action == 'update:nocache'
    call s:update_list_buffer(extend(copy(b:settings), {'nocache': 1}))
  elseif a:action == 'open'
    if empty(link.gist.files)
      redraw
      echohl WarningMsg
      echo  'Gist does not contain files:'
      echohl None
      echo  'No files are contained in the gist. Cannot be opened.'
      return
    endif
    " move the focuse to the previous selected window and open the gist to
    " regulate the position of the new buffer
    silent execute 'wincmd p'
    call s:open_gist(link.gist.id, link.filename, settings)
    if g:gista#close_list_after_open
      " close listwindow and goback to opend window
      let nwinnum = bufwinnr(bufnr('%'))
      let lwinnum = bufwinnr(bufnr(s:get_buffer_name('list')))
      execute lwinnum . 'wincmd w'
      quit
      execute nwinnum . 'wincmd w'
    endif
  elseif a:action == 'rename'
    if empty(link.filename)
      redraw
      echohl WarningMsg
      echo  'Invalid action:'
      echohl None
      echo  'You have to execute "rename" action on the filename'
      return
    endif
    call s:rename_gist(link.gist.id, link.filename, settings)
  elseif a:action == 'remove'
    if empty(link.filename)
      redraw
      echohl WarningMsg
      echo  'Invalid action:'
      echohl None
      echo  'You have to execute "remove" action on the filename. '
      echon 'If you want to delete the gist, use "delete" action.'
      return
    endif
    call s:remove_gist(link.gist.id, link.filename, settings)
  elseif a:action == 'delete'
    if !empty(link.filename)
      redraw
      echohl WarningMsg
      echo  'Invalid action:'
      echohl None
      echo  'You have to execute "delete" action on the gist description. '
      echon 'If you want to remove a particular file, use "remove" action.'
      return
    endif
    call s:delete_gist(link.gist.id, settings)
  elseif a:action == 'smart-delete'
    if empty(link.filename)
      call s:delete_gist(link.gist.id, settings)
    else
      call s:remove_gist(link.gist.id, link.filename, settings)
    endif
  elseif a:action == 'star'
    call s:star_gist(link.gist.id, settings)
  elseif a:action == 'unstar'
    call s:unstar_gist(link.gist.id, settings)
  elseif a:action == 'is-starred'
    call s:is_starred_gist(link.gist.id, settings)
  elseif a:action == 'fork'
    call s:fork_gist(link.gist.id, settings)
  elseif a:action == 'browse'
    call s:browse_gist(link.gist.id, link.filename, settings)
  endif
endfunction " }}}

function! s:open_gist(gistid, filenames, settings) abort " {{{
  let settings = extend({
        \ 'opener': g:gista#gist_opener,
        \}, a:settings)
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    " downloading gist has failed
    return
  endif

  if empty(a:filenames)
    let filenames = keys(gist.files)
  elseif type(a:filenames) == 1 " String
    let filenames = [a:filenames]
  else
    let filenames = a:filenames
  endif

  for filename in filenames
    let bufname = s:get_buffer_name(a:gistid, filename)
    let bufnum = bufnr(bufname)
    let winnum = bufwinnr(bufnum)

    if winnum == -1
      if !has_key(gist.files, filename)
        redraw
        echohl WarningMsg
        echo  'File entry is not found:'
        echohl None
        echo  'An entry of "' . filename . '" is not found in the gist.'
        continue
      endif
      silent execute 'noautocmd' settings.opener bufname
      if bufnum == -1
        let save_undolevels = &undolevels
        setlocal undolevels=-1
        setlocal buftype=acwrite bufhidden=hide noswapfile
        setlocal modifiable

        silent %delete _
        call setline(1, split(gist.files[filename].content, "\n"))

        let &undolevels = save_undolevels
        setlocal nomodified

        " connect the gist
        call s:connect_gist_buffer(gist.id, filename)

        " successfully loaded, call autocmd
        doautocmd StdinReadPost,BufRead,BufReadPost
      endif
    else
      execute winnum . 'wincmd w'
    endif
  endfor
  redraw | echo 'Gist files (' . join(filenames, ', ') . ') are opened.'
endfunction " }}}
function! s:connect_gist_buffer(gistid, filename) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif
  " Connect current buffer to the gist
  let gist.files[a:filename].bufnum = bufnr('%')
  " Keep gistid and filename to the buffer variable
  let b:gistinfo = {
        \ 'gistid': a:gistid,
        \ 'filename': a:filename
        \}
  " is the gist editable?
  if gist.owner.login == gista#raw#get_authenticated_user()
    " user own the gist, modifiable
    setlocal modifiable
    autocmd! BufWriteCmd <buffer>
          \ call s:ac_write_gist_buffer(expand("<amatch>"))
  else
    " non user gist, nomodifiable
    setlocal nomodifiable
    autocmd! BufWriteCmd <buffer>
  endif
endfunction " }}}
function! s:ac_write_gist_buffer(filename) abort " {{{
  " Note: this function is assumed to called from autocmd.
  if substitute(a:filename, '\\', '/', 'g') == expand("%:p:gs@\\@/@")
    if &buftype == ''
      " save the file to the filesystem
      execute "w".(v:cmdbang ? "!" : "") fnameescape(v:cmdarg) fnameescape(a:filename)
    endif
    " upload the change to gist
    if empty(g:gista#update_on_write)
      " do not save the gist on the web
      return
    elseif g:gista#update_on_write == 2 && !v:cmdbang
      echohl Comment
      echo  'Type ":w!" to update the gist or set "let g:gista#update_on_write'
      echon ' = 1" to update the gist everytime when the file is saved.'
      echohl None
    else
      return gista#view#save_buffer({})
    endif
  else
    " new filename is given, save the content with a new filename
    " and stop autocmd, unlink the content from Gist
    execute "file" fnameescape(a:filename)
    call gista#view#disconnect_buffer({'confirm': 0, 'provide_filename': 0})
    execute "w".(v:cmdbang ? "!" : "") fnameescape(v:cmdarg) fnameescape(a:filename)
  endif
endfunction " }}}
function! s:post_gist(bufnums, filenames, contents, settings) abort " {{{
  let settings = extend({
        \ 'description': '',
        \ 'public': -1,
        \ 'interactive_description':  g:gista#interactive_description,
        \ 'interactive_publish_status': g:gista#interactive_publish_status,
        \}, a:settings)

  if settings.interactive_description && empty(settings.description)
    redraw
    echohl Title
    echo  'Description:'
    echohl None
    echo  'Please write a description of the gist.'
    echo  '(You can suppress this message with setting '
    echon '"let g:gista#interactive_description = 0" in your vimrc.)'
    let settings.description = input('Description: ')
  endif
  if settings.interactive_publish_status && settings.public == -1
    redraw
    echohl Title
    echo  'Publish status:'
    echohl None
    echo  'Please specify a publish status of the gist. '
    echon 'If you want to post a gist as a private gist, type "no".'
    echo  '(You can suppress this message with setting '
    echon '"let g:gista#interactive_publish_status = 0" in your vimrc.)'
    let settings.public = gista#util#input_yesno(
          \ 'Post a gist as a public gist?',
          \ g:gista#post_public ? 'yes' : 'no'))
  endif

  " upload gist
  let res = gista#raw#post(a:filenames, a:contents, settings)
  if res.status == 201
    " save gist
    let gist = res.content
    call s:set_gist(gist.id, gist)
    setlocal nomodified
    " connect the gists
    if g:gista#auto_connect_after_post
      redraw | echo 'Connecting buffers to the gist ...'
      let F = function("<SID>connect_gist_buffer")
      for [bufnum, filename] in gista#vital#zip(a:bufnums, a:filenames)
        call gista#util#call_on_buffer(bufnum, F, gist.id, filename)
      endfor
    endif
    " update gist list
    call s:update_list({})
    redraw | echo 'Gist is saved: ' . gist.html_url
    return gist
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to post the gist'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:save_gist(gistid, filenames, contents, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif
  let partial = gista#vital#pick(gist, [
        \ 'description',
        \ 'public',
        \ 'files',
        \])
  let settings = extend({
        \ 'interactive_description': g:gista#interactive_description,
        \ 'interactive_publish_status': g:gista#interactive_publish_status,
        \ 'description': '',
        \ 'public': -1,
        \}, a:settings)

  if empty(settings.description)
    if settings.interactive_description && empty(partial.description)
      redraw
      echohl Title
      echo  'Description (missing):'
      echohl None
      echo  'It seems this gist does not have a description. '
      echon  'Please provide a description of the gist.'
      echo  '(You can suppress this message with setting '
      echon '"let g:gista#interactive_description = 0" in your vimrc.)'
      let partial.description = input('Description: ')
    elseif settings.interactive_description == 2
      redraw
      echohl Title
      echo  'Description:'
      echohl None
      echo  'Please modify a description of the gist (Hit return to cancel).'
      echo  '(You can suppress this message with setting '
      echon '"let g:gista#interactive_description = 0 or 1" in your vimrc.)'
      let partial.description = input('Description: ', partial.description)
    endif
  else
    let partial.description = settings.description
  endif

  if settings.public == -1
    if settings.interactive_publish_status == 2
      redraw
      echohl Title
      echo  'Publish status:'
      echohl None
      echo  'Please modify a publish status of the gist. '
      echon 'If you want to post a gist as a private gist, type "no".'
      echo  '(You can suppress this message with setting '
      echon '"let g:gista#interactive_publish_status = 0" in your vimrc.)'
      let settings.public = gista#util#input_yesno(
            \ 'Post a gist as a public gist?',
            \ partial.public ? 'yes' : 'no'))
    endif
  else
    let partial.public = settings.public
  endif

  " update gist contents
  for [filename, content] in gista#vital#zip(a:filenames, a:contents)
    let partial.files[filename] = {'content': content}
  endfor
  " upload gist
  let res = gista#raw#patch(a:gistid, partial, settings)
  if res.status == 200
    " update gist (without loosing links)
    for [key, value] in items(res.content)
      let gist[key] = value
      unlet! value
    endfor
    setlocal nomodified
    " update gist list
    call s:update_list({})
    redraw | echo 'Gist (' . a:gistid . ') is saved: ' . gist.html_url
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to post the gist: ' . gist.html_url
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:rename_gist(gistid, filename, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif

  if has_key(settings, 'new_filename')
    let new_filename = settings.new_filename
  else
    redraw
    echohl Title
    echo  'Rename:'
    echohl None
    echo  'Please input a new filename (Empty to cancel).'
    let new_filename = input(a:filename . ' -> ', a:filename)
    if empty(new_filename)
      echohl WarningMsg
      echo 'Canceled'
      echohl None
      return
    endif
  endif

  let partial = {}
  let partial.files = {}
  let partial.files[a:filename] = {
        \ 'filename': new_filename,
        \ 'content': gist.files[a:filename].content,
        \}

  " upload gist
  let res = gista#raw#patch(a:gistid, partial, a:settings)
  if res.status == 200
    " update gist (without loosing links)
    for [key, value] in items(res.content)
      let gist[key] = value
      unlet! value
    endfor
    setlocal nomodified
    " update gist list
    call s:update_list({})
    redraw | echo "Renamed from " a:filename . " to " . new_filename . " : "
    echon gist.html_url
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Renaming "' . a:filename . '" has failed:'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:remove_gist(gistid, filename, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif

  redraw
  echohl Title
  echo  'Remove:'
  echohl None
  echo  'Removing "' . a:filename . '" from the gist. '
  echo  'This operation cannot be undone within vim-gista interface. '
  echon 'You have to go Gist web interface to revert the file.'
  let response = gista#util#input_yesno('Are you sure to remove the file')
  if !response
    redraw
    echohl WarningMsg
    echo 'Canceled'
    echohl None
    return
  endif

  " remove the file from gist
  let res = gista#raw#remove(
        \ a:gistid,
        \ [a:filename],
        \ a:settings
        \)
  if res.status == 200
    " disconnect
    if exists('b:gistinfo') &&
          \ b:gistinfo.gist.id == a:gistid &&
          \ b:gistinfo.filename == a:filename
      call s:disconnect_gist_buffer({'confirm': 0})
    else
      call gista#util#call_on_buffer(
            \ gist.files[a:filename].bufnum,
            \ function("<SID>disconnect_gist_buffer"),
            \ {'confirm': 0},
            \)
    endif
    " update gist (without loosing links)
    for [key, value] in items(res.content)
      let gist[key] = value
      unlet! value
    endfor
    " update gist list
    call s:update_list({})
    redraw | echo "Removed " . a:filename . " from the gist: " . gist.html_url
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to remove a file from the gist: ' . gist.html_url
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif

endfunction " }}}
function! s:delete_gist(gistid, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif

  redraw
  echohl Title
  echo  'Delete:'
  echohl None
  echo  'Deleting a gist (' . a:gistid . '). '
  echon 'If you really want to delete the gist, type "DELETE".'
  echohl WarningMsg
  echo  'This operation cannot be undone even in Gist web interface.'
  echohl None
  let response = input('type "DELETE" to delete the gist: ')
  if response !=# 'DELETE'
    redraw
    echohl WarningMsg
    echo 'Canceled'
    echohl None
    return
  endif

  " delete the gist
  let res = gista#raw#delete(a:gistid, a:settings)
  if res.status == 204
    " disconnect
    let F = function("<SID>disconnect_gist_buffer")
    for filename in keys(gist.files)
      call gista#util#call_on_buffer(
            \ gist.files[filename].bufnum,
            \ F, {'confirm': 0},
            \)
    endfor
    " delete gist cache
    let gists = s:get_gists()
    unlet! gists[a:gistid]
    " update gist list
    call s:update_list({})
    redraw | echo "Deleted the gist (" . a:gistid . ")"
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to delete the gist: ' . gist.html_url
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif

endfunction " }}}
function! s:star_gist(gistid, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif
  " star gist
  redraw
  let res = gista#raw#star(a:gistid, a:settings)
  if res.status == 204
    redraw
    echo printf('Gist (%s) is starred.', a:gistid)
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to star the gist: ' . gist.html_url
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:unstar_gist(gistid, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif

  " unstar gist
  redraw
  let res = gista#raw#unstar(a:gistid, a:settings)
  if res.status == 204
    redraw
    echo printf('Gist (%s) is unstarred.', a:gistid)
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to unstar the gist: ' . gist.html_url
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:is_starred_gist(gistid, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif

  " is starred?
  let res = gista#raw#is_starred(a:gistid, a:settings)
  if res.status == 204
    redraw
    echo printf('Gist (%s) is starred.', a:gistid)
  elseif res.status == 404
    redraw
    echo printf('Gist (%s) is not starred.', a:gistid)
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to check if the gist is starred.'
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:fork_gist(gistid, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif
  " fork gist
  let res = gista#raw#fork(a:gistid, a:settings)
  if res.status == 201
    " update gist list
    call s:update_list({})
    redraw
    echo  printf('The gist (%s) is forked. ', a:gistid)
    let a = gista#util#input_yesno('Do you want to open the forked gist now?')
    if a
      call s:open_gist(res.content.id, [], a:settings)
    endif
  else
    redraw
    echohl ErrorMsg
    echo  res.status . ' ' . res.statusText
    echohl None
    echo  'Failed to fork the gist: ' . gist.html_url
    if has_key(res.content, 'message')
      echo  'Message: ' . res.content.message
    endif
  endif
endfunction " }}}
function! s:browse_gist(gistid, filename, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    let url = 'https://gist.github.com/' . string(a:gistid)
  else
    let url = gist.html_url
  endif
  if !empty(a:filename)
    let url = url . '#file-' . substitute(a:filename, '\.', '-', 'g')
  endif
  call gista#util#browse(url)
endfunction " }}}
function! s:disconnect_gist_buffer(settings) abort " {{{
  let settings = extend({
        \ 'provide_filename': 1,
        \ 'confirm': 1,
        \}, a:settings)
  if empty(get(b:, 'gistinfo', {}))
    redraw
    echohl ErrorMsg
    echo  'No gist is connected:'
    echohl None
    echo  'It seems that no gist is connected to this buffer.'
    return
  endif
  if settings.confirm
    redraw
    echohl Title
    echo  'Disconnect the gist:'
    echohl None
    echo  'If you disconnec the gist from the buffer, you need to re-open the '
    echon 'gist when you want to update the changes.'
    let a = gista#util#input_yesno('Are you sure to disconnect?')
    if !a
      redraw
      echohl WarningMsg
      echo  'Canceled'
      echohl None
      return
    endif
  endif
  setlocal buftype&
  autocmd! BufWriteCmd <buffer>
  unlet! b:gistinfo
  if settings.provide_filename
    let fname = s:get_usable_buffer_name(fnameescape(expand('%:t')))
    execute "file" fname
  endif
endfunction " }}}


function! gista#view#list(lookup, settings) abort " {{{
  return s:open_list(a:lookup, a:settings)
endfunction " }}}
function! gista#view#update_list(settings) abort " {{{
  return s:update_list(a:settings)
endfunction " }}}
function! gista#view#update_list_buffer(settings) abort " {{{
  return s:update_list_buffer(a:settings)
endfunction " }}}

function! gista#view#open(gistid, filenames, settings) abort " {{{
  if type(a:filenames) == 3 && empty(a:filenames)
    redraw
    echohl Title
    echo  'Filenames is required:'
    echohl None
    echo  'Please specify filenamess with a semi-colon (;) separated string '
    echon '(e.g. foo.txt;bar.vim;hoge.html). '
    echo  'If you want to open all files in the gist, leave the field empty '
    echon 'and hit return.'
    let _filenames = input('A semi-colon separated filenames: ')
    if !empty(_filenames)
      let filenames = split(_filenames, ";")
    else
      unlet filenames
      let filenames = ''
    endif
  else
    let filenames = a:filenames
  endif
  return s:open_gist(a:gistid, filenames, a:settings)
endfunction " }}}
function! gista#view#post_buffer(line1, line2, settings) abort " {{{
  let filename = gista#util#provide_filename(expand('%'), 0)
  let content = join(getline(a:line1, a:line2), "\n")
  return s:post_gist([bufnr('%')], [filename], [content], a:settings)
endfunction " }}}
function! gista#view#post_all_buffers(settings) abort " {{{
  let filenames = []
  let contents = []
  let cbufnum = bufnr(expand('%'))
  let bufnums = range(1, bufnr("$"))
  let posted_bufnums = []
  let index = 1
  for bufnum in bufnums
    redraw
    echo  'Constructing a gist to post... '
    echon index . '/' . len(bufnums)
    let index = index + 1
    if !bufexists(bufnum) || !buflisted(bufnum) ||
          \ (g:gista#include_invisible_buffers_in_multiple ||
          \  bufwinnr(bufnum) == -1)
      " the buffer is not exist/listed/visible thus ignore.
      continue
    endif
    execute bufnum . "buffer"
    call add(contents, join(getline(1, line('$')), "\n"))
    call add(filenames,
          \ gista#util#provide_filename(expand('%'), len(posted_bufnums))
          \)
    call add(posted_bufnums, bufnum)
  endfor
  execute cbufnum . "buffer"
  return s:post_gist(posted_bufnums, filenames, contents, a:settings)
endfunction " }}}
function! gista#view#save(gistid, filenames, contents, settings) abort " {{{
  return s:save_gist(a:gistid, a:filenames, a:contents, a:settings)
endfunction " }}}
function! gista#view#save_buffer(line1, line2, settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    redraw
    echohl ErrorMsg
    echo  'No gist is connected:'
    echohl None
    echo  'It seems that no gist is connected to this buffer.'
    return
  endif
  let gistid = b:gistinfo.gistid
  let filename = b:gistinfo.filename
  let content = join(getline(a:line1, a:line2), "\n")
  return s:save_gist(gistid, [filename], [content], a:settings)
endfunction " }}}
function! gista#view#rename(gistid, filename, settings) abort " {{{
  return s:rename_gist(a:gistid, a:filename, a:settings)
endfunction " }}}
function! gista#view#rename_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:rename_gist(
        \ b:gistinfo.gistid,
        \ b:gistinfo.filename,
        \ a:settings)
endfunction " }}}
function! gista#view#remove(gistid, filename, settings) abort " {{{
  return s:remove_gist(a:gistid, a:filename, a:settings)
endfunction " }}}
function! gista#view#remove_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:remove_gist(
        \ b:gistinfo.gistid,
        \ b:gistinfo.filename,
        \ a:settings)
endfunction " }}}
function! gista#view#delete(gistid, settings) abort " {{{
  return s:delete_gist(gistid, settings)
endfunction " }}}
function! gista#view#delete_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:delete_gist(b:gistinfo.gistid, a:settings)
endfunction " }}}
function! gista#view#star(gistid, settings) abort " {{{
  return s:star_gist(gistid, settings)
endfunction " }}}
function! gista#view#star_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:star_gist(b:gistinfo.gistid, a:settings)
endfunction " }}}
function! gista#view#unstar(gistid, settings) abort " {{{
  return s:unstar_gist(gistid, settings)
endfunction " }}}
function! gista#view#unstar_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:unstar_gist(b:gistinfo.gist.id, a:settings)
endfunction " }}}
function! gista#view#is_starred(gistid, settings) abort " {{{
  return s:is_starred_gist(a:gistid, a:settings)
endfunction " }}}
function! gista#view#is_starred_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:is_starred_gist(b:gistinfo.gistid, a:settings)
endfunction " }}}
function! gista#view#fork(gistid, settings) abort " {{{
  return s:fork_gist(a:gistid, a:settings)
endfunction " }}}
function! gista#view#fork_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  return s:fork_gist(b:gistinfo.gistid, a:settings)
endfunction " }}}
function! gista#view#browse(gistid, filename, settings) abort " {{{
  let gist = s:get_gist(a:gistid)
  let url = get(gist, 'html_url', 'https://gist.github.com/' . gist.id)
  let filename = substitute(a:filename, '\.', '-', '')
  if !empty(filename)
    let url = url . '#file-' . filename
  endif
  call gista#util#browse(url)
endfunction " }}}
function! gista#view#browse_buffer(settings) abort " {{{
  if empty(get(b:, 'gistinfo', {}))
    " gista does not manage this buffer
    return
  endif
  call gista#view#browse(b:gistinfo.gistid, b:gistinfo.filename)
endfunction " }}}
function! gista#view#disconnect(gistid, filenames, settings) " {{{
  let gist = s:get_gist(a:gistid)
  if empty(gist)
    return
  endif
  if empty(a:filenames)
    call gista#view#disconnect(a:gistid, keys(gist.files), a:settings)
  else
    let F = function("<SID>disconnect_gist_buffer")
    for filename in a:filenames
      let bufnum = get(gist.files[filename], 'bufnum', -1)
      call gista#util#call_on_buffer(bufnum, F, a:settings)
    endfor
  endif
endfunction " }}}
function! gista#view#disconnect_buffer(settings) abort " {{{
  call s:disconnect_gist_buffer(a:settings)
endfunction " }}}


nnoremap <silent> <Plug>(gista-open-list)
      \ :call gista#view#list('', {})<CR>
nnoremap <silent> <Plug>(gista-update-list)
      \ :call gista#view#update_list({})<CR>
nnoremap <silent> <Plug>(gista-update-list-nocache)
      \ :call gista#view#update_list({'nocache': 1})<CR>

nnoremap <silent> <Plug>(gista-action-update)
      \ :call <SID>action_list_buffer('update')<CR>
nnoremap <silent> <Plug>(gista-action-update-nocache)
      \ :call <SID>action_list_buffer('update:nocache')<CR>
nnoremap <silent> <Plug>(gista-action-open)
      \ :call <SID>action_list_buffer('open')<CR>
nnoremap <silent> <Plug>(gista-action-rename)
      \ :call <SID>action_list_buffer('rename')<CR>
nnoremap <silent> <Plug>(gista-action-remove)
      \ :call <SID>action_list_buffer('remove')<CR>
nnoremap <silent> <Plug>(gista-action-delete)
      \ :call <SID>action_list_buffer('delete')<CR>
nnoremap <silent> <Plug>(gista-action-smart-delete)
      \ :call <SID>action_list_buffer('smart-delete')<CR>
nnoremap <silent> <Plug>(gista-action-browse)
      \ :call <SID>action_list_buffer('browse')<CR>
nnoremap <silent> <Plug>(gista-action-star)
      \ :call <SID>action_list_buffer('star')<CR>
nnoremap <silent> <Plug>(gista-action-unstar)
      \ :call <SID>action_list_buffer('unstar')<CR>
nnoremap <silent> <Plug>(gista-action-is-starred)
      \ :call <SID>action_list_buffer('is-starred')<CR>
nnoremap <silent> <Plug>(gista-action-fork)
      \ :call <SID>action_list_buffer('fork')<CR>
nnoremap <silent> <Plug>(gista-action-browse)
      \ :call <SID>action_list_buffer('browse')<CR>


let s:consts = {}
let s:consts.DELIMITER = has('unix') ? ':' : '_'
let s:consts.LISTWIN_FILETYPE = 'gista-list'


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
