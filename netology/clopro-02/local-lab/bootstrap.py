#!/usr/bin/env python3
"""Start the disposable lab and upload the actual PNG through signed S3 requests."""
import argparse
import json
from pathlib import Path
import secrets
import subprocess
import time

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

PROJECT = 'netology-clopro15-2'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--state-dir', type=Path, required=True)
    a = p.parse_args()
    state = a.state_dir.expanduser().resolve()
    root = Path(__file__).resolve().parents[1]
    if state == root or root in state.parents:
        p.error('Keep generated credentials outside the source tree')
    if state.exists() and any(state.iterdir()):
        p.error('Use a new empty state directory')
    existing = subprocess.check_output([
        'docker', 'ps', '-aq', '--filter', 'label=com.docker.compose.project=' + PROJECT], text=True)
    if existing.strip():
        p.error('The lab project already has containers; do not overwrite it')
    state.mkdir(parents=True, mode=0o700, exist_ok=True)
    state.chmod(0o700)
    credentials = {'access_key': 'lab-' + secrets.token_hex(10),
                   'secret_key': secrets.token_hex(24)}
    (state / 'credentials.json').write_text(json.dumps(credentials))
    (state / 'credentials.json').chmod(0o600)
    config = {'identities': [
        {'name': 'lab-admin', 'credentials': [
            {'accessKey': credentials['access_key'], 'secretKey': credentials['secret_key']}],
         'actions': ['Admin', 'Read', 'Write', 'List', 'Tagging']},
        {'name': 'anonymous', 'actions': ['Read:clopro15-picture']}]}
    (state / 's3.json').write_text(json.dumps(config))
    (state / 's3.json').chmod(0o600)
    (state / 'private.env').write_text(
        f'S3_CONFIG={state}/s3.json\nDB_PASSWORD={secrets.token_hex(24)}\n'
        f'DB_ROOT_PASSWORD={secrets.token_hex(24)}\n')
    (state / 'private.env').chmod(0o600)
    compose = ['docker', 'compose', '--project-name', PROJECT,
               '--env-file', str(state / 'private.env'), '-f', str(root / 'local-lab/compose.yaml')]
    subprocess.run(compose + ['up', '-d', '--build', '--wait', '--wait-timeout', '120'], check=True)
    client = boto3.client(
        's3', endpoint_url='http://127.0.0.1:18820', region_name='us-east-1',
        aws_access_key_id=credentials['access_key'], aws_secret_access_key=credentials['secret_key'],
        config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}, proxies={},
                      request_checksum_calculation='when_required',
                      response_checksum_validation='when_required'))
    for attempt in range(30):
        try:
            client.list_buckets()
            break
        except (BotoCoreError, ClientError):
            if attempt == 29:
                raise
            time.sleep(1)
    client.create_bucket(Bucket='clopro15-picture')
    client.put_object(Bucket='clopro15-picture', Key='picture.png',
                      Body=(root / 'assets/picture.png').read_bytes(), ContentType='image/png')
    print('Uploaded picture.png through the S3 API; credentials remain in the private state directory.')
    subprocess.run(['python3', str(root / 'local-lab/check.py'), 'object', '--format', 'text'], check=True)
    subprocess.run(['python3', str(root / 'local-lab/check.py'), 'sample', '--expect', '3', '--format', 'text'], check=True)


if __name__ == '__main__':
    main()
