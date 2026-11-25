#!/usr/bin/env python3
"""Disposable QEMU lab: two subnets, NAT, public/private VM and a VPC-router analogue.

No cloud API calls. --state-dir must be outside this repository and contain no
other data. A supplied Ubuntu cloud image is opened read-only as a backing image.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import socket
import subprocess
import time
from typing import Any

import yaml

NODES = {"nat": (22350, "192.168.10.254"),
         "public": (22351, "192.168.10.10"),
         "router": (22352, "192.168.10.1"),
         "private": (None, "192.168.20.10")}
OWNER = "netology-clopro-15-1-disposable"


def run(args, **kw):
    return subprocess.run(list(map(str, args)), check=True, text=True,
                          capture_output=True, **kw)


def ssh(state, name, command, timeout=30, check=True):
    return subprocess.run(["ssh", "-q", "-F", str(state / "ssh-config"), name, command],
                          capture_output=True, text=True, timeout=timeout, check=check)


def network(name, index):
    ethernets: dict[str, dict[str, Any]] = {}
    if name != "private":
        ethernets["wan0"] = {"dhcp4": True}
    if name != "private":
        ethernets["public0"] = {"addresses": [NODES[name][1] + "/24"]}
    if name in {"router", "private"}:
        ethernets["private0"] = {"addresses": [
            "192.168.20.1/24" if name == "router" else "192.168.20.10/24"]}
    if name in {"nat", "public"}:
        ethernets["public0"]["routes"] = [
            {"to": "192.168.20.0/24", "via": "192.168.10.1"}]
    if name == "private":
        ethernets["private0"].update({
            "routes": [{"to": "0.0.0.0/0", "via": "192.168.20.1"}],
            "nameservers": {"addresses": ["10.0.2.3"]}})
    if name == "router":
        ethernets["public0"]["routes"] = [
            {"to": "192.168.10.0/24", "scope": "link", "table": 100},
            {"to": "0.0.0.0/0", "via": "192.168.10.254", "table": 100}]
        ethernets["public0"]["routing-policy"] = [
            {"from": "192.168.20.0/24", "table": 100, "priority": 100}]
        ethernets["private0"]["routes"] = [
            {"to": "192.168.20.0/24", "scope": "link", "table": 100}]
    for nic, cfg in ethernets.items():
        suffix = {"wan0": 0, "public0": 1, "private0": 2}[nic]
        cfg.update({"match": {"macaddress": f"52:54:00:15:{index:02x}:{suffix:02x}"},
                    "set-name": nic})
    return {"version": 2, "ethernets": ethernets}


def userdata(name, public_key):
    d = {"hostname": name, "manage_etc_hosts": True, "ssh_pwauth": False,
         "users": [{"name": "ubuntu", "groups": "sudo", "shell": "/bin/bash",
                    "sudo": "ALL=(ALL) NOPASSWD:ALL",
                    "ssh_authorized_keys": [public_key]}]}
    if name in {"nat", "router"}:
        d["write_files"] = [{
            "path": "/etc/sysctl.d/90-netology-routing.conf", "content":
            "net.ipv4.ip_forward=1\nnet.ipv4.conf.all.rp_filter=0\nnet.ipv4.conf.default.rp_filter=0\n"}]
        d["runcmd"] = [
            ["sysctl", "-p", "/etc/sysctl.d/90-netology-routing.conf"],
            ["sh", "-c", "for f in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > \"$f\"; done"]]
    if name == "nat":
        d["runcmd"].append([
            "sh", "-c", "command -v iptables >/dev/null || (apt-get update && apt-get -o DPkg::Lock::Timeout=180 install -y iptables)"])
        d["runcmd"].append([
            "iptables", "-t", "nat", "-A", "POSTROUTING", "-s", "192.168.20.0/24",
            "-o", "wan0", "-j", "MASQUERADE"])
    return d


def create(state, base):
    if state.exists() and any(state.iterdir()):
        raise SystemExit("State directory is not empty; use status/down, or a new directory.")
    state.mkdir(parents=True, mode=0o700, exist_ok=True)
    state.chmod(0o700)
    (state / "owner.json").write_text(json.dumps({"owner": OWNER, "base": str(base)}))
    fmt = json.loads(run(["qemu-img", "info", "--output=json", base]).stdout)["format"]
    run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", state / "key"])
    pubkey = (state / "key.pub").read_text().strip()
    config = ["Host nat public router private", "  User ubuntu",
              "  IdentityFile " + shlex.quote(str(state / "key")),
              "  IdentitiesOnly yes", "  StrictHostKeyChecking accept-new",
              "  UserKnownHostsFile " + shlex.quote(str(state / "known_hosts")),
              "  ConnectTimeout 4", "  LogLevel ERROR"]
    for name, (port, address) in NODES.items():
        config += ["Host " + name, "  HostName " + ("127.0.0.1" if port else address)]
        config += ["  Port " + str(port)] if port else ["  ProxyJump public"]
    (state / "ssh-config").write_text("\n".join(config) + "\n")
    for index, (name, (port, _)) in enumerate(NODES.items(), 1):
        if port:
            with socket.socket() as s:
                s.bind(("127.0.0.1", port))
        d = state / name
        d.mkdir()
        run(["qemu-img", "create", "-f", "qcow2", "-F", fmt, "-b", base, d / "disk.qcow2", "10G"])
        (d / "user-data").write_text("#cloud-config\n" + yaml.safe_dump(userdata(name, pubkey)))
        (d / "meta-data").write_text(f"instance-id: {OWNER}-{name}\nlocal-hostname: {name}\n")
        net = network(name, index)
        (d / "network-config").write_text(yaml.safe_dump(net))
        run(["xorriso", "-as", "mkisofs", "-quiet", "-output", d / "seed.iso",
             "-volid", "cidata", "-joliet", "-rock", d / "user-data", d / "meta-data", d / "network-config"])
        cmd = ["qemu-system-x86_64", "-name", f"clopro15-{name}", "-enable-kvm",
               "-cpu", "host", "-smp", "1", "-m", "768", "-drive",
               f"file={d}/disk.qcow2,if=virtio,format=qcow2", "-drive",
               f"file={d}/seed.iso,media=cdrom,readonly=on", "-display", "none",
               "-serial", f"file:{d}/serial.log", "-monitor", "none",
               "-pidfile", str(d / "qemu.pid"), "-daemonize"]
        for nic, cfg in net["ethernets"].items():
            if nic == "wan0":
                backend = f"user,id={nic},hostfwd=tcp:127.0.0.1:{port}-:22"
            else:
                group, udp = ("239.193.15.1", 30151) if nic == "public0" else ("239.193.15.2", 30152)
                backend = f"socket,id={nic},mcast={group}:{udp},localaddr=127.0.0.1"
            cmd += ["-netdev", backend, "-device",
                    f"virtio-net-pci,netdev={nic},mac={cfg['match']['macaddress']}"]
        run(cmd)
    deadline = time.monotonic() + 200
    for name in NODES:
        while time.monotonic() < deadline:
            try:
                r = ssh(state, name, "cloud-init status --wait >/dev/null && hostname", timeout=20, check=False)
                if r.returncode == 0:
                    print(f"{name}: ready", flush=True)
                    break
            except subprocess.TimeoutExpired:
                pass
            time.sleep(2)
        else:
            raise SystemExit(f"{name} failed readiness; keep state for diagnosis and use down afterwards.")


def status(state):
    for name in NODES:
        pidfile = state / name / "qemu.pid"
        print(f"{name}: {'running' if pidfile.exists() else 'stopped'}")


def down(state, delete):
    if json.loads((state / "owner.json").read_text()).get("owner") != OWNER:
        raise SystemExit("Not an owned disposable lab directory.")
    # Private first: its management connection depends on public and router.
    for name in ["private", "nat", "router", "public"]:
        if (state / name / "qemu.pid").exists():
            try:
                ssh(state, name, "sudo -n poweroff", timeout=15, check=False)
            except subprocess.TimeoutExpired:
                pass
    for _ in range(120):
        if not any((state / n / "qemu.pid").exists() for n in NODES):
            break
        time.sleep(.5)
    if any((state / n / "qemu.pid").exists() for n in NODES):
        raise SystemExit("A VM has not shut down; no files deleted.")
    status(state)
    if delete:
        shutil.rmtree(state)
        print("Deleted the owned disposable state directory; base image untouched.")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("command", choices=["up", "status", "down"])
    p.add_argument("--state-dir", type=Path, required=True)
    p.add_argument("--base-image", type=Path)
    p.add_argument("--delete", action="store_true", help="With down, remove only this owned lab state.")
    a = p.parse_args()
    state = a.state_dir.expanduser().resolve()
    source_tree = Path(__file__).resolve().parents[1]
    if state == source_tree or source_tree in state.parents:
        p.error("--state-dir must be outside the source repository")
    if a.command == "up":
        if a.base_image is None:
            p.error("up requires --base-image")
        create(state, a.base_image.expanduser().resolve())
    elif a.command == "down":
        down(state, a.delete)
    else:
        status(state)


if __name__ == "__main__":
    main()
