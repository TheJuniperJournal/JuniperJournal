#!/usr/bin/env python3
"""Exercise real APIs using two disposable, confirmed email accounts.

Credentials are read from a private JSON file, never printed. Creates labeled
private fixtures and cleans them up. Does not change/delete the accounts.
"""
import argparse
import base64
import json
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request
import uuid
from web_config import public_config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--accounts', type=Path, required=True)
    parser.add_argument('--env', type=Path, default=Path('.env.staging'))
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--allow-production', action='store_true')
    args = parser.parse_args()
    config = public_config(args.env.read_text())
    origin, key = config['SUPABASE_URL'], config['SUPABASE_KEY']
    if 'mltoisbukuhkxrdvndxl' in origin and not args.allow_production:
        parser.error('Use a separate test backend or explicitly allow production fixtures')
    accounts = json.loads(args.accounts.read_text())
    if len(accounts) != 2 or accounts[0]['email'] == accounts[1]['email']:
        parser.error('Two separate disposable accounts are required')
    results, sessions, project, objects = [], [], None, []
    marker = 'Launch QA ' + str(uuid.uuid4())

    def request(method, path, data=None, session=None, binary=False, extra=None):
        headers = {'apikey': key, 'Content-Type': 'image/png' if binary else 'application/json'}
        if session:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        if extra:
            headers.update(extra)
        payload = data if binary else (json.dumps(data).encode() if data is not None else None)
        req = urllib.request.Request(origin + path, method=method, data=payload, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read()
                if 'application/json' in response.headers.get('Content-Type', ''):
                    return response.status, json.loads(raw) if raw else None
                return response.status, raw
        except urllib.error.HTTPError as error:
            raw = error.read()
            try:
                body = json.loads(raw)
            except ValueError:
                body = None
            return error.code, body

    def check(name, condition):
        results.append({'check': name, 'passed': bool(condition)})
        print(name + ': ' + ('PASS' if condition else 'FAIL'), flush=True)
        if not condition:
            raise RuntimeError(name)

    try:
        for index, account in enumerate(accounts):
            status, session = request('POST', '/auth/v1/token?grant_type=password',
                                      {'email': account['email'], 'password': account['password']})
            check(f'Account {index + 1} login with confirmed email', status == 200 and bool(session.get('access_token')))
            sessions.append(session)
        owner, other = sessions
        owner_id, other_id = owner['user']['id'], other['user']['id']
        status, data = request('POST', '/rest/v1/projects', {
            'user_id': owner_id, 'project_name': marker,
            'problem_statement': 'Disposable launch verification',
            'tags': ['Engineering & Design'], 'project_type': 'solo',
            'community_links': [], 'visibility': 'private',
        }, owner, extra={'Prefer': 'return=representation'})
        check('Private project creation returns its row', status == 201 and bool(data))
        project = data[0]['id']
        status, data = request('GET', f'/rest/v1/projects?id=eq.{project}&select=id', session=other)
        check('Other account cannot read private project', status == 200 and data == [])
        status, data = request('PATCH', f'/rest/v1/projects?id=eq.{project}',
                               {'project_name': 'Forbidden edit'}, other, extra={'Prefer': 'return=representation'})
        check('Other account cannot edit private project', status in (401, 403) or (status == 200 and data == []))
        status, data = request('POST', '/rest/v1/journal_entries', {
            'project_id': project, 'user_id': owner_id, 'title': marker,
            'progress': 'implementation', 'content': [
                {'stage': 'free_notes', 'submitted': False},
                {'type': 'body', 'text': 'Private test journal content'},
            ],
        }, owner, extra={'Prefer': 'return=representation'})
        check('Journal create/save', status == 201 and bool(data))
        journal = data[0]['id']
        status, data = request('GET', f'/rest/v1/journal_entries?id=eq.{journal}&select=id', session=other)
        check('Other account cannot read private journal', status == 200 and data == [])
        image = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jGZkAAAAASUVORK5CYII=')
        for bucket, path in [('images', 'launch-qa/' + str(uuid.uuid4()) + '.png'),
                             ('journal-attachments', project + '/' + str(uuid.uuid4()) + '.png')]:
            route = '/storage/v1/object/' + bucket + '/' + path
            status, data = request('POST', route, image, owner, binary=True)
            check(bucket + ' authenticated upload', status == 200)
            objects.append((bucket, path))
            if bucket == 'images':
                status, data = request('PUT', route, image, other, binary=True)
                check('Other account cannot overwrite image', status != 200)
                status, data = request('DELETE', '/storage/v1/object/images', {'prefixes': [path]}, other)
                status, data = request('GET', '/storage/v1/object/public/images/' + path)
                check('Other account cannot delete image', status == 200 and data == image)
            else:
                status, data = request('GET', '/storage/v1/object/authenticated/' + bucket + '/' + path, session=owner)
                check('Owner can read private attachment', status == 200 and data == image)
                status, data = request('GET', '/storage/v1/object/authenticated/' + bucket + '/' + path, session=other)
                check('Other account cannot read private attachment', status != 200)
                status, data = request('GET', '/storage/v1/object/public/' + bucket + '/' + path)
                check('Anonymous cannot read private attachment', status != 200)
        status, data = request('POST', '/rest/v1/rpc/add_project_member',
                               {'p_project_id': project, 'p_user_id': other_id, 'p_role': 'project_member'}, owner)
        check('Owner can invite project collaborator', status in (200, 204))
        status, data = request('GET', f'/rest/v1/projects?id=eq.{project}&select=id', session=other)
        check('Pending invitation does not grant private access', status == 200 and data == [])
        status, invitations = request('POST', '/rest/v1/rpc/pending_project_invitations', {}, other)
        invitation = next((row for row in invitations if row['project_id'] == project), None) if status == 200 else None
        check('Invitee receives project invitation', invitation is not None)
        status, data = request('POST', '/rest/v1/rpc/respond_project_invitation',
                               {'p_id': invitation['id'], 'p_accept': True}, other)
        check('Invitee can accept collaboration', status in (200, 204))
        status, data = request('GET', f'/rest/v1/projects?id=eq.{project}&select=id', session=other)
        check('Accepted collaborator can read shared project', status == 200 and bool(data))
    except Exception as error:
        results.append({'check': 'Run completion', 'passed': False, 'error_type': type(error).__name__})
    finally:
        if sessions:
            for bucket, path in objects:
                status, data = request('DELETE', '/storage/v1/object/' + bucket, {'prefixes': [path]}, sessions[0])
                results.append({'check': bucket + ' fixture cleanup', 'passed': status == 200 and bool(data), 'path': path if not (status == 200 and bool(data)) else None})
            if project:
                status, data = request('DELETE', f'/rest/v1/projects?id=eq.{project}', session=sessions[0], extra={'Prefer': 'return=representation'})
                results.append({'check': 'Project and journal fixture cleanup', 'passed': status == 200 and bool(data)})
        for index, session in enumerate(sessions):
            status, data = request('POST', '/auth/v1/logout', session=session)
            results.append({'check': f'Account {index + 1} logout', 'passed': status == 204})
            status, data = request('POST', '/auth/v1/token?grant_type=refresh_token', {'refresh_token': session['refresh_token']})
            results.append({'check': f'Account {index + 1} refresh revoked after logout', 'passed': status != 200})
        args.report.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        args.report.write_text(json.dumps({'checks': results, 'all_passed': all(row['passed'] for row in results)}, indent=2))
        args.report.chmod(0o600)
    if not all(row['passed'] for row in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
