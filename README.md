
# 21 — Server Auto Setup

Automated Linux server setup script for Debian and Ubuntu.

`21` configures a server with UFW firewall rules, TCP optimization, BBR congestion control, IPv6 settings, Fail2ban protection, DNS diagnostics, and time synchronization.

## Features

- **System update** — updates installed packages and installs required dependencies.
- **UFW firewall** — configures incoming and outgoing traffic rules.
- **SSH protection** — detects SSH ports and adds firewall rules to help prevent accidental lockout.
- **TCP tuning** — adjusts TCP queues, backlog, and keepalive parameters.
- **BBR** — enables BBR congestion control when supported by the kernel.
- **IPv6** — disables IPv6 through sysctl and UFW configuration.
- **ICMP** — blocks incoming ICMP echo requests.
- **Fail2ban** — protects SSH against repeated authentication failures.
- **DNS diagnostics** — checks DNS resolution without changing resolver configuration.
- **Time synchronization** — enables system time synchronization.
- **GeoIP report** — optionally runs a separate GeoIP script and displays country traffic percentages.
- **Logging** — stores detailed command output in `/var/log/21-server-setup.log`.

## Supported systems

- Debian
- Ubuntu

Root privileges are required.

## Quick start

Run the setup script directly from GitHub:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/whitebbit/21/main/21.sh)
```

Or using `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/whitebbit/21/main/21.sh)
```

> Replace `whitebbit` if the repository is owned by a different GitHub account.

## Firewall rules

The script configures UFW with the following rules:

| Port | Protocol |
|---|---|
| 22 / detected SSH ports | TCP |
| 80 | TCP |
| 443 | TCP, UDP |
| 8443 | TCP, UDP |
| 10000–60000 | TCP, UDP |

Incoming traffic is denied by default. Outgoing traffic is allowed by default.

The configured port range is broad. Review the firewall rules before running the script on a production server.

## Fail2ban configuration

The SSH jail is configured with the following parameters:

| Setting | Value |
|---|---|
| Ban duration | 7 days |
| Find time | 3 minutes |
| Maximum retries | 3 |
| Backend | systemd |
| SSH mode | aggressive |

## Important notes

- The script must be run as `root`.
- The script does not automatically reboot the server.
- IPv6 is disabled by default after running the script.
- BBR is enabled only if the running kernel supports it.
- DNS configuration is inspected but not overwritten.
- UFW rules are added to the existing firewall configuration.
- Review the script before executing it on a production server.

## Logs

Detailed execution logs are stored at:

```text
/var/log/21-server-setup.log
```

## License

No license has been specified yet.
