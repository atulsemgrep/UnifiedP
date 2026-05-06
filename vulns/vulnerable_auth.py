# vulnerable_auth.py
def login(user, password):
    hardcoded_pw = "dangerousPW42"  # Hard-coded password - Vulnerable!
    if user == "admin" and password == hardcoded_pw:
        # authentication logic here
        return True
    return False
