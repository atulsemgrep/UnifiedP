import os
import subprocess
import shlex
import flask

app = flask.Flask(__name__)


@app.route("/route_param/<route_param>")
def route_param(route_param):
    # Fixed: Allowlist approach to prevent command injection
    # Only allow specific, safe commands
    ALLOWED_COMMANDS = {
        'date': ['/bin/date'],
        'uptime': ['/usr/bin/uptime'],
        'whoami': ['/usr/bin/whoami']
    }
    
    if route_param == 'date':
        command = ['/bin/date']
    elif route_param == 'uptime':
        command = ['/usr/bin/uptime']
    elif route_param == 'whoami':
        command = ['/usr/bin/whoami']
    else:
        return flask.jsonify({"error": "Command not allowed"}), 403

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=5,
            check=False
        )
        return flask.jsonify({"output": result.stdout, "command": route_param})
    except Exception as e:
        return flask.jsonify({"error": str(e)}), 400


# Flask true negatives
@app.route("/route_param/<route_param>")
def route_param2(route_param):

    # ok:dangerous-os-exec
    os.execl("static")

    return "ok!"
