"******************************************************************************
" vim-gista interface
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:get_buffer_name(...) abort " {{{
  return 'gista' . s:consts.DELIMITER . gista#utils#vital#path_join(a:000)
endfunction " }}}
function! s:get_usable_buffer_name(name) abort " {{{
  if bufnr(a:name) == -1
    return a:name
  endif
  let index = 1
  let filename = fnamemodify(a:name, ':t')
  let basename = fnamemodify(a:name, ':r')
  let extension = fnamemodify(a:name, ':e')
  while bufnr(filename) > -1
    let index += 1
    let filename = printf("%s-%d.%s", basename, index, extension)
  endwhile
  return filename
endfunction " }}}
function! s:get_bridges() abort " {{{
  if !exists('s:bridges')
    let s:bridges = {}
  endif
  return s:bridges
endfunction " }}}
function! s:get_bridge(gistid, filename) abort " {{{
  let bridges = s:get_bridges()
  return get(get(bridges, a:gistid, {}), a:filename, -1)
endfunction " }}}
function! s:set_bridge(gistid, filename, bufnum) abort " {{{
  let bridges = s:get_bridges()
  if !has_key(bridges, a:gistid)
    let bridges[a:gistid] = {}
  endif
  let bridges[a:gistid][a:filename] = a:bufnum
