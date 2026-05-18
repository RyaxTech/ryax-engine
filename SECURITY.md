# Security Policy

This document describes how to
report a vulnerability, the versions of the engine that receive security
updates, and the timelines we commit to for triage, remediation and
disclosure.

## Reporting a Vulnerability

Please report suspected security vulnerabilities through one of the following
private channels. **Do not open a public GitHub or GitLab issue for security
problems.**

- **Email:** `security@ryax.tech`
  Encrypted email is supported; request our PGP public key in your initial
  message and we will respond with the current key.
- **Customers with a commercial support contract** may additionally use
  `support@ryax.tech` and reference the contract; security reports filed
  through this channel are routed to the security team within the same
  business day.

Please include, where possible:

- a description of the vulnerability and its potential impact;
- the affected component, version and deployment mode (Helm chart on
  Kubernetes, AWS Marketplace SaaS, air-gapped, etc.);
- step-by-step reproduction instructions or a proof-of-concept;
- any known mitigations or workarounds;
- whether the issue is already public or is being coordinated with another
  party.

We will acknowledge your report within **3 business days** and provide an
initial assessment within **7 calendar days**.

## Supported Versions

Security fixes are issued for the versions listed below. Older versions do
not receive security updates; users on unsupported versions are encouraged to
upgrade.

| Version line     | Status                       | Security fixes              |
|------------------|------------------------------|-----------------------------|
| `26.4.x` (latest)| Active                       | Yes — all severities        |
| `26.2.x`         | Maintenance                  | Yes — Critical and High only |
| `26.0.x` and older | End of life                | No                          |

The current release is published at
<https://github.com/RyaxTech/ryax-engine/releases> and as Helm chart
`oci://registry.ryax.org/release-charts/ryax-engine`.

## Severity Classification

Severity is assessed using the **Common Vulnerability Scoring System
v3.1 (CVSS v3.1)**:

| Severity  | CVSS v3.1 base score |
|-----------|----------------------|
| Critical  | 9.0 – 10.0           |
| High      | 7.0 – 8.9            |
| Medium    | 4.0 – 6.9            |
| Low       | 0.1 – 3.9            |

Ryax reserves the right to adjust severity based on real-world exploitability
and on the deployment topology (e.g. whether the vulnerable surface is
exposed to untrusted users in a typical Ryax deployment).

## Remediation and Disclosure SLA

The following targets apply from the moment a report is confirmed as a valid
vulnerability:

| Severity  | Fix available within | Customer / public advisory within |
|-----------|----------------------|-----------------------------------|
| Critical  | 7 calendar days      | 7 calendar days of fix            |
| High      | 30 calendar days     | 14 calendar days of fix           |
| Medium    | 90 calendar days     | At next planned release           |
| Low       | Next planned release | At next planned release           |

For deployments procured through a commercial channel (including the AWS
Marketplace listing of *Ryax Orchestration Engine*), customers are notified
of Critical and High vulnerabilities affecting their deployment **within 72
hours of confirmation**, prior to public disclosure, through the email
contact registered with Ryax.

## Coordinated Disclosure

Ryax follows a **coordinated disclosure** model. We aim to publish a security
advisory together with the patched release. The default embargo window is
**90 days** from the date the report is confirmed; this can be shortened
(e.g. for a fix that is already public upstream) or extended by mutual
agreement with the reporter when additional time is reasonably required to
prepare a fix.

## Scope

### In scope

- Source code and build artefacts of the Ryax engine published in this
  repository and its mirror at
  <https://gitlab.com/ryax-tech/ryax/ryax-main>.
- Official Ryax Helm charts published at
  `oci://registry.ryax.org/release-charts/ryax-engine`.
- Default Ryax actions distributed at
  <https://gitlab.com/ryax-tech/workflows/default-actions>.

### Out of scope

- Third-party services and infrastructure that a customer chooses to
  interconnect with Ryax (their Kubernetes distribution, cloud provider,
  HPC scheduler, identity provider, etc.). Vulnerabilities in those systems
  should be reported to their respective vendors.
- Vulnerabilities that require physical access to a node, root-equivalent
  privileges on the cluster, or credentials issued by the customer's
  administrator.
- Findings whose only impact is denial-of-service through legitimate
  workload submission against customer-controlled resource quotas.
- Issues in dependencies that have already been disclosed upstream and for
  which an upgrade is available.

## Cryptography

Ryax does not ship a FIPS-validated cryptographic module. The engine relies
on cryptographic primitives from the underlying host operating system,
container base images and standard upstream libraries (OpenSSL via PyCA
`cryptography`, PyCA `bcrypt`, `asyncssh`). Customers requiring FIPS 140-2 /
140-3 cryptographic operation can deploy Ryax on a FIPS-validated host
operating system and Kubernetes distribution to inherit the underlying
validated providers.

## Software Supply Chain

- The Ryax engine is distributed under the **MPL-2.0** licence.
- User actions are built reproducibly through the Nix-based `ryax_lock`
  mechanism documented at
  <https://docs.ryax.tech/reference/ryax_lock>.

## Contact

- Security reports: `security@ryax.tech`
- General support: `support@ryax.tech`
- Documentation: <https://docs.ryax.tech>
