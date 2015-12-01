let s:save_cpo = &cpoptions
set cpoptions&vim

let s:V = gista#vital()
let s:C = s:V.import('System.Cache')

function! s:get_file_cache() abort " {{{
  if !exists('s:file_cache')
    let s:file_cache = s:C.new(
          \ 'file', {
          \   'cache_dir': g:gista#cache_dir,
          \ }
          \)
  endif
  return s:file_cache
endfunction " }}}
function! s:get_memory_cache() abort " {{{
  if !exists('s:memory_cache')
    let s:memory_cache = s:C.new('memory')
  endif
  return s:memory_cache
endfunction " }}}

function! gista#util#get_cache(name) abort " {{{
  let memory_cache = s:get_memory_cache()
  if memory_cache.has(a:name)
    return memory_cache.get(a:name)
  endif
  let file_cache = s:get_file_cache()
  let cache = s:C.new('memory')
  let cache = extend(cache, {
        \ '__name__': a:name,
        \ '_cached': file_cache.get(a:name, {})
        \})
  function! cache.on_changed() abort
    let file_cache = s:get_file_cache()
    call file_cache.set(self.__name__, self._cached)
  endfunction
  call memory_cache.set(a:name, cache)
  return cache
endfunction " }}}
function! gista#util#init(prefix, settings) abort " {{{
  let prefix = empty(a:prefix)
        \ ? 'g:gista',
        \ : printf('g:gista#%s', a:prefix)
  for [key, Value] in a:settings
    let name = printf('%s#%s', prefix, key)
    if !exists(name)
      silent execute printf('let %s = %s', name, string(Value))
    endif
    unlet Value
  endfor
endfunction " }}}

let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