endfunction " }}}
function! s:format_gist(gist) abort " {{{
  let gistid = printf("[%-20S]", a:gist.id)
  let update = printf("%s",
        \ gista#utils#datetime(a:gist.updated_at).format('%Y/%m/%d %H:%M:%S'))
  let private = a:gist.public ? "" : "<private>"
  let description = empty(a:gist.description) ?
        \ '<<No description>>' :
        \ a:gist.description
  let bwidth = gista#utils#get_bufwidth()
  let width = bwidth - len(private) - len(gistid) - len(update) - 4
  return printf(printf("%%-%dS %%s %%s %%s", width),
        \ gista#utils#trancate(description, width),
        \ private,
        \ gistid,
        \ update)
endfunction " }}}
function! s:format_gist_file(gist, filename) abort " {{{
  return '- ' . a:filename
endfunction " }}}
function! s:disconnect(...) abort " {{{
  let settings = extend({
        \ 'provide_filename': 1,
        \}, get(a:000, 0, {}))
  if !exists('b:gistinfo')
    return
  endif

  setlocal buftype&
  autocmd! BufWriteCmd <buffer>
  unlet! b:gistinfo
  if settings.provide_filename
    let fname = s:get_usable_buffer_name(fnameescape(expand('%:t')))
    execute 'file' fname
  endif
  setlocal modified
endfunction " }}}
function! s:action(action) abort " {{{
  if &filetype !=# s:consts.LISTWIN_FILETYPE
    return
  endif

  let settings = extend({
        \ 'openers': g:gista#gist_openers_in_action,
        \ 'opener': g:gista#gist_default_opener_in_action,
        \}, get(b:settings, 'action_settings', {}))

  let cursorline = line('.')
  let link = get(b:links, cursorline - 1, {})
  if empty(link)
    return
  endif

  call gista#interface#do_action(a:action, link, settings)
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
      echohl GistaInfo
      echo  'Type ":w!" to update the gist or set "let g:gista#update_on_write'
      echon ' = 1" to update the gist everytime when the file is saved.'
      echohl None
    else
      return gista#interface#save(1, '$')
    endif
  else
    " new filename is given, save the content with a new filename
    " and stop autocmd, unlink the content from Gist
    execute "file" fnameescape(a:filename)
    call s:disconnect({'provide_filename': 0})
    execute "w".(v:cmdbang ? "!" : "") fnameescape(v:cmdarg) fnameescape(a:filename)
  endif
endfunction " }}}


function! gista#interface#list(lookup, ...) abort " {{{
  let bufname = s:get_buffer_name('list')
  let settings = extend({
        \ 'page': -1,
        \ 'nocache': 0,
        \ 'opener': g:gista#list_opener,
        \}, get(a:000, 0, {}))
  let settings.action_settings = extend({
        \ 'opener': g:gista#gist_default_opener_in_action,
        \}, get(settings, 'action_settings', {}))

  let bufnum = bufnr(bufname)
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    silent execute 'noautocmd' settings.opener bufname
    if bufnum == -1
      " initialize list window
      setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
      execute "setfiletype" s:consts.LISTWIN_FILETYPE

      if g:gista#enable_default_keymaps
        nmap <buffer> <F1>       :<C-u>help vim-gista-default-mappings<CR>
        nmap <buffer> <C-l>      <Plug>(gista-action-update)
        nmap <buffer> <C-l><C-l> <Plug>(gista-action-update-nocache)
        nmap <buffer> r          <Plug>(gista-action-rename)
        nmap <buffer> D          <Plug>(gista-action-smart-delete)
        nmap <buffer> +          <Plug>(gista-action-star)
        nmap <buffer> -          <Plug>(gista-action-unstar)
        nmap <buffer> ?          <Plug>(gista-action-is-starred)
        nmap <buffer> F          <Plug>(gista-action-fork)
        nmap <buffer> <CR>       <Plug>(gista-action-open)
        nmap <buffer> <S-CR>     <Plug>(gista-action-browse)
        nmap <buffer> e          <Plug>(gista-action-edit)
        nmap <buffer> s          <Plug>(gista-action-split)
        nmap <buffer> v          <Plug>(gista-action-vsplit)
        nmap <buffer> b          <Plug>(gista-action-browse)
        nmap <buffer> yy         <Plug>(gista-action-yank)
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
        \ a:lookup != b#lookup ||
        \ settings.page != get(b#settings, 'page', -1)
        \)
  let b:lookup = a:lookup
  let b:settings = settings
  if is_condition_updated
    " lookup condition has changed, update is required
    call gista#interface#update(settings)
  endif
endfunction " }}}
function! gista#interface#update(...) abort " {{{
  let bufname = s:get_buffer_name('list')
  let settings = extend({}, get(a:000, 0, getbufvar(bufname, 'settings', {})))
  " this function should be called on the gista:list window
  if bufname !=# expand('%')
    call gista#utils#call_on_buffer(bufname,
          \ function('gista#interface#update'),
          \ settings)
    return
  endif

  let gists = gista#gist#api#list(b:lookup, settings)
  if empty(gists)
    bw!
    return
  endif

  " put gist lines and links
  let lines = []
  let links = []
  call add(lines, '" Press <F1> to see the help')
  call add(lines, '')
  call add(links, {})
  call add(links, {})
  for gist in gists
    call add(lines, s:format_gist(gist))
    call add(links, {'gist': gist, 'filename': ''})
    for filename in keys(gist.files)
      call add(lines, s:format_gist_file(gist, filename))
      call add(links, {'gist': gist, 'filename': filename})
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
  let b:settings = gista#utils#vital#omit(settings, ['nocache'])
endfunction " }}}

function! gista#interface#connect(gistid, filename) abort " {{{
  if exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'Gist is already connected'
    echohl None
    echo 'It seems that a gist is already connected to the current buffer.'
    return
  endif
  let gist = gista#gist#api#get(a:gistid)
  if empty(gist)
    return
  endif
  " Connect current buffer to the gist
  call s:set_bridge(a:gistid, a:filename, bufnr('%'))
  " Keep gistid and filename to the buffer variable
  let b:gistinfo = {
        \ 'gistid': a:gistid,
        \ 'filename': a:filename
        \}
  " is the gist editable?
  if gist.owner.login == gista#gist#raw#get_authenticated_user()
    " user own the gist, modifiable
    setlocal modifiable
    autocmd! BufWriteCmd <buffer>
          \ call s:ac_write_gist_buffer(expand("<amatch>"))
  else
    " non user gist, nomodifiable
    setlocal buftype=nowrite
    setlocal nomodifiable
    autocmd! BufWriteCmd <buffer>
  endif
