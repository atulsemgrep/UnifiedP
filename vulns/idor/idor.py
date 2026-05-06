from flask import render_template, redirect, url_for, session
from werkzeug.security import check_password_hash


def idor_login_page(request, app):
    return render_template('idor/idor_login.html')


def idor_login_api(request, app):
    form = request.form

    username = form.get('username')
    password = form.get('password')

    if not username or not password:
        return render_template('idor/idor_login.html', error=True)

    db_result = app.db_helper.execute_read(
        "SELECT * FROM users WHERE username=:username",
        { 'username': username }
    )

    if len(db_result) == 0:
        return render_template('idor/idor_login.html', error=True)

    user = app.db_models.UserDbModel(db_result[0])

    if not check_password_hash(user.password, password):
        return render_template('idor/idor_login.html', error=True)

    session['user_id'] = user.id
    session.permanent = True

    return redirect(url_for('idor_profile'))


def idor_profile_page(request, app):
    user_id = session.get('user_id')

    if not user_id:
        return redirect(url_for('idor_login'))

    db_result = app.db_helper.execute_read(
        "SELECT * FROM users WHERE id=:user_id",
        { 'user_id': user_id }
    )

    if len(db_result) == 0:
        return redirect(url_for('idor_login'))

    user = app.db_models.UserDbModel(db_result[0])
    return render_template('idor/idor_profile.html', user=user)


