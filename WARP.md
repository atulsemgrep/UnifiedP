# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a vulnerable Flask web application designed for security testing and demonstration purposes. The app contains intentional security vulnerabilities including SQL injection, XSS, SSRF, path traversal, IDOR, and file upload vulnerabilities.

## Development Commands

### Setup
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
sh setup.sh
```

### Running the Application
```bash
# Development mode (Flask dev server)
sh run.sh

# Production mode (using Waitress)
sh run.prod.sh
```

### Docker
```bash
# Build Docker image
docker build -t vuln-flask-web-app .

# Run container
docker run -it -p 5000:5000 --rm --name vuln-flask-web-app vuln-flask-web-app
```

### Security Scanning
The project uses Semgrep for security scanning via CircleCI. The CI pipeline automatically runs on PRs and commits to generate `findings.json` and `findings_summary.json`.

## Architecture

### Application Structure
- **app.py**: Main Flask application with route definitions for all vulnerability demonstrations
- **db_helper.py**: SQLite database wrapper using in-memory database (temp/database.db)
- **db_models.py**: Database models (UserDbModel)
- **middlewares.py**: API key authentication middleware (optional)
- **vulns/**: Directory containing vulnerability demonstration modules organized by type:
  - `sql_injection/`: Login and search injection examples
  - `xssinjection/`: Reflected and stored XSS
  - `file_upload/`: File upload vulnerabilities with ImageMagick integration
  - `ssrf/`: Server-Side Request Forgery
  - `path_traversal/`: Path traversal examples
  - `idor/`: Insecure Direct Object Reference
  - `iframe_injection/`: iFrame injection examples

### Database
- Uses SQLite with database stored at `temp/database.db`
- Initialized automatically on first run with sample data:
  - Users table (with admin and test user)
  - Messages table (for stored XSS demo)
  - Products table (for search demo)
- Database can be reset via `/reset-database` endpoint

### Configuration
- **TEMP_UPLOAD_FOLDER**: `{root}/temp/uploads` - temporary file storage
- **PUBLIC_UPLOAD_FOLDER**: `{root}/static/uploads` - public uploads
- **PUBLIC_IMG_FOLDER**: `{root}/static/img` - static images
- **API Key (optional)**: Set via `VULN_FLASK_APP_API_KEY` environment variable. When set, all requests require an `api_key` cookie matching this value.

### Dependencies
- Flask 2.0.1 with Jinja2 templating
- SQLite3 for database
- ImageMagick (system dependency) for image processing
- Waitress for production WSGI server
- requests, lxml for various vulnerability demonstrations

## Important Notes

- This application contains **intentional security vulnerabilities** for educational purposes
- Never deploy this application to production or expose it to untrusted networks
- The database contains hardcoded credentials (md5 hashes) for demo purposes
- Files in `api_keys.py` contain test API keys (Google reCAPTCHA test keys)
- ImageMagick is required system dependency for file upload functionality
