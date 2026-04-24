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


def _download_image(url, app):
    if not url:
        return ''

    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https'):
        raise ValueError('Only http(s) image URLs are allowed')
    if parsed.hostname in ('localhost', '127.0.0.1', '::1'):
        raise ValueError('Local URLs are not allowed')

    response = requests.get(url, timeout=5)
    response.raise_for_status()

    download_image_path = f"{app.config['PUBLIC_UPLOAD_FOLDER']}/downloaded-image.png"
    with open(download_image_path, 'wb') as file:
        file.write(response.content)

    public_url = f"{app.config['PUBLIC_UPLOADS_URL']}/downloaded-image.png"

    return public_url