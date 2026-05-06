import ipaddress
import socket
import requests
from urllib.parse import urlparse
from flask import render_template


def ssrf_page(request, app):
    return render_template(
        'ssrf.html'
    )


def ssrf_api(request, app):
    form = request.form

    name = form['name']
    email = form['email']
    original_picture_url = form['imageUrl']

    downloaded_url = _download_image(original_picture_url, app)

    return render_template(
        'ssrf.html',
        email=email,
        name=name,
        original_url=original_picture_url,
        profile_picture_url=downloaded_url
    )


def _validate_url(url):
    """Raise ValueError if url is not a safe, externally-reachable http(s) URL.

    Checks performed:
    1. Scheme must be http or https (blocks file://, gopher://, etc.)
    2. Hostname resolves to at least one IP address (catches unresolvable hosts)
    3. Every resolved IP is checked with ipaddress — blocks loopback (127.x, ::1),
       private ranges (10.x, 172.16-31.x, 192.168.x), link-local (169.254.x — AWS/GCP
       metadata endpoint), reserved, multicast, and unspecified (0.0.0.0) addresses.
       Resolving *before* the request closes the DNS-rebinding window.
    """
    parsed = urlparse(url)

    if parsed.scheme not in ('http', 'https'):
        raise ValueError('Only http(s) image URLs are allowed')

    hostname = parsed.hostname
    if not hostname:
        raise ValueError('Invalid URL: missing hostname')

    # Resolve the hostname now, before the request, so the check and the
    # connection use the same network path (mitigates DNS rebinding).
    try:
        addr_infos = socket.getaddrinfo(hostname, None)
    except socket.gaierror as exc:
        raise ValueError(f'Could not resolve hostname: {hostname}') from exc

    if not addr_infos:
        raise ValueError(f'No addresses returned for hostname: {hostname}')

    for addr_info in addr_infos:
        ip_str = addr_info[4][0]
        try:
            ip = ipaddress.ip_address(ip_str)
        except ValueError as exc:
            raise ValueError(f'Unparseable IP address: {ip_str}') from exc

        if (
            ip.is_loopback      # 127.x.x.x, ::1
            or ip.is_private    # 10.x, 172.16-31.x, 192.168.x, fd00::/8, ...
            or ip.is_link_local # 169.254.x.x (AWS/GCP metadata), fe80::/10
            or ip.is_reserved   # IANA reserved blocks
            or ip.is_multicast  # 224.x – 239.x
            or ip.is_unspecified  # 0.0.0.0, ::
        ):
            raise ValueError(f'URL resolves to a forbidden address: {ip_str}')


def _download_image(url, app):
    if not url:
        return ''

    _validate_url(url)

    # allow_redirects=False prevents a redirect chain from bypassing the
    # _validate_url check (e.g., attacker's server 302s to 169.254.169.254).
    response = requests.get(url, timeout=5, allow_redirects=False)
    response.raise_for_status()

    download_image_path = f"{app.config['PUBLIC_UPLOAD_FOLDER']}/downloaded-image.png"
    with open(download_image_path, 'wb') as file:
        file.write(response.content)

    public_url = f"{app.config['PUBLIC_UPLOADS_URL']}/downloaded-image.png"

    return public_url