endfunction " }}}
function! gista#interface#open(gistid, filenames, ...) abort " {{{
  let settings = extend({
        \ 'openers': g:gista#gist_openers,
        \ 'opener': g:gista#gist_default_opener,
        \}, get(a:000, 0, {}))

  let gist = gista#gist#api#get(a:gistid, settings)
  if empty(gist)
    return
  endif

  if empty(a:filenames)
    let filenames = keys(gist.files)
  elseif type(a:filenames) == 1 " String
    let filenames = [a:filenames]
  else
    let filenames = a:filenames
  endif

  if has_key(settings.openers, settings.opener)
    let opener = settings.openers[settings.opener]
  else
    let opener = settings.opener
  endif
  for filename in filenames
    let bufname = s:get_buffer_name(a:gistid, filename)
    let bufnum = bufnr(bufname)
    let winnum = bufwinnr(bufnum)

    if winnum == -1
      if !has_key(gist.files, filename)
        redraw
        echohl GistaWarning
        echo  'File entry is not found:'
        echohl None
        echo  'An entry of "' . filename . '" is not found in the gist.'
        continue
      endif
      execute 'noautocmd' opener bufname
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
        call gista#interface#connect(a:gistid, filename)

        " successfully loaded, call autocmd
        doautocmd StdinReadPost,BufRead,BufReadPost
      endif
    else
      execute winnum . 'wincmd w'
    endif
  endfor
