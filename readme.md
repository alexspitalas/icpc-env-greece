# ICPC Contest Image Tools
This repository is a fork of the necessary tools to build the contestant image by the [ICPC Southeast Regional](https://github.com/icpc-environment/icpc-env).
The image is a linux installation optimized for booting off a flash drive that is used by all the teams in our region.
This is a trial test of the tools for the [ICPC Greece Regional](https://algoforum.upatras.gr/).

## Key Features
We will reduce the features of the original image to supports the following:

* Programming languages: c, c++, java, python3
* IDEs and developer tools: Eclipse, Code::Blocks, gvim, emacs, Visual Studio Code, IntelliJ
* Local web server with copies of language documentation for: STL *(CPP)*, Java, Python3
* Automatically populate the linux disk cache on boot to speed up response time for certain programs
* Advanced firewall to restrict team access to the network
* Fat32 partition for teams to store files that allows for easy access after the contest
* Simple management/set up for admins
* Custom home directory content(for configuring firefox, desktop shortcuts, etc)
* Fully customizable, automated process for building consistent images
* Lightweight XFCE desktop environment

## Usage Requirements
* 64bit hardware
* USB boot capable(BIOS + UEFI supported)
* 1gb of ram(2+ recommended)
* 32gb flash drive(USB3.2 strongly recommended)

## Build Requirements
* Linux host system
* qemu, uml-utlities
* Approx 30GB disk space free
* Ansible
* Python3

## Building the Image
Building the image is a very simple process, and takes between 10-30minutes
depending on connection speed and various other factors.

1. Clone this repository:
```bash
git clone https://github.com/alexspitalas/icpc-env-greece
cd icpc-env-greece
```
1. Make sure dependencies are met
  * Install required packages
    ```bash
    sudo apt-get install qemu-system-x86 genisoimage bsdtar ansible # Debian based Distros
    sudo apt-get install qemu-system-x86 genisoimage ansible libarchive-tools xorriso python3-passlib # newer Debian based Distros without bsdtar
    sudo pacman -S qemu-system-x86 cdrtools libarchive ansible # Arch Based Distros
    ```
  * Download the 64 bit version of Ubuntu 22.04.2 Server inside the cloned directory:
    ```bash
    curl -O https://releases.ubuntu.com/releases/24.04.4/ubuntu-24.04.4-live-server-amd64.iso
    ```
  * Download the 64 bit version of eclipse into the `files/` directory:
    ```bash
    cd files && curl -O  https://ftp2.osuosl.org/pub/eclipse/technology/epp/downloads/release/2025-09/R/eclipse-java-2025-09-R-linux-gtk-x86_64.tar.gz
    ```
  * Also download these IDEs in the `files/` directory:<br>
    CLion:
    ```bash
    curl -O https://download-cdn.jetbrains.com/cpp/CLion-2025.2.4.tar.gz
    ```
    IntelliJ:
    ```bash
    curl -O https://download-cdn.jetbrains.com/idea/ideaIC-2025.2.4.tar.gz
    ```
    PyCharm:
    ```bash
    curl -O https://download.jetbrains.com/python/pycharm-2025.3.6.1.tar.gz
    ```
    NetBeans:
    ```bash
    curl -4 -O https://archive.apache.org/dist/netbeans/netbeans-installers/18/apache-netbeans_18-1_all.deb
    ```
    Sublime Text (Build 4200):
    ```bash
    curl -O https://download.sublimetext.com/sublime-text_build-4200_amd64.deb
    ```

  * Download Kotlin zip into the `files/` directory
    ```bash
    curl -L -O https://github.com/JetBrains/kotlin/releases/download/v2.2.0/kotlin-compiler-2.2.0.zip
    ```
  * *(Optional, required if `node_exporter_enabled: true`)* Download Prometheus `node_exporter` into the `files/` directory:
    ```bash
    curl -L -O https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz
    ```

1. Run secrets/gen-secrets.sh to create some ssh keys/other secret data. Follow this with ./fetch-secrets.sh to put them in the right place for ansible. Pass the ID of the contest as an argument on both scripts.
```bash
cd ../secrets
chmod u+x gen-secrets.sh
./gen-secrets.sh 'contestID'
```
```bash
cd ..
chmod u+x fetch-secrets.sh
./fetch-secrets.sh 'contestID'
```
2. Copy `group_vars/all.dist` to `group_vars/all` and edit it to your liking. Specifically
set the icpcadmin password, and firewall expiration properly.
```bash
cp group_vars/all.dist group_vars/all # You can append this with .yml .yaml
# If you want to edit password and firewall expiration
code group_vars/all #opens editor
```

3. Run the `create_baseimg.sh` script to create an unattended installation disk for ubuntu, perform the installation,
and leave the base image ready for processing. During this step you can specify how large you want the image to be(Default 28500M to fit on most
32G flash drives).
```bash
# This step takes around 3-5minutes depending on system/internet speed.
./create_baseimg.sh # optionally add '-s 28500M' for 32GB images, or --no-usb remove the extra fat32 partition
```
4. Build the actual contestant image. This step takes the base image, boots it up,
runs ansible to configure everything, performs a few final cleanup steps, and finally
powers it off. Take a walk, this step takes some time(10-30minutes).
```bash
./build-final.sh
```
5. Take the newly minted image and copy it to a usb drive (or hard drive) (as root). You can see all devices by running 'lsblk'.
```
# WARNING: Make sure to replace /dev/sdx with your actual device
sudo dd if=output/all-2025-09-01_image-amd64.img of=/dev/sdx bs=1M status=progress oflag=direct conv=sparse
```
## Installing Directly on Internal SSDs
If you are installing the contestant environment directly onto the PCs' internal SATA/NVMe SSDs rather than booting from external USB flash drives:

### 1. Configure `group_vars/all` (from `group_vars/all.dist`)
Set `install_target` to `"ssd"` in `group_vars/all` before running `./build-final.sh`:
```yaml
install_target: "ssd"
```
* `"usb"` *(default)* keeps USB flash drive stability workarounds enabled (`blacklist uas`, `usbcore.autosuspend=-1`, `usbcore.lpm_disable=1`, `99-usb-flush.conf` dirty-page caps, `warm-fs-cache.service` boot preloading via `vmtouch`, `fstrim.timer` disabled, and volatile `journald` logs).
* `"ssd"` removes the USB throttling/workarounds and `warm-fs-cache.service`, enables weekly `fstrim.timer`, and persists `journald` logs (capped at 100M).
* *(Optional)* When building a base image exclusively for internal SSDs, pass `--no-usb` to `./create_baseimg.sh` to omit the 192MB FAT32 `ICPC` partition.

### 2. Deploy via USB + Clonezilla
1. Write the built image to a staging USB drive with `dd` (replace `/dev/sdx` with the USB device):
   ```bash
   sudo dd if=output/all-2025-09-01_image-amd64.img of=/dev/sdx bs=1M status=progress oflag=direct conv=sparse
   ```
2. **Do not boot from this staging USB drive.** Booting it directly triggers `firstboot.service`, generates an `/etc/machine-id`, and marks `/icpc/setup-complete` on the source USB before cloning.
3. Boot the target PC into **Clonezilla** and clone **disk-to-local-disk** (`device-device` / `disk_to_local_disk`) from the staging USB drive to the internal SSD (`/dev/sda` or `/dev/nvme0n1`).
   * The image uses `UUID=` in `/etc/fstab`, so it works on both SATA and NVMe drives.
   * By default the root partition stays ~28.5GB; if you want to use the full SSD capacity, enable Clonezilla's proportional partition resize options (`-k1` / `-r` in Expert mode).
4. **Unplug the staging USB drive before rebooting** the PC. Both drives share identical partition/filesystem `UUID`s right after cloning, so leaving both attached can cause GRUB or Linux to mount the wrong disk.
5. *(If needed)* If the PC previously had another OS installed and fails to boot automatically, clear stale EFI boot entries or select the SSD in the UEFI/BIOS boot order.

### 3. First Boot
1. On first boot from the cloned SSD, `systemd` generates a unique `/etc/machine-id` for that workstation.
2. `firstboot.service` switches to `tty2` and launches `/icpc/scripts/icpc_setup` before the desktop starts:
   * Prompts for any unconfigured runtime settings (such as DOMjudge URL/team credentials when `domjudge_enabled: true` and credentials aren't pre-filled, or the print team name when needed).
   * Runs `/icpc/scripts/self_test` (showing `Install Target: ssd` along with system, network, proxy, and compiler checks) and waits for `[Enter]`.
   * Writes `/icpc/setup-complete` and starts LightDM into the `contestant` desktop session.
3. To re-run first-boot setup on a machine later, run `sudo /icpc/scripts/icpc_setup -f` or perform a `Full Reset` (`full-reset`).

## Customization of the Image
One of our goals with this image is for it to be easily customized. To achieve this
the image is configured using Ansible. Ansible is kicked off with the `main.yml`
file, which mostly just includes things in the `playbooks/` subdirectory. For more
details please refer to `playbooks/readme.yml`**[Does not exist]**. Support files for ansible are
found in the `files/` subdirectory.

Some of the ansible plays depend on variables that you can set in the file
`group_vars/all`. Please refer to `group_vars/all.dist` for an example of what
this file should contain. That's where you'll want to go to edit the contest
admin password and configure what urls contestants are allowed to access.

If you want to customize the partition layout, you'll need to edit the
`configs/2004_autoinnstall.yaml` file. By default you'll get a 192MB Fat32 partition
and the rest of the space will be dedicated to the image itself. 14700M works well
as a default size and fits easily on most 16G flash drives you'll encounter. You can
also run `create_baseimage.sh` with `--no-usb` to skip getting the 192MB Fat32 partition
if you don't intend to use these on usb drives the contestants get to keep.

### Testing customizations
There is a script available to help with development so you don't have to build
the full image, wait for it to copy to a usb drive, and then boot.

Follow steps the above until you get to running the `build-final.sh` script;
instead run `./runvm.sh` instead. This will start a VM off the base image, then
give you a menu allowing you to run ansible, ssh in, and a few other utility
functions.

Once you have ansible performing all the tasks you need, halt the vm, then
continue with the `build-final.sh` script. You should never use an image created
by the `runvm.sh` script, always build images using `build-final.sh`

### SSH Access to Built Image
In the final image, SSH password authentication is disabled and `imageadmin` is removed. Only SSH key authentication is permitted via `ssh.service`:
* Connect as the **`icpcadmin`** user using an authorized SSH key (e.g., `files/secrets/icpcadmin@contestmanager`, your local `~/.ssh/id_ed25519`, or a key listed in `icpcadmin_ssh_keys`):
  ```bash
  ssh -i files/secrets/icpcadmin@contestmanager icpcadmin@<ip_or_localhost>
  ```
* When testing under QEMU, run:
  ```bash
  ./connect2qemu.sh
  ```
  This connects as `icpcadmin` on the active port (5222 or 2222).
* You can add custom public keys to `group_vars/all` under `icpcadmin_ssh_keys` prior to building.

### Monitoring (Prometheus node_exporter & Grafana)
Contestant images can optionally run [Prometheus `node_exporter`](https://github.com/prometheus/node_exporter) (`playbooks/monitoring.yml`) for host monitoring in Prometheus and Grafana.

1. Enable and configure it in `group_vars/all` (see `group_vars/all.dist` for defaults):
   ```yaml
   node_exporter_enabled: true
   node_exporter_version: "1.12.1"
   node_exporter_port: 9100
   # Optional: restrict inbound scrapes to your Prometheus server IP/CIDR
   node_exporter_allowed_ips:
     - "192.168.1.10"
   ```
   Download `node_exporter-<version>.linux-amd64.tar.gz` into `files/` beforehand (the build expects the local archive in `files/` and fails if it is missing).
2. When enabled, the build installs `/usr/local/bin/node_exporter`, enables `node_exporter.service` (at low CPU/IO priority), opens port `9100/tcp` in UFW, and configures `icpc-static-node-exporter` (`/usr/local/bin/icpc-metrics`) to expose `icpc_workstation_info`, `icpc_build_ts`, and `icpc_update_ts` under `/var/lib/prometheus/node-exporter`.
3. On your Prometheus server, add a scrape job targeting the contestant machines (port `9100`):
   ```yaml
   scrape_configs:
     - job_name: 'contestants'
       static_configs:
         - targets:
             - '<contestant-ip-1>:9100'
             - '<contestant-ip-2>:9100'
   ```
   Then add Prometheus as a data source in Grafana and import a Node Exporter dashboard (such as Grafana dashboard ID `1860`).


## Reset Contestant
To reset a contestant all you need to do is to `log out` from the contestant user and **log in** to the `Clear Team Account`. When you log in the reset script will automaticly start and it will recreate the `Contestant user` and will reboot the system. Saved DOMjudge team credentials (`/icpc/domjudge_credentials`) are preserved across `Clear Team Account` resets.
In case you want to use the command you can run the `delete-user` command on the admin side.

To perform a full reset (wipe the contestant account, setup completion state, and saved DOMjudge credentials so the machine prompts again on next boot), **log in** to `Full Reset` at the login screen or run `full-reset` (`sudo /icpc/scripts/full_reset.sh`) on the admin side.
