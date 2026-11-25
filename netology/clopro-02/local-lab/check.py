#!/usr/bin/env python3
"""Read-only checks of the running Object Storage / LAMP / TCP-balancer lab."""
import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
import time
from pathlib import Path
from typing import Any

import requests

PAGE = 'http://127.0.0.1:18880/'
IMAGE = 'http://127.0.0.1:18820/clopro15-picture/picture.png'
STATS = 'http://127.0.0.1:18881/stats;csv'


def request(url, method='GET', data=None):
    # A TCP load balancer selects a backend per connection, not per HTTP request.
    with requests.Session() as s:
        s.trust_env = False
        return s.request(method, url, data=data, headers={'Connection': 'close'}, timeout=6)


def servers():
    response = request(STATS)
    response.raise_for_status()
    rows = csv.DictReader(io.StringIO(response.text.removeprefix('# ')))
    return [{k: row[k] for k in ['svname', 'status', 'check_status', 'check_code', 'addr']}
            for row in rows if row['pxname'] == 'lamp_group' and row['svname'].startswith('web')]


def check_object():
    expected = (Path(__file__).resolve().parents[1] / 'assets/picture.png').read_bytes()
    response = request(IMAGE)
    assert response.status_code == 200, response.status_code
    assert response.headers.get('Content-Type') == 'image/png'
    assert response.content == expected, 'Object bytes differ from source PNG'
    denied = request('http://127.0.0.1:18820/clopro15-picture/forbidden.txt', method='PUT', data=b'write must fail')
    assert denied.status_code == 403, 'Anonymous write must be forbidden'
    return {'anonymous_get': response.status_code, 'content_type': 'image/png',
            'bytes': len(expected), 'sha256': hashlib.sha256(response.content).hexdigest(),
            'anonymous_put': denied.status_code, 'passed': True}


def sample(count, expected_backends):
    deadline = time.monotonic() + 20
    while sum(row['status'] == 'UP' for row in servers()) != expected_backends:
        assert time.monotonic() < deadline, 'Balancer health checks did not converge'
        time.sleep(.2)
    distribution = Counter()
    database = {}
    for _ in range(count):
        response = request(PAGE)
        assert response.status_code == 200, response.status_code
        assert IMAGE in response.text, 'Page does not reference the uploaded image'
        node = response.headers.get('X-Backend-Id')
        assert node and node in response.text, 'Backend header/body mismatch'
        distribution[node] += 1
    # Probe SQL through the same load balancer, also using new TCP connections.
    for _ in range(max(count, 3)):
        response = request(PAGE + 'health.php')
        assert response.status_code == 200, response.status_code
        body = response.json()
        assert body['status'] == 'ok' and body['database'] is True, body
        database[body['node']] = {'database': body['database'], 'php': body['php']}
    current = servers()
    up = sum(row['status'] == 'UP' for row in current)
    assert len(distribution) == expected_backends, distribution
    assert up == expected_backends, current
    assert set(database) == set(distribution), database
    return {'http_requests': count, 'http_200': sum(distribution.values()),
            'backends': dict(distribution), 'healthy_backends': up,
            'sql_health': database, 'balancer_servers': current, 'passed': True}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode', choices=['object', 'status', 'sample'])
    p.add_argument('--requests', type=int, default=30)
    p.add_argument('--expect', type=int, default=3)
    p.add_argument('--output', type=Path)
    p.add_argument('--format', choices=['json', 'text'], default='json')
    a = p.parse_args()
    result: dict[str, Any]
    if a.mode == 'object':
        result = check_object()
    elif a.mode == 'status':
        result = {'balancer_servers': servers()}
    else:
        result = sample(a.requests, a.expect)
    result['timestamp'] = datetime.now(timezone.utc).isoformat()
    rendered = json.dumps(result, indent=2) + '\n'
    if a.output:
        a.output.parent.mkdir(parents=True, exist_ok=True)
        a.output.write_text(rendered)
    if a.format == 'json':
        print(rendered, end='')
    elif a.mode == 'sample':
        print(f"HTTP 200: {result['http_200']}/{result['http_requests']}")
        print(f"Healthy backends: {result['healthy_backends']}")
        for node, count in result['backends'].items():
            health = result['sql_health'][node]
            print(f"{node}: {count} responses; PHP {health['php']}; SQL ready={health['database']}")
        for row in result['balancer_servers']:
            print(f"{row['svname']}: {row['status']} {row['check_status']} {row['check_code']} {row['addr']}")
    else:
        for key, value in result.items():
            print(f'{key}: {value}')


if __name__ == '__main__':
    main()
