# Changelog

## Unreleased

### Security
- **Disabled tinyproxy (`playbooks/proxy.yaml`) in `main.yml`.** It listened on
  `localhost:8888` and forwarded to any destination with no domain whitelist.
  Because the UFW rules allow `127.0.0.1 -> 127.0.0.1`, a contestant could set
  `http_proxy=http://localhost:8888` and reach arbitrary sites, bypassing the
  squid allow-list that is supposed to be the network filter. squid
  (`playbooks/firewall.yml`) remains the single egress filter.

### Known issues / follow-ups (not changed here)
- `configs/imageadmin-ssh_key` is a committed private key. It is only used to
  talk to the local QEMU build VM and `imageadmin` is removed from the final
  image by `files/scripts/makeDist.sh`, so it does not ship — but it is still a
  private key in version control.
- `files/scripts/firewall.sh` / `playbooks/firewall.yaml` are an older
  UFW-only approach (with `ufw default deny outgoing`) that is **not** wired
  into `main.yml`. They are dead code today and would break squid-based egress
  if run by accident; consider removing them to avoid confusion.
