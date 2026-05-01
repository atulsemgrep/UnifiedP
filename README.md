# bad-python-app

A deliberately vulnerable Flask app. Useful for trying out scanners, doing security
training, or just poking around to see what bad code looks like in practice.

Don't deploy this anywhere public. It's broken on purpose.


## What's in here

The app exposes a handful of pages, each one demonstrating a different class of bug:

- SQL injection (login + search)
- Reflected and stored XSS
- SSRF
- Path traversal
- IDOR
- Iframe injection
- Unrestricted file upload (uses ImageMagick, so beware of ImageTragic-era issues too)

Each one lives under `vulns/<category>/` and is wired into a route in `app.py`.
Templates are in `templates/`, static assets in `static/`, and the SQLite-backed
demo data lives in `data/`.

There are also some loose `vuln-*.py` / `vuln-main*.java` files at the root.
Those aren't part of the running app — they're standalone snippets used for
SAST testing.


## Requirements

- Python 3.7+
- ImageMagick (https://imagemagick.org)
- Docker, if you'd rather not install the above locally


## Running it

### Docker

```sh
docker build -t vuln-flask-web-app .
docker run -it -p 5000:5000 --rm --name vuln-flask-web-app vuln-flask-web-app
```

### Local

```sh
python3 -m venv venv
source venv/bin/activate
sh setup.sh
sh run.sh
```

Then open http://localhost:5000.

If you want to wipe the demo DB, there's a `POST /reset-database` endpoint, or
just hit the reset button on the home page.


## Locking it down (optional)

By default there's no auth and any request gets through. If you're running this
somewhere others can reach it (don't, but if you must), set an API key:

```sh
export VULN_FLASK_APP_API_KEY=myapisecret
```

Once that's set, every request needs an `api_key` cookie matching it:

```http
GET / HTTP/1.1
Host: localhost:5000
Cookie: api_key=myapisecret
```

The check lives in `middlewares.py`.


## CI

There's one GitHub Actions workflow: `.github/workflows/semgrep.yml`. It runs
Semgrep against the repo on:

- pushes to `main` (full scan, baseline)
- every pull request (diff-aware — only flags new findings)
- a daily cron at 17:23 UTC (catches new rules firing on existing code)
- manual `workflow_dispatch`

The job runs in the `semgrep/semgrep` container and just calls `semgrep ci`.
Dependabot PRs are skipped because they don't get repo secrets and the run
would fail.

It needs a `SEMGREP_APP_TOKEN` secret to push results to Semgrep Cloud:

```sh
gh secret set SEMGREP_APP_TOKEN --repo <owner>/<repo>
```

In a production pipeline you'd lean on the exit code of `semgrep ci` to gate
later stages (build, publish, deploy). A non-zero exit means one or more
findings tagged as **blocking** in the Semgrep Cloud policy were reported —
i.e. issues serious enough that the team has agreed shipping should stop
until they're triaged or fixed. **Monitor** and **comment** findings still
surface but don't fail the run, so they don't block the pipeline. That
classification lives in the Semgrep Cloud rule policy, not in the workflow
file.

This repo doesn't wire up that gate because the whole point is to be
vulnerable — the scan is expected to light up on every run, and any gated
build job would never fire. See the comments in the workflow for the shape
a real one would take.


## Demoing diff-aware scans locally

To see the difference between a full scan and a diff-aware scan, create a
branch with a single new vulnerable line and scan it against `main` as the
baseline:

```sh
# Create a branch and add one new vulnerable line
git checkout -b test-diff-aware
echo 'eval(input())' >> vuln-1.py
git add vuln-1.py
git commit -m "test: add one new vuln for diff scan"

# Run a diff-aware scan against main as the baseline
SEMGREP_BASELINE_REF=main semgrep scan --config auto
```

Expected output: one finding (the `eval(input())` you just added), not the
dozens that exist across the rest of the repo. If you see all the existing
findings too, diff-aware didn't engage.

To compare, run it without the baseline:

```sh
semgrep scan --config auto
```

You should see a flood of findings — that's the full-repo baseline. The
contrast between the two runs is the demo.


## Layout

```
app.py            # routes
db_helper.py      # sqlite setup + reset
db_models.py      # demo data
middlewares.py    # api key gate
vulns/            # one folder per vuln category
templates/        # jinja templates
static/           # css, images, uploads
data/             # seed data
```


## License

See `LICENSE`.
