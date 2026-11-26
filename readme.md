# ICPC Judgehost Image Tools (`judgesImage`)
This branch builds the dedicated **DOMjudge 9.0.0 judgehost** Linux image for the [ICPC Greece / SEERC Regional](https://algoforum.upatras.gr/), based on the [ICPC Southeast Regional](https://github.com/icpc-environment/icpc-env) image tools.

## Key Features
* **Custom DOMjudge 9.0.0 judgehost Docker image (`icpc/judgehost:9.0.0`)** built on top of `domjudge/judgehost:9.0.0` with toolchains matching the contestant image in both `/chroot/domjudge` and the outer container:
  * **C / C++:** GCC 14 / G++ 14 (default via `update-alternatives` in both outer container and chroot)
  * **Java:** OpenJDK 21
  * **Python:** Python 3.12 & PyPy 3
  * **Kotlin:** Kotlin `2.2.20` (`/chroot/domjudge/usr/lib/kotlinc` + `/usr/local/bin/{kotlinc,kotlin,kotlinc-jvm,kapt}` inside `/usr` so DOMjudge's `chroot-startstop.sh` mounts it, and symlinked into outer `/usr/local/bin`)
  * Verified during image build with an end-to-end unprivileged compile & run smoke test using DOMjudge's actual `chroot-startstop.sh` mount layout plus outer-container checks
* **Host compilers & tooling:** GCC/G++ 14, OpenJDK 21, Python 3 / PyPy 3, Kotlin `2.2.20`, VS Code, `vim`, `gedit`, Docker CE (with 50 MB × 3 json-file log rotation)
* **Deterministic judging & stability tuning:**
  * cgroup v2 enabled (required by DOMjudge 9.0+)
  * SMT disabled (`nosmt`), deep C-states capped (`max_cstate=1`), ASLR disabled (`kernel.randomize_va_space=0`), `vm.swappiness=0`
  * Boot-time CPU stabilization service (`judgehost-tuning.service`: `performance` governor/EPP, Turbo/Boost disabled, THP defrag off)
  * `runJudgehosts.sh` automatically pins one judgehost container per physical P-core (reserving CPU 0 for the OS/IRQs/Docker/SSH)
* **Unattended boot & hardened SSH:**
  * `firstboot.service` (`icpc_setup`) disabled so judgehosts boot unattended
  * Key-only SSH authentication for `icpcadmin`/`root` (`PasswordAuthentication no`, `contestant` and `teamreset` denied)
  * UFW configured with `OpenSSH` allowed and kept disabled on judgehosts so Docker/DOMserver traffic is unobstructed
* **Lightweight XFCE desktop** with helper scripts in `/opt/scripts/` (`runJudgehosts.sh`, `startAllContainers.sh`, `stopAllContainers.sh`, `removeAllContainers.sh`)

## Usage Requirements
* 64-bit x86_64 hardware (multi-core CPU; physical SSD recommended)
* BIOS or UEFI boot capable
* 4+ GB RAM recommended (depending on core count & judgehost containers)

## Build Requirements
* Linux host system with KVM support
* `qemu-system-x86`, `xorriso`, `bsdtar` (`libarchive-tools`), `ansible`, `python3`, `python3-passlib`
* ~30 GB free disk space for the sparse build (default virtual disk size is `88500M` / ~88.5 GB; use `-s` if targeting a smaller physical drive); build VM uses 2 GB RAM / 2 vCPUs

## Building the Image

1. Clone this repository and switch to `judgesImage`:
   ```bash
   git clone https://github.com/alexspitalas/icpc-env-greece
   cd icpc-env-greece
   git checkout judgesImage
   ```

2. Install host build dependencies:
   ```bash
   # Ubuntu / Debian
   sudo apt-get install qemu-system-x86 xorriso ansible libarchive-tools python3-passlib
   # Arch Linux
   sudo pacman -S qemu-system-x86 cdrtools libarchive ansible
   ```

3. Download the Ubuntu 24.04.4 Server ISO into the repository root:
   ```bash
   curl -LO https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso
   ```
   *(No manual IDE or Kotlin archives are required — Kotlin `2.2.20` is downloaded automatically during `build-final.sh`, or reused if `files/kotlin-compiler-2.2.20.zip` is placed locally.)*

4. Generate SSH keys/secrets and copy them into `files/secrets/`:
   ```bash
   cd secrets
   chmod u+x gen-secrets.sh
   ./gen-secrets.sh 'contestID'
   cd ..
   chmod u+x fetch-secrets.sh
   ./fetch-secrets.sh 'contestID'
   ```

5. Copy `group_vars/all.dist` to `group_vars/all` and customize `icpc_timezone`, `icpcadmin_pass`, and any extra `icpcadmin_ssh_keys`:
   ```bash
   cp group_vars/all.dist group_vars/all
   ```

6. Create the base Ubuntu 24.04.4 disk image (default size is `88500M` / ~88.5 GB; pass `-s <size>` if your target drive is smaller, and `--no-usb` if installing on internal SSDs without the 192 MB FAT32 `ICPC` partition):
   ```bash
   ./create_baseimg.sh --no-usb
   # Example for a 32 GB target drive:
   # ./create_baseimg.sh --no-usb -s 28500M
   ```

7. Provision the judgehost image with Ansible (builds `icpc/judgehost:9.0.0` and runs the chroot smoke tests):
   ```bash
   ./build-final.sh
   ```

8. Flash the generated image to the target disk (replace `/dev/sdx` carefully — check with `lsblk`):
   ```bash
   sudo dd if=output/all-YYYY-MM-DD_image-amd64.img of=/dev/sdx bs=1M status=progress oflag=direct conv=sparse
   ```

## Post-Install Judgehost Setup
1. On the DOMserver Web UI, enable Kotlin under **Admin → Languages → `kt` → Allow submit: Yes**.
2. On each judgehost PC, edit `/opt/scripts/runJudgehosts.sh` to set:
   * `DOMSERVER_IP` / `DOMSERVER_PORT`
   * `JUDGEDAEMON_PASSWORD`
   * `HOSTNAME` (**must be unique** for each physical judgehost PC)
3. Create and start the judgehost containers:
   ```bash
   sudo /opt/scripts/runJudgehosts.sh
   sudo /opt/scripts/startAllContainers.sh
   ```

## Testing Customizations
To iterate on Ansible changes without running a full `build-final.sh`, use `./runvm.sh` against the base image. Always build production images with `./build-final.sh`.