endfunction " }}}
function! gista#interface#post(line1, line2, ...) abort " {{{
  let settings = extend({
        \ 'auto_connect_after_post': g:gista#auto_connect_after_post,
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let filename = gista#utils#provide_filename(expand('%'), 0)
  let content = join(getline(a:line1, a:line2), "\n")

  let gist = gista#gist#api#post([filename], [content], settings)
  if empty(gist)
    return
  endif

  " Connect the buffer to the gist
  if settings.auto_connect_after_post
    call gista#interface#connect(gist.id, filename)
  endif
  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#post_buffers(...) abort " {{{
  let settings = extend({
        \ 'include_invisible_buffers_in_multiple':
        \     g:gista#include_invisible_buffers_in_multiple,
        \ 'auto_connect_after_post': g:gista#auto_connect_after_post,
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let filenames = []
  let contents = []
  let pbufnums = []
  let bufnums = range(1, bufnr('$'))
  let cbufnum = bufnr(expand('%'))
  let index = 1
  for bufnum in bufnums
    redraw | echo 'Constructing a gist to post ...' index . '/' . len(bufnums)
    if !bufexists(bufnum) ||
          \ !buflisted(bufnum) ||
          \ (!settings.include_invisible_buffers_in_multiple &&
          \  bufwinnr(bufnum) == -1)
      continue
    endif

    execute bufnum . 'buffer'
    call add(contents, join(getline(1, line('$')), "\n"))
    call add(filenames,
          \ gista#utils#provide_filename(expand('%:t'), len(pbufnums)))
    call add(pbufnums, bufnum)
  endfor
  execute cbufnum . 'buffer'

  let gist = gista#gist#api#post(filenames, contents, settings)
  if empty(gist)
    return
  endif

  " Connect the buffer to the gist
  if settings.auto_connect_after_post
    for [bufnum, filename] in gista#utils#vital#zip(pbufnums, filenames)
      call gista#utils#call_on_buffer(
            \ bufnum,
            \ function('gista#interface#connect'),
            \ gist.id, filename)
    endfor
  endif
  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#save(line1, line2, ...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#save() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gistid = b:gistinfo.gistid
  let filename = b:gistinfo.filename
  let content = join(getline(a:line1, a:line2), "\n")

  let gist = gista#gist#api#patch(gistid, [filename], [content], settings)
  if empty(gist)
    return
  endif

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#rename(new_filename, ...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#rename() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gistid = b:gistinfo.gistid
  let filename = b:gistinfo.filename

  let gist = gista#gist#api#rename(gistid, filename, a:new_filename, settings)
  if empty(gist)
    return
  endif

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#remove(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#remove() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gistid = b:gistinfo.gistid
  let filename = b:gistinfo.filename

  let gist = gista#gist#api#remove(gistid, filename, settings)
  if empty(gist)
    return
  endif

  " Disconnect
  call s:disconnect()

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#delete(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#delete() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gistid = b:gistinfo.gistid

  let gist = gista#gist#api#delete(gistid, settings)
  if empty(gist)
    return
  endif

  " Disconnect
  call gista#interface#disconnect_action(gistid, '')

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#star(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#star() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({}, get(a:000, 0, {}))
  let gistid = b:gistinfo.gistid

  call gista#gist#api#star(gistid, settings)
endfunction " }}}
function! gista#interface#unstar(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#unstar() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({}, get(a:000, 0, {}))
  let gistid = b:gistinfo.gistid

  call gista#gist#api#unstar(gistid, settings)
endfunction " }}}
function! gista#interface#is_starred(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#is_starred() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({}, get(a:000, 0, {}))
  let gistid = b:gistinfo.gistid

  let is_starred = gista#gist#api#is_starred(gistid, settings)
  if !type(is_starred) == 0
    return
  endif

  if is_starred
    redraw | echo printf('The gist (%s) is starred', gistid)
  else
    redraw | echo printf('The gist (%s) is not starred', gistid)
  endif
endfunction " }}}
function! gista#interface#fork(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#fork() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gistid = b:gistinfo.gistid

  let gist = gista#gist#api#fork(gistid, settings)
  if empty(gist)
    return
  endif

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif

  " Open the new fork?
  redraw
  echohl GistaTitle
  echo 'Gist forked'
  echohl None
  echohl GistaQuestion
  let a = gista#utils#input_yesno(printf(
        \ 'A gist (%s) is forked. Do you want to open it now?', gistid))
  echohl None
  if a
    call gista#interface#open(gist.id, [], settings)
  endif
endfunction " }}}
function! gista#interface#browse(...) abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#browse() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let settings = extend({}, get(a:000, 0, {}))

  let gistid = b:gistinfo.gistid
  let filename = b:gistinfo.filename

  call gista#interface#browse_action(gistid, filename, settings)
endfunction " }}}
function! gista#interface#yank() abort " {{{
  if !exists('b:gistinfo')
    redraw
    echohl WarningMsg
    echo 'No gist is connected'
    echohl None
    echo 'It seems that no gist is connected to the current buffer.'
          \ 'gista#interface#yank() function need to be executed on the'
          \ 'buffer which is connected to a gist.'
    return
  endif

  let gistid = b:gistinfo.gistid
  let filename = b:gistinfo.filename

  call gista#interface#yank_action(gistid, filename)
endfunction " }}}

function! gista#interface#do_action(action, info, ...) " {{{
  let settings = extend({
        \ 'openers': g:gista#gist_openers_in_action,
        \ 'opener': g:gista#gist_default_opener_in_action,
        \ 'close_list_after_open': g:gista#close_list_after_open,
        \}, get(a:000, 0, {}))

  if a:action ==# 'update' " {{{
    call gista#interface#update(settings) " }}}
  elseif a:action ==# 'update_nocache' " {{{
    let settings = deepcopy(settings)
    let settings.nocache = 1
    call gista#interface#update(settings) " }}}
  elseif a:action ==# 'open' ||
        \ a:action ==# 'edit' ||
        \ a:action ==# 'split' ||
        \ a:action ==# 'vsplit' " {{{
    if empty(a:info.gist.files)
      redraw
      echohl GistaWarning
      echo  'Gist does not contain files:'
      echohl None
      echo  'No files are existing in the gist. Canceled.'
      return
    endif

    if a:action !=# 'open'
      " overwrite opener
      let settings = extend(settings, {
            \ 'opener': a:action,
            \})
    endif

    " move the focuse to the previous selected window
    execute 'wincmd p'
    call gista#interface#open(a:info.gist.id, a:info.filename, settings)
    if settings.close_list_after_open
      " close gista:list and focuse back to the opend windw
      let cwinnum = winnr()
      let lwinnum = bufwinnr(bufnr(s:get_buffer_name('list')))
      execute lwinnum . 'wincmd w'
      quit
      execute cwinnum . 'wincmd w'
    endif " }}}
  elseif a:action ==# 'rename' " {{{
    if empty(a:info.filename)
      redraw
      echohl GistaWarning
      echo  'Invalid action:'
      echohl None
      echo  'You have to execute "rename" action on the filename'
      return
    endif
    call gista#interface#rename_action(a:info.gist.id, a:info.filename, '') " }}}
  elseif a:action ==# 'remove' " {{{
    if empty(a:info.filename)
      redraw
      echohl GistaWarning
      echo  'Invalid action:'
      echohl None
      echo  'You have to execute "remove" action on the filename'
      return
    endif
    call gista#interface#remove_action(a:info.gist.id, a:info.filename) " }}}
  elseif a:action ==# 'delete' " {{{
    if !empty(a:info.filename)
      redraw
      echohl GistaWarning
      echo  'Invalid action:'
      echohl None
      echo  'You have to execute "delete" action on the gist description. '
      echon 'If you want to remove a particular file, use "remove" action.'
      return
    endif
    call gista#interface#delete_action(a:info.gist.id) " }}}
  elseif a:action ==# 'smart_delete' " {{{
    if empty(a:info.filename)
      call gista#interface#delete_action(a:info.gist.id)
    else
      call gista#interface#remove_action(a:info.gist.id, a:info.filename)
    endif " }}}
  elseif a:action ==# 'star' " {{{
    call gista#interface#star_action(a:info.gist.id) " }}}
  elseif a:action ==# 'unstar' " {{{
    call gista#interface#unstar_action(a:info.gist.id) " }}}
  elseif a:action ==# 'is_starred' " {{{
    call gista#interface#is_starred_action(a:info.gist.id) " }}}
  elseif a:action ==# 'fork' " {{{
    call gista#interface#fork_action(a:info.gist.id) " }}}
  elseif a:action ==# 'browse' " {{{
    call gista#interface#browse_action(a:info.gist.id, a:info.filename) " }}}
  elseif a:action ==# 'yank' " {{{
    call gista#interface#yank_action(a:info.gist.id, a:info.filename) " }}}
  endif

endfunction " }}}
function! gista#interface#rename_action(gistid, filename, new_filename, ...) abort " {{{
  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gist = gista#gist#api#rename(
        \ a:gistid, a:filename, a:new_filename, settings)
  if empty(gist)
    return
  endif

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#remove_action(gistid, filename, ...) abort " {{{
  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gist = gista#gist#api#remove(a:gistid, a:filename, settings)
  if empty(gist)
    return
  endif

  " Disconnect
  call gista#interface#disconnect_action(a:gistid, a:filename)

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#delete_action(gistid, ...) abort " {{{
  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gist = gista#gist#api#delete(a:gistid, settings)
  if empty(gist)
    return
  endif

  " Disconnect (#delete return deepcopied gist instance)
  call gista#interface#disconnect_action(a:gistid, '')

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif
endfunction " }}}
function! gista#interface#star_action(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  call gista#gist#api#star(a:gistid, settings)
endfunction " }}}
function! gista#interface#unstar_action(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  call gista#gist#api#unstar(a:gistid, settings)
endfunction " }}}
function! gista#interface#is_starred_action(gistid, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let is_starred = gista#gist#api#is_starred(a:gistid, settings)
  if !type(is_starred) == 0
    return
  endif

  if is_starred
    redraw | echo printf('The gist (%s) is starred', a:gistid)
  else
    redraw | echo printf('The gist (%s) is not starred', a:gistid)
  endif
endfunction " }}}
function! gista#interface#fork_action(gistid, ...) abort " {{{
  let settings = extend({
        \ 'update_list': 1,
        \}, get(a:000, 0, {}))

  let gist = gista#gist#api#fork(a:gistid, settings)
  if empty(gist)
    return
  endif

  " Update list window
  if settings.update_list
    call gista#interface#update()
  endif

  " Open the new fork?
  redraw
  echohl GistaTitle
  echo 'Gist forked'
  echohl None
  echohl GistaQuestion
  let a = gista#utils#input_yesno(printf(
        \ 'A gist (%s) is forked. Do you want to open it now?', a:gistid))
  if a
    call gista#interface#open(gist.id, [])
  endif
