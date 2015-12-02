let s:save_cpo = &cpo
set cpo&vim

let s:current_filename = ''

function! s:ask_filename(...) abort " {{{
  let options = extend({
        \ 'apiname': gista#api#get_current_apiname(),
        \ 'gistid': gista#api#get#get_current_gistid(),
        \}, get(a:000, 0, {}),
        \)
  let apiname = gista#util#validate#silently(
        \ 'gista#api#get_apiname',
        \ options.apiname
        \)
  let gistid = gista#util#validate#silently(
        \ 'gista#api#get#get_gistid',
        \ options.gistid
        \)
  if !empty(apiname) && !empty(gistid)
    let client = gista#api#client(options)
    let entry = client.content_cache.get(gistid)
    let filenames = keys(get(entry, 'files', {}))
    if len(filenames) > 0
      if len(filenames) == 1
        return filenames[0]
      endif
      redraw
      let ret = gista#util#prompt#inputlist(
            \ 'Please select a file name:',
            \ filenames,
            \)
      return ret ? filenames[ret - 1] : ''
    endif
  endif
  redraw
  return gista#util#prompt#ask(
        \ 'Please input a filename: ', '',
        \ 'customlist,gista#complete#filename',
        \)
endfunction " }}}
function! s:set_current_filename(value) abort " {{{
  let s:current_filename = a:value
endfunction " }}}

function! gista#api#read#get_filename(filename) abort " {{{
  let filename = empty(a:filename)
        \ ? s:ask_filename()
        \ : a:filename
  call gista#validate#filename(filename)
  return filename
endfunction " }}}
function! gista#api#read#get_current_filename() abort " {{{
  return s:current_filename
endfunction " }}}
function! gista#api#read#call(client, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'filename': '',
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let anonymous = gista#api#get_current_anonymous()
  let gist = gista#api#get#call(a:client, options)
  let filename = gista#api#read#get_filename(options.filename)
  if has_key(get(gist, 'files', {}), filename)
    let file = gist.files[filename]
    " request the file content if the content is truncated
    if get(file, 'truncated')
      let res = a:client.get(file.raw_url, {}, {}, {
            \ 'verbose': options.verbose,
            \ 'anonymous': anonymous,
            \})
      if res.status != 200
        call gista#util#prompt#throw(
              \ printf('%s: %s', res.status, res.statusText),
              \ res.content,
              \)
      endif
      let file.truncated = 0
      let file.content = res.content
    endif
    call s:set_current_filename(filename)
    return split(file.content, '\r\?\n')
  endif
  call gista#util#prompt#throw(
        \ '404: Not found',
        \ printf(
        \   'A filename "%s" is not found in a gist "%s"',
        \   filename, gist.id,
        \ ),
        \)
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
