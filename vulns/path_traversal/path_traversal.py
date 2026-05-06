
import os

from flask import render_template, send_file
from werkzeug.utils import safe_join
from werkzeug.exceptions import NotFound


def path_traversal_page(request, app):
    return render_template("path-traversal.html")


def path_traversal_image(request, app):
    img = request.args.get('img', '')

    # safe_join raises NotFound (HTTP 404) if `img` contains path traversal
    # sequences (../), absolute paths (/etc/passwd), or encoded variants
    # (%2F, %2e%2e) that would escape PUBLIC_IMG_FOLDER.
    try:
        image_path = safe_join(app.config['PUBLIC_IMG_FOLDER'], img)
    except NotFound:
        return 'File not found', 404

    if not os.path.isfile(image_path):
        return 'File not found', 404

    return send_file(image_path)