endfunction " }}}
function! gista#interface#browse_action(gistid, filename, ...) abort " {{{
  let settings = extend({}, get(a:000, 0, {}))
  let gist = gista#gist#api#get(a:gistid, settings)
  let url = gista#utils#get_gist_url(gist, a:filename)
  call gista#utils#browse(url)
endfunction " }}}
function! gista#interface#disconnect_action(gistid, filenames) abort " {{{
  let bridges = s:get_bridges()

  if empty(a:filenames)
    let filenames = keys(get(bridges, a:gistid, {}))
  elseif type(a:filenames) == 1
    let filenames = [a:filenames]
  else
    let filenames = a:filenames
  endif

  let F = function("<SID>disconnect")
  for filename in filenames
    let bufnum = s:get_bridge(a:gistid, filename)
    call gista#utils#call_on_buffer(bufnum, F)
  endfor
endfunction " }}}
function! gista#interface#yank_action(gistid, ...) abort " {{{
  let filename = get(a:000, 0, '')
  if empty(filename)
    let content = a:gistid
  else
    let content = printf("%s/%s", a:gistid, filename)
  endif

  let @" = content
  redraw | echo 'Yanked: ' . content

  if has('clipboard')
    call setreg(v:register, content)
  endif
endfunction " }}}

nnoremap <silent> <Plug>(gista-update)
      \ :call gista#interface#update()<CR>
