# Changelog

## Unreleased

### Security
- **Enforced SSH key-only authentication (disabled password logins) and enabled `ssh.service`.**
  Configured `/etc/ssh/sshd_config.d/01-ssh-keys-only.conf` with `PasswordAuthentication no`
  and `KbdInteractiveAuthentication no`, disabled `ssh.socket`, and enabled `ssh.service`.
- **Authorized admin SSH keys for `icpcadmin` and `root`.** Added authorized keys
  setup for `files/secrets/icpcadmin@contestmanager.pub`, host public keys
  (`~/.ssh/id_ed25519.pub` / `~/.ssh/id_rsa.pub`), and custom keys configured via
  `icpcadmin_ssh_keys` in `group_vars/all` (without including the committed `imageadmin` build key).
- **Updated `connect2qemu.sh` for post-build SSH access.** Updated `connect2qemu.sh`
  to connect as `icpcadmin` using `files/secrets/icpcadmin@contestmanager` (or default key),
  auto-detect ports 5222 and 2222, and remove unnecessary host sudo.
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
