#!/usr/bin/env python3

import json
import os
import shutil
import time
from pathlib import Path
from subprocess import run

import psutil
from tomlkit import dump, parse

print("-- Installing the Ryax internal registry certificate", flush=True)

registry_cert = os.environ["REGISTRY_CERT"]
registry_server = os.environ["REGISTRY_SERVER"]

nsenter = ["nsenter", "--target", "1", "--mount"]
mount_prefix = Path("/mnt")

if any(
    [
        "dockerd" in proc.info["name"]
        and not any(["--containerd" in options for options in proc.cmdline()])
        for proc in psutil.process_iter(["name"])
    ]
):
    print("-- Docker Daemon detected!")
    registry_cert_dir = Path("/etc/docker/certs.d") / registry_server
    (mount_prefix / registry_cert_dir.relative_to("/")).mkdir(
        parents=True, exist_ok=True
    )
    registry_cert_path = registry_cert_dir / "ca.crt"
    with open(
        mount_prefix / registry_cert_path.relative_to("/"), mode="w"
    ) as cert_file:
        cert_file.write(registry_cert)
    print("-- Registry certificate installed!")
    exit(0)

registry_cert_dir = Path("/etc/containerd/certs.d") / registry_server
(mount_prefix / registry_cert_dir.relative_to("/")).mkdir(parents=True, exist_ok=True)
registry_cert_path = registry_cert_dir / "ca.crt"

with open(mount_prefix / registry_cert_path.relative_to("/"), mode="w") as cert_file:
    cert_file.write(registry_cert)

k3s_config_dir = mount_prefix / (Path("/var/lib/rancher/k3s").relative_to("/"))
containerd_config_path = mount_prefix / (
    Path("/etc/containerd/config.toml").relative_to("/")
)

if k3s_config_dir.exists():
    print("-- k3s detected!", flush=True)
    registries_config_path_dir = mount_prefix / (
        Path("/etc/rancher/k3s").relative_to("/")
    )
    registries_config_path_dir.mkdir(parents=True, exist_ok=True)
    registries_config_path = registries_config_path_dir / "registries.yaml"
    if registries_config_path.exists():
        print("Already configured!", flush=True)
        run(nsenter + ["crictl", "info"])

    else:
        registries_config = f"""
mirrors:
  {registry_server}:
    endpoint:
      - "https://{registry_server}"
configs:
  "{registry_server}":
    tls:
      ca_file: {registry_cert_path}
"""
        with open(registries_config_path, "w") as config:
            config.write(registries_config)

        print(
            "-- Restarting the containerd daemon. WARNING: this pod will fail and restart",
            flush=True,
        )
        run(nsenter + ["killall", "containerd"], check=True)
        print("-- Done", flush=True)

elif containerd_config_path.exists():
    shutil.copy(
        containerd_config_path,
        str(containerd_config_path) + ".old",
    )
    proc = run(nsenter + ["containerd", "--version"], capture_output=True)
    version = proc.stdout.decode().split()[2].split(".")
    # remove v, if the version starts with a v
    if version[0][0] == "v":
        version[0] = version[0][1:]
    if version[0] == "0" or (version[0] == "1" and int(version[1]) < 5):
        print(
            f"Only Containerd version 1.5+ is supported, found version {'.'.join(version)}"
        )
        exit(3)
    if version[0] == "2":
        print(f"Containerd version 2 detected : {'.'.join(version)}")

    print("-- Inject containerd certificates", flush=True)
    with open(
        mount_prefix / registry_cert_dir.relative_to("/") / "hosts.toml", "w"
    ) as hosts_file:
        cert_config = f"""
server = "https://{registry_server}"

[host."https://{registry_server}"]
  ca = "{registry_cert_path}"
  capabilities = ["pull", "resolve", "push"]
"""
        hosts_file.write(cert_config)

    with open(containerd_config_path, mode="r") as conf_file:
        conf = parse(conf_file.read())
    print("--- Previous containerd configuration:", flush=True)
    print(json.dumps(conf, indent=4), flush=True)

    # Force config version to 2
    conf["version"] = 2
    if conf.get("plugins") is None:
        conf["plugins"] = {}

    if conf["plugins"].get("io.containerd.grpc.v1.cri") is None:
        if conf["plugins"].get("cri"):
            conf["plugins"]["io.containerd.grpc.v1.cri"] = conf["plugins"].pop("cri")
        else:
            conf["plugins"]["io.containerd.grpc.v1.cri"] = {}

    if conf["plugins"]["io.containerd.grpc.v1.cri"].get("registry") is None:
        conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"] = {}

    current_config = conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"].get(
        "config_path"
    )
    if current_config is not None and current_config == "/etc/containerd/certs.d":
        print("-- Already configured!", flush=True)
        run(nsenter + ["crictl", "info"])
    else:
        conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"]["config_path"] = (
            "/etc/containerd/certs.d"
        )

        if (
            conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"].get("mirrors")
            is not None
        ):
            to_remove_conf = conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"][
                "mirrors"
            ]
            print(
                f"-- WARNING: removing existing registry mirrors: {to_remove_conf}",
                flush=True,
            )
            del conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"]["mirrors"]

        if (
            conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"].get("configs")
            is not None
        ):
            to_remove_conf = conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"][
                "configs"
            ]
            print(
                f"-- WARNING: removing existing registry configs: {to_remove_conf}",
                flush=True,
            )
            del conf["plugins"]["io.containerd.grpc.v1.cri"]["registry"]["configs"]

        with open(containerd_config_path, mode="w") as conf_file:
            dump(conf, conf_file)

        print("--- New containerd configuration:", flush=True)
        print(json.dumps(conf, indent=4), flush=True)

        print(
            "-- Restarting the containerd daemon in 5 sec. WARNING: this pod will fail and restart",
            flush=True,
        )
        time.sleep(5)
        run(nsenter + ["systemctl", "restart", "containerd"], check=True)
        print("-- Done")
else:
    print("Error: Only standard containerd CRI and k3s are supported!")
    exit(2)
