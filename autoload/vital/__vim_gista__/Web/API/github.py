try:
    import vim
except ImportError:
    raise ImportError(
        '"vim" is not available. This module require to be loaded from Vim.'
    )


#
# NOTE
#   Vim use a global namespace for python/python3 so define a unique name
#   function and write a code inside of the function to prevent conflicts.
#
def _vim_vital_web_api_github_main():
    """A namespace function for Vital.Web.API.GitHub"""
    import re
    import sys
    import ssl
    import collections
    from itertools import chain
    from threading import Lock, Thread
    try:
        import json
    except ImportError:
        import simplejson as json
    try:
        from urllib.request import urlopen, Request
        from urllib.parse import (urlparse, parse_qs, urlencode, urlunparse)
    except ImportError:
        from urllib2 import urlopen, Request
        from urllib import urlencode
        from urlparse import (urlparse, parse_qs, urlunparse)

    DEFAULT_INDICATOR = (
        'Requesting entries and converting into '
        'JSON %%(page)d/%(page_count)d ...'
    )

    def format_exception():
        exc_type, exc_obj, tb = sys.exc_info()
        f = tb.tb_frame
        lineno = tb.tb_lineno
        filename = f.f_code.co_filename
        return "%s: %s at %s:%d" % (
            exc_obj.__class__.__name__,
            exc_obj, filename, lineno,
        )

    def to_vim(obj):
        if obj is None:
            return ''
        elif isinstance(obj, bool):
            return int(obj)
        elif isinstance(obj, dict):
            return dict([to_vim(k), to_vim(v)] for k, v in obj.items())
        elif isinstance(obj, (list, tuple)):
            return list(to_vim(v) for v in obj)
        return obj

    def build_headers(token):
        return {'Authorization': 'token %s' % token} if token else {}

    def build_url(url, **kwargs):
        scheme, netloc, path, params, query, fragment = urlparse(url)
        p = parse_qs(query)
        p.update(kwargs)
        return urlunparse([
            scheme, netloc, path, params,
            urlencode(p, doseq=True), fragment
        ])

    def request(url, headers={}, method=None):
        if method:
            if sys.version_info.major >= 3:
                req = Request(url, headers=headers, method=method)
            else:
                req = Request(url, headers=headers)
                req.get_method = lambda: method
        else:
            req = Request(url, headers=headers)
        context = ssl._create_unverified_context()
        res = urlopen(req, context=context)
        if not hasattr(res, 'getheader'):
            # urllib2 does not have getheader
            res.getheader = lambda name, self=res: self.info().getheader(name)
        return res

    def request_head(url, name, headers={}):
        res = request(url, headers=headers, method='HEAD')
        return res.getheader(name)

    def request_json(url, headers={}, **kwargs):
        url = build_url(url, **kwargs)
        res = request(url, headers=headers)
        obj = json.loads(res.read().decode('utf-8'))
        return to_vim(obj)

    def _request_entries(lock, queue, entries_per_pages, url,
                         headers, callback=None):
        try:
            while True:
                page, indicator = queue.popleft()
                entries = request_json(url, headers=headers, page=page)
                entries_per_pages.append([page, entries])
                if callback:
                    message = indicator % {'page': len(entries_per_pages)}
                    if hasattr(vim, 'async_call'):
                        with lock:
                            vim.async_call(callback, message)
                    else:
                        with lock:
                            callback(message)
        except IndexError:
            pass
        except Exception as e:
            # clear queue to stop other threads
            queue.clear()
            entries_per_pages.append(e)

    def request_entries(url, token,
                        indicator=DEFAULT_INDICATOR,
                        page_start=1, page_end=0,
                        nprocess=20, callback=None, **kwargs):
        # the followings might be str when specified from Vim.
        page_start = int(page_start)
        page_end = int(page_end)
        nprocess = int(nprocess)

        url = build_url(url, **kwargs)
        headers = build_headers(token)
        lock = Lock()
        queue = collections.deque()
        entries_per_pages = collections.deque()
        # figure out the number of pages from HEAD request
        if page_end == 0:
            if callback:
                callback('Requesting the total number of pages ...')
            response_link = request_head(url, 'link', headers=headers)
            if response_link:
                m = re.search(
                    '<.*?[?&]page=(\d+)[^>]*>; rel="last"', response_link
                )
                page_end = int(m.group(1)) if m else 1
            else:
                page_end = 1
        # prepare task queue
        for page in range(page_start, page_end + 1):
            queue.append([page, indicator % {
                'url': url,
                'page_count': page_end - page_start + 1
            }])
        # start workers
        kwargs = dict(
            target=_request_entries,
            args=(lock, queue, entries_per_pages, url, headers, callback),
        )
        workers = [Thread(**kwargs) for n in range(nprocess)]
        for worker in workers:
            worker.start()
        for worker in workers:
            worker.join()
        # check if sub-thread throw exceptions or not
        exceptions = list(
            filter(lambda x: not isinstance(x, list), entries_per_pages)
        )
        if len(exceptions):
            raise exceptions[0]
        # merge and flatten entries
        return list(chain.from_iterable(map(
            lambda x: x[1], sorted(entries_per_pages, key=lambda x: x[0])
        )))

    def echo_status_vim(indicator):
        vim.command('redraw | echo "%s"' % indicator)

    if sys.version_info < (3, 0, 0):
        def ensure_unicode(s, encoding):
            if isinstance(s, unicode):
                return s
            else:
                return s.decode(encoding)
    else:
        def ensure_unicode(s, encoding):
            if not isinstance(s, bytes):
                return s
            else:
                return s.decode(encoding)


    # Execute a main code
    namespace = {}
    try:
        # Override 'request' with 'pseudo_requst' if exists
        try:
            request = _vim_vital_web_api_github_test_pseudo_request
        except NameError:
            pass
        encoding = vim.eval('&encoding')
        kwargs = vim.eval('kwargs')
        kwargs = { ensure_unicode(k, encoding): ensure_unicode(v, encoding)
                   for k, v in kwargs.items()}
        if kwargs.pop('verbose', 1):
            kwargs['callback'] = echo_status_vim
        entries = request_entries(**kwargs)
        namespace['entries'] = entries
    except:
        namespace['exception'] = format_exception()

    return namespace

# Call a namespace function
_vim_vital_web_api_github_response = _vim_vital_web_api_github_main()
