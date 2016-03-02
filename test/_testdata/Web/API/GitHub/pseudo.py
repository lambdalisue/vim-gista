def _vim_vital_web_api_github_test_pseudo_request(url, headers={}, method=None):
    try:
        import json
    except ImportError:
        import simplejson as json
    try:
        from urllib.parse import urlparse, parse_qs
    except ImportError:
        from urlparse import urlparse, parse_qs

    class PseudoHTTPResponse(object):
        def __init__(self, status, reason, content, headers={}):
            self._status = status
            self._reason = reason
            self._content = content
            self._headers = headers
        def read(self, amt=None):
            return self._content
        def getheader(self, name, default=None):
            return self._headers.get(name, default)
        def getheaders(self):
            return tuple(self._header)
        def status(self):
            return self._status
        def reason(self):
            return self._reason
        def version(self):
            return 'HTTP/1.1'
        def msg(self):
            return ''

    scheme, netloc, path, params, query, fragment = urlparse(url)
    page = int(parse_qs(query).get('page', ['0'])[0])
    link_precursor = '<https://api.github.com/resource?page=%d>; rel="%s"'
    pseudo_entries = [{ 'id': i } for i in range(1, 301)]

    if page == 0:
        link = [
            link_precursor % (2, 'next'),
            link_precursor % (3, 'last'),
        ]
        entries = []
    elif page == 1:
        link = [
            link_precursor % (2, 'next'),
            link_precursor % (3, 'last'),
        ]
        entries = pseudo_entries[0:100]
    elif page == 2:
        link = [
            link_precursor % (1, 'first'),
            link_precursor % (1, 'prev'),
            link_precursor % (3, 'next'),
            link_precursor % (3, 'last'),
        ]
        entries = pseudo_entries[100:200]
    elif page == 3:
        link = [
            link_precursor % (1, 'first'),
            link_precursor % (2, 'prev'),
        ]
        entries = pseudo_entries[200:300]
    else:
        raise Exception(
            'vital: Web.API.GitHub: Unexpected request (%s)' % url
        )
    content = json.dumps(entries).encode('utf-8')
    return PseudoHTTPResponse(200, 'OK', content, {
        'link': ','.join(link),
    })

