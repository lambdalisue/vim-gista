"******************************************************************************
" A simple filebased cache system
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


let s:directory = get(g:, 'gista#utils#cache#directory', '')
let s:directory = empty(s:directory) ? g:gista#directory . "cache/" : s:directory
let s:prototype = {}

function! s:prototype.get(name) abort dict " {{{
  if has_key(self.cached, a:name)
    return self.cached[a:name]
  else
    return self.default
  endif
endfunction " }}}
function! s:prototype.set(name, value, ...) abort dict " {{{
  let settings = extend({
        \ 'autosave': 1,
        \}, get(a:000, 0, {}))
  let self.cached[a:name] = a:value
  if settings.autosave
    call self.save()
  endif
endfunction " }}}
function! s:prototype.has(name) abort dict " {{{
  return has_key(self.cached, a:name)
endfunction " }}}
function! s:prototype.remove(name, ...) abort dict " {{{
  let settings = extend({
        \ 'autosave': 1,
        \}, get(a:000, 0, {}))
  if self.has(a:name)
    unlet self.cached[a:name]
  endif
  if settings.autosave
    call self.save()
  endif
endfunction " }}}
function! s:prototype.clear(...) abort dict " {{{
  let settings = extend({
        \ 'autosave': 1,
        \}, get(a:000, 0, {}))
  let self.cached = {}
  if settings.autosave
    call self.save()
  endif
endfunction " }}}
function! s:prototype.save() abort dict " {{{
  let created = !filereadable(self.filename)
  call writefile([gista#utils#vital#json_encode(self.cached)], self.filename)
  if created && !gista#utils#vital#is_windows()
    call gista#utils#vital#system('chmod 600 ' . self.filename)
  endif
  let self.last_updated = strftime("%FT%T%z")
endfunction " }}}
function! s:prototype.load() abort dict " {{{
  if filereadable(self.filename)
    let content = join(readfile(self.filename), '')
    let self.cached = gista#utils#vital#json_decode(content)
    let self.last_updated = strftime("%FT%T%z", getftime(self.filename))
  endif
endfunction " }}}

function! gista#utils#cache#new(name, directory, ...) abort " {{{
  let settings = extend({
        \ 'autoload': 1,
        \ 'default': '',
        \}, get(a:000, 0, {}))
  let obj = extend(copy(s:prototype), {
        \ 'cached': {},
        \ 'last_updated': '',
        \ 'default': settings.default,
        \})
  let obj.directory = empty(a:directory) ? s:directory : a:directory
  let obj.directory = fnamemodify(expand(obj.directory), ':p')
  let obj.filename = obj.directory . a:name . '.json'
  " create if the directory is not exists
  if !isdirectory(obj.directory)
    call mkdir(obj.directory, 'p', 0700)
  endif
  if settings.autoload
    call obj.load()
  endif
  return obj
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
