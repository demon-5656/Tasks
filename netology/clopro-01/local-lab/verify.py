#!/usr/bin/env python3
"""Verify the owned local NAT lab, including loss/recovery of private internet.

Disables forwarding only INSIDE the disposable NAT guest, restoring it in finally.
Does not call Yandex Cloud or alter host network configuration.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shlex
import subprocess
from typing import Any


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--state-dir", type=Path, required=True)
    p.add_argument("--output", type=Path)
    a = p.parse_args()
    state = a.state_dir.expanduser().resolve()
    assert json.loads((state / "owner.json").read_text())["owner"] == "netology-clopro-15-1-disposable"

    def ssh(node, command, check=True):
        return subprocess.run(["ssh", "-q", "-F", str(state / "ssh-config"), node, command],
                              text=True, capture_output=True, timeout=25, check=check)

    def get(node, address=None):
        command = ["curl", "-4", "-fsS", "--connect-timeout", "3", "--max-time", "6",
                   "-o", "/dev/null", "-w", "%{http_code} %{remote_ip}"]
        if address:
            command += ["--resolve", "example.com:443:" + address]
        r = ssh(node, shlex.join(command + ["https://example.com/"]), check=False)
        return {"exit_code": r.returncode, "response": r.stdout.strip(),
                "stderr": r.stderr.strip()}

    report: dict[str, Any] = {"environment": "local QEMU/KVM, not Yandex Cloud",
              "timestamp": datetime.now(timezone.utc).isoformat()}
    report["public_baseline"] = get("public")
    report["private_baseline"] = get("private")
    for key in ["public_baseline", "private_baseline"]:
        assert report[key]["exit_code"] == 0 and report[key]["response"].split()[0] == "200", report
    address = report["private_baseline"]["response"].split()[1]
    report["private_interfaces"] = json.loads(ssh("private", "ip -j -4 address").stdout)
    assert {i["ifname"] for i in report["private_interfaces"]} == {"lo", "private0"}
    report["private_routes"] = json.loads(ssh("private", "ip -j -4 route").stdout)
    report["vpc_route_table"] = json.loads(ssh("router", "ip -j -4 route show table 100").stdout)
    assert any(r.get("dst") == "default" and r.get("gateway") == "192.168.10.254"
               for r in report["vpc_route_table"])
    report["ssh_proxyjump"] = subprocess.run(
        ["ssh", "-G", "-F", str(state / "ssh-config"), "private"],
        text=True, capture_output=True, check=True).stdout.split("proxyjump ")[1].splitlines()[0]
    assert report["ssh_proxyjump"] == "public"
    try:
        ssh("nat", "sudo -n sysctl -w net.ipv4.ip_forward=0")
        # Fixed resolved address excludes DNS failure as the cause of the timeout.
        report["private_nat_off"] = get("private", address)
        report["public_nat_off"] = get("public", address)
        assert report["private_nat_off"]["exit_code"] == 28, report
        assert report["public_nat_off"]["exit_code"] == 0, report
    finally:
        ssh("nat", "sudo -n sysctl -w net.ipv4.ip_forward=1")
    report["private_restored"] = get("private", address)
    assert report["private_restored"]["exit_code"] == 0, report
    report["nat_rule_counters"] = ssh("nat", "sudo -n iptables -t nat -nvL POSTROUTING").stdout
    report["passed"] = True
    rendered = json.dumps(report, indent=2) + "\n"
    if a.output:
        a.output.parent.mkdir(parents=True, exist_ok=True)
        a.output.write_text(rendered)
    print(rendered, end="")


if __name__ == "__main__":
    main()
