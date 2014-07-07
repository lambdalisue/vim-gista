"******************************************************************************
" Vital
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


let s:V = vital#of('vim_gista')
function! gista#utils#vital#get_vital() " {{{
  return s:V
endfunction " }}}
function! s:get_list() " {{{
  if !exists('s:List')
    let s:List = gista#utils#vital#get_vital().import('Data.List')
  endif
  return s:List
endfunction " }}}
function! s:get_dict() " {{{
  if !exists('s:Dict')
    let s:Dict = gista#utils#vital#get_vital().import('Data.Dict')
  endif
  return s:Dict
endfunction " }}}
function! s:get_base64() " {{{
  if !exists('s:Base64')
    let s:Base64 = gista#utils#vital#get_vital().import('Data.Base64')
  endif
  return s:Base64
endfunction " }}}
function! s:get_http() " {{{
  if !exists('s:HTTP')
    let s:HTTP = gista#utils#vital#get_vital().import('Web.HTTP')
  endif
  return s:HTTP
endfunction " }}}
function! s:get_json() " {{{
  if !exists('s:JSON')
    let s:JSON = gista#utils#vital#get_vital().import('Web.JSON')
  endif
  return s:JSON
endfunction " }}}
function! s:get_path() " {{{
  if !exists('s:Path')
    let s:Path = gista#utils#vital#get_vital().import('System.Filepath')
  endif
  return s:Path
endfunction " }}}
function! s:get_process() " {{{
  if !exists('s:Process')
    let s:Process = gista#utils#vital#get_vital().import('Process')
  endif
  return s:Process
endfunction " }}}
function! s:get_datetime() " {{{
  if !exists('s:DateTime')
    let s:DateTime = gista#utils#vital#get_vital().import('DateTime')
  endif
  return s:DateTime
endfunction " }}}

" Prelude
function! gista#utils#vital#is_windows() " {{{
  "return s:get_prelude().is_windows()
  return (has('win16') || has('win32') || has('win64'))
endfunction " }}}

" Path
function! gista#utils#vital#path_join(...) " {{{
  return call(s:get_path().join, a:000)
endfunction " }}}

" List
function! gista#utils#vital#cons(...) " {{{
  return call(s:get_list().cons, a:000)
endfunction " }}}
function! gista#utils#vital#concat(...) " {{{
  return call(s:get_list().concat, a:000)
endfunction " }}}
function! gista#utils#vital#zip(...) " {{{
  return call(s:get_list().zip, a:000)
endfunction " }}}

" Dict
function! gista#utils#vital#pick(...) " {{{
  return call(s:get_dict().pick, a:000)
endfunction " }}}
function! gista#utils#vital#omit(...) " {{{
  return call(s:get_dict().omit, a:000)
endfunction " }}}

" Base64
function! gista#utils#vital#base64_encode(...) " {{{
  return call(s:get_base64().encode, a:000)
endfunction " }}}

" HTTP
function! gista#utils#vital#request(method, url, ...) abort " {{{
  let settings = extend({
        \ 'client': g:gista#disable_python_client ? ['curl', 'wget'] : ['python', 'curl', 'wget'],
        \}, get(a:000, 0, {}))
  return s:get_http().request(a:method, a:url, settings)
endfunction
function! gista#utils#vital#get(url, params, headers, ...) abort " {{{
  let settings = extend({
        \ 'default_content': s:consts.DEFAULT_CONTENT,
        \}, get(a:000, 0, {}))
  let settings['param'] = a:params
  let settings['headers'] = a:headers
  let res = gista#utils#vital#request('GET', a:url, settings)
  let res.content = get(res, 'content', settings.default_content)
  let res.content = s:get_json().decode(
        \ empty(res.content) ? settings.default_content : res.content)
  return res
endfunction " }}}
function! gista#utils#vital#post(url, params, headers, ...) abort " {{{
  let settings = extend({
        \ 'default_content': s:consts.DEFAULT_CONTENT,
        \}, get(a:000, 0, {}))
  let settings['data'] = s:get_json().encode(a:params)
  let settings['headers'] = a:headers
  let res = gista#utils#vital#request('POST', a:url, settings)
  let res.content = get(res, 'content', settings.default_content)
  let res.content = s:get_json().decode(
        \ empty(res.content) ? settings.default_content : res.content)
  return res
endfunction " }}}
function! gista#utils#vital#put(url, params, headers, ...) abort " {{{
  let settings = extend({
        \ 'default_content': s:consts.DEFAULT_CONTENT,
        \}, get(a:000, 0, {}))
  let settings['data'] = s:get_json().encode(a:params)
  let settings['headers'] = a:headers
  let res = gista#utils#vital#request('PUT', a:url, settings)
  let res.content = get(res, 'content', settings.default_content)
  let res.content = s:get_json().decode(
        \ empty(res.content) ? settings.default_content : res.content)
  return res
endfunction " }}}
function! gista#utils#vital#patch(url, params, headers, ...) abort " {{{
  let settings = extend({
        \ 'default_content': s:consts.DEFAULT_CONTENT,
        \}, get(a:000, 0, {}))
  let settings['data'] = s:get_json().encode(a:params)
  let settings['headers'] = a:headers
  let res = gista#utils#vital#request('PATCH', a:url, settings)
  let res.content = get(res, 'content', settings.default_content)
  let res.content = s:get_json().decode(
        \ empty(res.content) ? settings.default_content : res.content)
  return res
endfunction " }}}
function! gista#utils#vital#delete(url, headers, ...) abort " {{{
  let settings = extend({
        \ 'default_content': s:consts.DEFAULT_CONTENT,
        \}, get(a:000, 0, {}))
  let settings['headers'] = a:headers
  let res = gista#utils#vital#request('DELETE', a:url, settings)
  let res.content = get(res, 'content', settings.default_content)
  let res.content = s:get_json().decode(
        \ empty(res.content) ? settings.default_content : res.content)
  return res
endfunction " }}}

" JSON
function! gista#utils#vital#json_encode(...) " {{{
  return call(s:get_json().encode, a:000)
endfunction " }}}
function! gista#utils#vital#json_decode(...) " {{{
  return call(s:get_json().decode, a:000)
endfunction " }}}
function! gista#utils#vital#true() " {{{
  return s:get_json().true
endfunction " }}}
function! gista#utils#vital#false() " {{{
  return s:get_json().false
endfunction " }}}
function! gista#utils#vital#null() " {{{
  return s:get_json().null
endfunction " }}}
function! gista#utils#vital#to_boolean(value) " {{{
  return a:value ? gista#utils#vital#true() : gista#utils#vital#false()
endfunction " }}}

" System
function! gista#utils#vital#system(...) " {{{
  return call(s:get_process().system, a:000)
endfunction " }}}

" DateTime
function! gista#utils#vital#from_format(...) " {{{
  return call(s:get_datetime().from_format, a:000)
endfunction " }}}


let s:consts = {}
let s:consts.DEFAULT_CONTENT = '{}'

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
