#!/usr/bin/env python3
"""Check HTTP connectivity between app Deployments through their Services."""
import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone

PAIRS = [(s, t) for s in ("frontend", "backend", "cache")
         for t in ("frontend", "backend", "cache") if s != t]
ALLOWED = {("frontend", "backend"), ("backend", "cache")}


def check(source, target):
    prefix = ["kubectl", "exec", "-n", "app", f"deploy/{source}", "--"]
    fqdn = f"{target}.app.svc.cluster.local."
    try:
        service = subprocess.run(
            ["kubectl", "get", "service", target, "-n", "app", "-o", "json"],
            text=True, capture_output=True, timeout=12, check=True)
        expected_ip = json.loads(service.stdout)["spec"]["clusterIP"]
        dns = subprocess.run(prefix + ["nslookup", fqdn],
                             text=True, capture_output=True, timeout=12)
        # A DNS timeout must never count as a denied HTTP connection.
        if dns.returncode or expected_ip not in dns.stdout.split():
            return {"source": source, "target": target, "exit_code": dns.returncode,
                    "http_status": None, "state": "error",
                    "detail": f"DNS preflight failed for {fqdn}: {dns.stdout} {dns.stderr}"}
    except (OSError, subprocess.TimeoutExpired, subprocess.CalledProcessError,
            ValueError, KeyError) as exc:
        return {"source": source, "target": target, "exit_code": None,
                "http_status": None, "state": "error", "detail": str(exc)}
    cmd = prefix + ["curl", "--connect-timeout", "2", "--max-time", "4",
                    "-sS", "-o", "/dev/null", "-w", "%{http_code}",
                    f"http://{fqdn}:80/"]
    try:
        p = subprocess.run(cmd, text=True, capture_output=True, timeout=12)
        output = (p.stdout or "").strip()
        # kubectl returns the remote curl status when exec completed normally.
        http = output[-3:] if len(output) >= 3 and output[-3:].isdigit() else None
        if p.returncode == 0 and http and http.startswith("2"):
            state, detail = "connected", "HTTP " + http
        elif p.returncode == 28:
            state, detail = "timeout", "curl exit 28 (connection timed out)"
        else:
            state = "error"
            detail = f"kubectl/curl exit {p.returncode}; stdout={output!r}; stderr={p.stderr.strip()!r}"
        return {"source": source, "target": target, "exit_code": p.returncode,
                "http_status": http, "state": state, "detail": detail}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"source": source, "target": target, "exit_code": None,
                "http_status": None, "state": "error", "detail": str(exc)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("baseline", "restricted"))
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args()
    results = [check(s, t) for s, t in PAIRS]
    checks = []
    for r in results:
        expected = (r["source"], r["target"]) in ALLOWED if args.mode == "restricted" else True
        actual = r["state"] == "connected" if expected else r["state"] == "timeout"
        r["expected"] = "connected" if expected else "blocked (timeout)"
        r["match"] = actual
        checks.append(actual)
    passed = all(checks)
    report = {"mode": args.mode, "timestamp": datetime.now(timezone.utc).isoformat(),
              "passed": passed, "results": results}
    if args.format == "json":
        print(json.dumps(report, indent=2))
    else:
        print(f"mode={args.mode} passed={passed}")
        for r in results:
            mark = "OK" if r["match"] else "MISMATCH"
            print(f"{mark}: {r['source']} -> {r['target']}: {r['detail']} (expected {r['expected']})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
