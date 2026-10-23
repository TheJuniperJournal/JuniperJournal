#!/usr/bin/env python3
"""Write an allowlisted public Flutter configuration; never copies other secrets."""
import argparse, base64, json, pathlib

def public_config(source):
    try:
        values = json.loads(source)
    except json.JSONDecodeError:
        values = {}
        for line in source.splitlines():
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                values[key.strip()] = value.strip().strip('"\'')
    config = {key: values.get(key, '') for key in ('SUPABASE_URL', 'SUPABASE_KEY')}
    if not all(config.values()):
        raise ValueError('SUPABASE_URL and SUPABASE_KEY are required')
    key = config['SUPABASE_KEY']
    if key.startswith('sb_secret_'):
        raise ValueError('A privileged Supabase key cannot be bundled for web')
    if key.count('.') == 2:
        payload = key.split('.')[1]
        claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
        if claims.get('role') != 'anon':
            raise ValueError('Only an anon/publishable Supabase key can be bundled')
    elif not key.startswith('sb_publishable_'):
        raise ValueError('Expected a public Supabase publishable or anon key')
    return config

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('output')
    args = parser.parse_args()
    try:
        result = public_config(pathlib.Path(args.source).read_text())
    except (ValueError, OSError) as error:
        parser.exit(1, f'Web configuration rejected: {error}\n')
    pathlib.Path(args.output).write_text(json.dumps(result))
    print('Public web configuration prepared (values hidden).')
