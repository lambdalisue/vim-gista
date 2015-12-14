import re
import sys
import json
import collections
from itertools import chain
from threading import Lock, Thread
try:
    from urllib.request import urlopen, Request
    from urllib.parse import urlparse, parse_qs, urlencode, urlunparse, urljoin
    from queue import Queue
except ImportError:
    from urllib2 import urlopen, Request
    from urlparse import urlparse, parse_qs, urlencode, urlunparse, urljoin
    from Queue import Queue
try:
    import vim
except ImportError:
    vim = None

def format_exception():
    """Return a current exception as a user friendly string"""
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
    return { 'Authorization': 'token %s' % token } if token else {}

def build_url(url, **kwargs):
    scheme, netloc, path, params, query, fragment = urlparse(url)
    p = parse_qs(query)
    p.update(kwargs)
    return urlunparse([
        scheme, netloc, path, params,
        urlencode(p, doseq=True), fragment
    ])

def request_head(url, name, headers={}):
    if sys.version_info >= (3, 0, 0):
        req = Request(url, headers=headers, method='HEAD')
        res = urlopen(req)
        return res.getheader(name)
    else:
        req = Request(url, headers=headers)
        req.get_method = lambda: 'HEAD'
        res = urlopen(req)
        return res.info().getheader(name)

def request_json(url, headers={}, **kwargs):
    url = build_url(url, **kwargs)
    res = urlopen(Request(url, headers=headers))
    obj = json.loads(res.read().decode('utf-8'))
    return to_vim(obj)

def _request(lock, queue, entries_per_pages, url, headers, callback=None):
    while not queue.empty():
        page, indicator = queue.get()
        try:
            entries = request_json(url, headers=headers, page=page)
            entries_per_pages.append([page, entries])
        except:
            entries_per_pages.append([page, format_exception()])
        if callback:
            callback(lock, indicator % len(entries_per_pages))
        queue.task_done()

def request(url, token,
            indicator='Requesting entries and converting into JSON %%d/%d ...',
            nprocess=20, callback=None, **kwargs):
    nprocess = int(nprocess) # nprocess might given from Vim as 'str'
    url = build_url(url, **kwargs)
    headers = build_headers(token)
    lock  = Lock()
    queue = Queue()
    entries_per_pages = collections.deque()
    try:
        # figure out the number of pages from HEAD request
        if callback:
            callback(lock, 'Requesting the total number of pages ...')
        response_link = request_head(url, 'link', headers=headers)
        if response_link:
            m = re.search('<.*?[?&]page=(\d+)[^>]*>; rel="last"', response_link)
            page_count = int(m.group(1)) if m else 1
        else:
            page_count = 1
        # prepare task queue
        for page in range(1, page_count + 1):
            queue.put([page, indicator % page_count])
        # start workers
        kwargs = dict(
            target=_request,
            args=(lock, queue, entries_per_pages, url, headers, callback),
        )
        workers = [Thread(**kwargs) for n in range(nprocess)]
        for worker in workers:
            worker.start()
        # join until all quese are processed and all workers has terminated
        for worker in workers:
            worker.join()
        # merge and flatten entries
        entries_or_exceptions = map(
            lambda x: x[1],
            sorted(entries_per_pages, key=lambda x: x[0])
        )
        entries = chain.from_iterable(
            filter(lambda x: isinstance(x, list), entries_or_exceptions)
        )
        exceptions = chain.from_iterable(
            filter(lambda x: not isinstance(x, list), entries_or_exceptions)
        )
        return list(entries), list(exceptions)
    except:
        return list(), [format_exception()]

def echo_status_stderr(lock, indicator):
    with lock:
        sys.stderr.write((' ' * 80) + "\r")
        sys.stderr.write(indicator + "\r")
        sys.stderr.flush()

def echo_status_vim(lock, indicator):
    if vim:
        with lock:
            vim.command("redraw | echo '%s'" % indicator)
    else:
        raise ImportError('"vim" has not been available.')

def console():
    import os, ast
    import argparse

    parser = argparse.ArgumentParser(
        description='Request gists of a particular API for vim-gista',
    )
    parser.add_argument(
        '--url', default='https://api.github.com',
        help='An URL to request',
    )
    parser.add_argument(
        '--apiname', default='GitHub',
        help='An API name for a token cache',
    )
    parser.add_argument(
        '--username',
        help='A username for a token cache',
    )
    parser.add_argument(
        '--cache-dir', default='~/.cache/vim-gista',
        help='A cache directory for a token cache',
    )
    parser.add_argument(
        '--lookup', default='public',
    )
    parser.add_argument(
        '--since', default='',
    )
    parser.add_argument(
        '--per-page', type=int, default=100,
    )
    parser.add_argument(
        '--nprocess', type=int, default=50,
    )
    args = parser.parse_args()

    # get a cached token if username is specified
    if args.username:
        cache_file = os.path.expanduser(os.path.join(
            args.cache_dir, 'token', args.apiname,
        ))
        if not os.path.exists(cache_file):
            sys.stderr.write((
                'A token cache file "%s" is not found. '
                'Create a token cache with vim-gista and try again.\n'
            ) % cache_file)
            sys.exit(1)
        with open(cache_file) as fi:
            tokens =ast.literal_eval(fi.read())
        if args.username not in tokens:
            sys.stderr.write((
                'A token for "%s" is not found. '
                'Create a token cache with vim-gista and try again.\n'
            ) % args.username)
            sys.exit(1)
        token = tokens[args.username]
    else:
        token = ''

    # get correct URL from lookup
    lookup = args.lookup
    if lookup == 'public':
        baseurl = urljoin(args.url, 'gists/public')
    elif args.username and lookup == '%s/starred' % (args.username):
        baseurl = urljoin(args.url, 'gists/starred')
    elif args.username and lookup == args.username:
        baseurl = urljoin(args.url, 'gists')
    else:
        baseurl = urljoin(args.url, 'users/%s/gists' % lookup)
    url = build_url(baseurl, since=args.since, per_page=args.per_page)
    entries, exceptions = request(
        url, token,
        nprocess=args.nprocess,
        callback=echo_status_stderr,
    )
    sys.stderr.write("\n")
    sys.stdout.write(str(entries) + "\n")
    sys.stderr.write("\n".join(exceptions) + "\n")


if __name__ == '__main__':
    console()