nnoremap <silent> <Plug>(gista-update-nocache)
      \ :call gista#interface#update({'nocache': 1})<CR>
nnoremap <silent> <Plug>(gista-action-update)
      \ :call <SID>action('update')<CR>
nnoremap <silent> <Plug>(gista-action-update-nocache)
      \ :call <SID>action('update_nocache')<CR>
nnoremap <silent> <Plug>(gista-action-open)
      \ :call <SID>action('open')<CR>
nnoremap <silent> <Plug>(gista-action-edit)
      \ :call <SID>action('edit')<CR>
nnoremap <silent> <Plug>(gista-action-split)
      \ :call <SID>action('split')<CR>
nnoremap <silent> <Plug>(gista-action-vsplit)
      \ :call <SID>action('vsplit')<CR>
nnoremap <silent> <Plug>(gista-action-rename)
      \ :call <SID>action('rename')<CR>
nnoremap <silent> <Plug>(gista-action-remove)
      \ :call <SID>action('remove')<CR>
nnoremap <silent> <Plug>(gista-action-delete)
      \ :call <SID>action('delete')<CR>
nnoremap <silent> <Plug>(gista-action-smart-delete)
      \ :call <SID>action('smart_delete')<CR>
nnoremap <silent> <Plug>(gista-action-browse)
      \ :call <SID>action('browse')<CR>
nnoremap <silent> <Plug>(gista-action-star)
      \ :call <SID>action('star')<CR>
nnoremap <silent> <Plug>(gista-action-unstar)
      \ :call <SID>action('unstar')<CR>
nnoremap <silent> <Plug>(gista-action-is-starred)
      \ :call <SID>action('is_starred')<CR>
nnoremap <silent> <Plug>(gista-action-fork)
      \ :call <SID>action('fork')<CR>
nnoremap <silent> <Plug>(gista-action-browse)
      \ :call <SID>action('browse')<CR>
nnoremap <silent> <Plug>(gista-action-yank)
      \ :call <SID>action('yank')<CR>


let s:consts = {}
let s:consts.DELIMITER = has('unix') ? ':' : '_'
let s:consts.LISTWIN_FILETYPE = 'gista-list'


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
