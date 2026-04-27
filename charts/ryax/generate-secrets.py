#!/usr/bin/env python3
import base64
import os
import string
import secrets


def frenet_key():
    return base64.urlsafe_b64encode(os.urandom(32)).decode()


def password():
    alphabet = string.ascii_letters + string.digits
    while True:
        password = "".join(secrets.choice(alphabet) for i in range(12))
        if (
            any(c.islower() for c in password)
            and any(c.isupper() for c in password)
            and sum(c.isdigit() for c in password) >= 3
        ):
            break
    return password


if __name__ == "__main__":
    registry_pass = password()
    runner_frenet_key = frenet_key()
    repository_frenet_key = frenet_key()
    worker_pg_pass = password()
    rabbitmq_pg_pass = password()

    print(
        f"""
runner:
  fernetEncryptionKey: {runner_frenet_key}
repository:
  fernetEncryptionKey: {repository_frenet_key}
worker:
  postgresql:
    auth:
      password: {worker_pg_pass}
rabbitmq:
  auth:
    password: {rabbitmq_pg_pass}
registry:
  credentials:
    password: "{registry_pass}"
    username: ryax
    enabled: true
"""
    )
