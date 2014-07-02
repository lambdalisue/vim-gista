"******************************************************************************
" Gista command options
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:get_parser() " {{{
  if !exists('s:parser') || 1
    let s:parser = gista#utils#option#new()
    call s:parser.add_argument(
          \ '--login',
          \ 'Login Gist API', {
          \   'conflicts': 'command',
          \})
    call s:parser.add_argument(
          \ '--logout',
          \ 'Logout Gist API', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \})
    call s:parser.add_argument(
          \ '--permanently',
          \ 'Logout permanently', {
          \   'kind': s:parser.SWITCH,
          \   'subordinations_of': 'logout',
          \})
    call s:parser.add_argument(
          \ '--list', '-l',
          \ 'List gists and show in gist list window', {
          \   'conflicts': 'command',
          \})
    call s:parser.add_argument(
          \ '--page',
          \ 'Specify a page index of gist list', {
          \   'kind': s:parser.VALUE,
          \   'subordinations_of': 'list',
          \})
    call s:parser.add_argument(
          \ '--nocache',
          \ 'Get gist list without using cache', {
          \   'kind': s:parser.SWITCH,
          \   'subordinations_of': 'list',
          \})
    call s:parser.add_argument(
          \ '--open', '-o',
          \ 'Open a specified gist in a gist buffer', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--post',
          \ 'Post a buffer to create/modify a gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of the posting gist', {
          \   'kind': s:parser.VALUE,
          \   'subordinations_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--multiple', '-m',
          \ 'Post a gist with all visible buffers', {
          \   'kind': s:parser.SWITCH,
          \   'subordinations_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--anonymous', '-a',
          \ 'Post a gist as an anonymous gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'publish_status',
          \   'subordinations_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--private', '-p',
          \ 'Post a gist as a private gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'publish_status',
          \   'subordinations_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--public', '-P',
          \ 'Post a gist as a public gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'publish_status',
          \   'subordinations_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--gistid',
          \ 'Specify a gist ID', {
          \   'kind': s:parser.VALUE,
          \   'subordinations_of': [
          \     'open', 'post', 'rename', 'remove', 'delete',
          \     'star', 'unstar', 'is-starred', 'fork',
          \     'disconnect', 'yank',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--filename',
          \ 'Specify a filename', {
          \   'kind': s:parser.VALUE,
          \   'subordinations_of': [
          \     'open', 'rename', 'remove', 'disconnect', 'yank',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--rename',
          \ 'Rename a filename of a file in the gist', {
          \   'conflicts': 'command',
          \   'requires': ['gistid', 'filename'],
          \})
    call s:parser.add_argument(
          \ '--remove',
          \ 'Remove a file from the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': ['gistid', 'filename'],
          \})
    call s:parser.add_argument(
          \ '--delete',
          \ 'Delete the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--star',
          \ 'Star the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--unstar',
          \ 'Unstar the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--is-starred',
          \ 'Display if the gist is starred', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--fork',
          \ 'Fork the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--browse',
          \ 'Browse the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--disconnect',
          \ 'Disconnect a buffer from the gist', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--yank',
          \ 'Yank Gist ID (and filename)', {
          \   'kind': s:parser.SWITCH,
          \   'conflicts': 'command',
          \   'requires': 'gistid',
          \})
    function! s:parser._pre_process(options) abort " {{{
      let options = a:options
      " post (if no conflict options are specified)
      if !self.has_conflicts('post', options)
        let options['post'] = self.TRUE
      endif
      " gistid (GistPost does not require gistid but use)
      if self.has_subordinated('gistid', options)
        let gistid = gista#utils#find_gistid(
              \   a:options.__range__[0],
              \   a:options.__range__[1],
              \)
        if !empty(gistid)
          let options['gistid'] = gistid
        endif
      endif
      " filename
      if exists('b:gistinfo') && self.has_subordinated('filename', options)
        let options['filename'] = b:gistinfo.filename
      endif
      return options
    endfunction " }}}
    function! s:parser._post_process(options) abort " {{{
      let options = a:options
      " private => public
      if has_key(options, 'private')
        let value = options.private
        unlet options['private']
        let options['public'] = !value
      endif
      return options
    endfunction " }}}
  endif
  return s:parser
endfunction " }}}


function! gista#interface#option#parse(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.parse, a:000, parser)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
