import json
import sys

# Read the JSON file
with open('findings.json', 'r') as f:
    data = json.load(f)

# Filter for only ERROR severity
errors = [
    finding for finding in data['results']  # Loop through all findings
    if finding['extra']['severity'] == 'ERROR'  # Keep only errors
]

# Print count and details
print(f"Found {len(errors)} ERROR severity findings:\n")

for error in errors:
    print(f"File: {error['path']}")
    print(f"Line: {error['start']['line']}")
    print(f"Rule: {error['check_id']}")
    print(f"Message: {error['extra']['message']}")
    print("-" * 80)