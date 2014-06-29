"******************************************************************************
" A simple option parser
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:T()
  return 1
endfunction
function! s:F()
  return 0
endfunction

let s:prototype = {
      \ '_default_options': {},
      \ '_long_arguments': {},
      \ '_short_arguments': {},
      \ '_conflicts': {},
      \ '_subordinations_of': {},
      \ '_requires': {},
      \}
function! s:shellwords(str) abort " {{{
  let sd = '\([^ \t''"]\+\)'        " Space/Tab separated texts
  let sq = '''\zs\([^'']\+\)\ze'''  " Single quotation wrapped text
  let dq = '"\zs\([^"]\+\)\ze"'     " Double quotation wrapped text
  let pattern = printf('\%%(%s\|%s\|%s\)', sq, dq, sd)
  " Split texts by spaces between sd/sq/dq
  let words = split(a:str, printf('%s\zs\s*\ze', pattern))
  " Extract wrapped words
  let words = map(words, 'matchstr(v:val, "^" . pattern . "$")')
  return words
endfunction " }}}
function! s:prototype.add_argument(name, ...) abort " {{{
  " add_argument({name} [, {description}, {settings}])
  " add_argument({name} [, {short}, {description}, {settings}])
  " parse arguments
  let short = get(a:000, 0, '')
  let description = get(a:000, 1, '')
  let settings = get(a:000, 2, {})
  if type(description) == 4 " Dict
    let settings = description
    unlet description | let description = short
    let short = ''
  endif
  " specify default settings
  let settings = extend({
        \ 'kind': self.ANY,
        \ 'conflicts': [],
        \ 'subordinations_of': [],
        \ 'requires': [],
        \}, settings)
  " validation
  if a:name !~# '^--'
    throw 'Argument name must start from "--"'
  elseif !empty(short) && short !~# '^-'
    throw 'Argument short name must start from "-"'
  endif
  " truncate leading hyphen
  let name = a:name[2:]
  let short_name = empty(short) ? '' : short[1:]
  " store
  let self._long_arguments[name] = {
        \ 'short': short_name,
        \ 'description': description,
        \ 'settings': settings,
        \}
  " conflict group
  if type(settings.conflicts) == 1
    if empty(settings.conflicts)
      let conflicts = []
    else
      let conflicts = [settings.conflicts]
    endif
  else
    let conflicts = settings.conflicts
  endif
  unlet settings['conflicts']
  let settings.conflicts = conflicts
  for conflict in conflicts
    if !has_key(self._conflicts, conflict)
      let self._conflicts[conflict] = []
    endif
    call add(self._conflicts[conflict], name)
  endfor
  " subordinations_of
  if type(settings.subordinations_of) == 1
    if empty(settings.subordinations_of)
      let subordinations_of = []
    else
      let subordinations_of = [settings.subordinations_of]
    endif
  else
    let subordinations_of = settings.subordinations_of
  endif
  unlet settings['subordinations_of']
  let settings.subordinations_of = subordinations_of
  if !empty(subordinations_of)
    let self._subordinations_of[name] = subordinations_of
  endif
  " requires
  if type(settings.requires) == 1
    if empty(settings.requires)
      let requires = []
    else
      let requires = [settings.requires]
    endif
  else
    let requires = settings.requires
  endif
  unlet settings['requires']
  let settings.requires = requires
  if !empty(requires)
    let self._requires[name] = requires
  endif
  " default
  if has_key(settings, 'default')
    let self._default_options[name] = settings.default
  endif
  " short name link
  if !empty(short)
    let self._short_arguments[short[1:]] = a:name[2:]
  endif
endfunction " }}}
function! s:prototype._parse_args(bang, range, ...) abort " {{{
  let options = {
        \ '__bang__': a:bang == '!',
        \ '__range__': a:range,
        \ '__unknown__': [],
        \}
  let options = extend(self._default_options, options)
  let arguments = a:0 > 0 ? s:shellwords(a:1) : []
  let length = len(arguments)
  let cursor = 0
  while cursor < length
    let carg = arguments[cursor]
    let narg = length-1 == cursor ? '' : arguments[cursor+1]
    if carg =~# '^--\?'
      let name = matchstr(carg, '^--\?\zs.*\ze')
      " translate short argument name to long argument name
      if has_key(self._short_arguments, name)
        let name = self._short_arguments[name]
      endif
      " do I know the option?
      if has_key(self._long_arguments, name)
        if empty(narg) || narg =~# '^--\?'
          let Value = self.TRUE
        else
          let Value = narg
          let cursor += 1
        endif
        let options[name] = Value
        unlet Value
      else
        call add(options['__unknown__'], name)
      endif
    else
      call add(options['__unknown__'], carg)
    endif
    let cursor += 1
  endwhile
  return options
endfunction " }}}
function! s:prototype._validate_args(options) abort " {{{
  let options = copy(a:options)
  " Conflict
  for [kind, conflicts] in items(self._conflicts)
    let conflicted = filter(copy(options), 'index(conflicts, v:key) > -1')
    if len(conflicted) > 1
      redraw
      echohl ErrorMsg
      echo  'Conflicted options:'
      echohl None
      echo  'Options "' . join(keys(conflicted), ',') . '" are conflicted. '
      echon 'The ' . kind . ' options listed below cannot be specified in '
      echon 'same time.'
      for name in conflicts
        echo ' - ' name
      endfor
      echo  'The operation will be canceled.'
      return {}
    endif
  endfor
  " Subordinations
  for [name, allowed_list] in items(self._subordinations_of)
    if has_key(options, name)
      let found = 0
      for allowed in allowed_list
        if has_key(options, allowed)
          let found = 1
          break
        endif
      endfor
      if !found
        redraw
        echohl ErrorMsg
        echo  'Subordination miss match:'
        echohl None
        echo  '"' . name . '" option is a subordination option and '
        echon 'cannot be used except with the following options'
        for name in allowed_list
          echo ' - ' name
        endfor
        echo  'The operation will be canceled.'
        return {}
      endif
    endif
  endfor
  " Requires
  for [name, required_list] in items(self._requires)
    if has_key(options, name)
      for required in required_list
        if !has_key(options, required)
          redraw
          echohl ErrorMsg
          echo  'Required option is missing:'
          echohl None
          echo  '"' . name . '" option requires the following options but '
          echon '"' . required . '" is missing.'
          for name in required_list
            echo ' - ' name
          endfor
          echo  'The operation will be canceled.'
          return {}
        endif
      endfor
    endif
  endfor
  " Kind
  for [name, Value] in items(options)
    if name =~# '^__.*__$' || !has_key(self._long_arguments, name)
      unlet Value
      continue
    endif
    let kind = self._long_arguments[name].settings.kind
    if kind == self.SWITCH && type(Value) != 2
      redraw
      echohl ErrorMsg
      echo  'Unknown value is specified to SWITCH option:'
      echohl None
      echo  '"' . name . '" option does not take any value while it is SWITCH '
      echon 'option but "' . Value . '" is specified.'
      echo  'The operation will be canceled.'
      return {}
    elseif kind == self.VALUE && type(Value) == 2
      redraw
      echohl ErrorMsg
      echo  'No value is specified to VALUE option:'
      echohl None
      echo  '"' . name . '" option require a value while it is VALUE '
      echon 'option but no value is specified.'
      echo  'The operation will be canceled.'
      return {}
    endif
    " Translate value
    if type(Value) == 2
      let options[name] = Value()
    endif
    unlet Value
  endfor
  " success
  return options
endfunction " }}}
function! s:prototype.parse(...) abort " {{{
  let options = call(self._parse_args, a:000, self)
  let options = self._pre_process(options)
  let options = self._validate_args(options)
  if empty(options)
    return {}
  endif
  let options = self._post_process(options)
  return options
endfunction " }}}
function! s:prototype.has_any(names, options) abort " {{{
  for name in a:names
    if has_key(a:options, name)
      return 1
    endif
  endfor
  return 0
endfunction " }}}
function! s:prototype.has_all(names, options) abort " {{{
  for name in a:names
    if !has_key(a:options, name)
      return 0
    endif
  endfor
  return 1
endfunction " }}}
function! s:prototype.has_conflicts(name, options) abort " {{{
  let conflicts = self._long_arguments[a:name].settings.conflicts
  for conflict in conflicts
    if self.has_any(self._conflicts[conflict], a:options)
      return 1
    endif
  endfor
  return 0
endfunction " }}}
function! s:prototype.has_subordinated(name, options) abort " {{{
  let subordinations_of = self._subordinations_of[a:name]
  return self.has_any(subordinations_of, a:options)
endfunction " }}}
function! s:prototype.has_requires(name, options) abort " {{{
  let requires = self._requires[a:name]
  return self.has_all(requires, a:options)
endfunction " }}}
function! s:prototype._pre_process(options) abort " {{{
  " user should override this method to manipulate options
  return a:options
endfunction " }}}
function! s:prototype._post_process(options) abort " {{{
  " user should override this method to manipulate options
  return a:options
endfunction " }}}


function! gista#utils#option#new(...) " {{{
  let s:argument_parser = extend(
        \ deepcopy(s:prototype),
        \ get(a:000, 0, {})
        \)
  " define constant values
  let consts = {}
  let consts.TRUE = function("<SID>T")
  let consts.FALSE = function("<SID>F")
  let consts.ANY = 0
  let consts.SWITCH = 1
  let consts.VALUE = 2
  for [key, Value] in items(consts)
    let s:argument_parser[key] = Value
    lockvar s:argument_parser[key]
    unlet Value
  endfor
  return s:argument_parser
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
