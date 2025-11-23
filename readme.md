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

### Improvements Over Previous Setup
- **Up-to-date content** (2025 vs 2019 - 6 years newer)
- **C++20/C++23 features** included
- **Search functionality** - find functions/classes instantly
- **Better organization** - unified documentation experience
- **Desktop integration** - easy access during contests

## IDE Java Version Consistency

### Eclipse Configuration
Eclipse is configured to use Java 21 consistently with the system-wide installation:

- **Compiler Compliance Level**: Java 21
- **JVM Paths**: Points to `/usr/lib/jvm/java-21-openjdk-amd64`
- **JavaDoc**: Links to Java 21 API documentation
- **Default JDK**: Set to OpenJDK 21

This ensures that:
- Code compiled in Eclipse matches DOMjudge compilation
- No version mismatch errors during development
- Consistent behavior between IDE and command-line compilation
- Access to Java 21 features (records, pattern matching, virtual threads, etc.)

### Other IDEs
- **IntelliJ IDEA**: Automatically detects system Java 21
- **VS Code**: Uses system Java via extensions
- **Command Line**: `javac` and `java` commands use Java 21

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

## Building the Image
Building the image is a very simple process, and takes between 10-30minutes
depending on connection speed and various other factors.

1. Clone this repository:
```bash
git clone https://github.com/SfikasTeo/icpc-env-greece.git
cd icpc-env-greece
```
1. Make sure dependencies are met
  * Install required packages
    ```bash
    sudo apt-get install qemu-system-x86 genisoimage bsdtar ansible # Debian based Distros
    sudo apt-get install qemu-system-x86 genisoimage ansible libarchive-tools # Debian based Distros without bsdtar
    sudo pacman -S qemu-system-x86 cdrtools libarchive ansible # Arch Based Distros
    ```
  * Download the 64 bit version of Ubuntu 20.04.6 Server inside the cloned directory:
    ```bash
    curl -O https://cdimage.ubuntu.com/releases/jammy/release/inteliot/ubuntu-22.04-live-server-amd64+intel-iot.iso
    ```
  * Download the 64 bit version of eclipse into the `files/` directory:
    ```bash
    cd files && wget http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2023-06/R/eclipse-java-2023-06-R-linux-gtk-x86_64.tar.gz

1. Run secrets/gen-secrets.sh to create some ssh keys/other secret data. Follow this with ./fetch-secrets.sh to put them in the right place for ansible.
2. Copy `group_vars/all.dist` to `group_vars/all` and edit it to your liking. Specifically
set the icpcadmin password, and firewall expiration properly.
3. Run the `create_baseimg.sh` script to create an unattended installation disk for ubuntu, perform the installation,
and leave the base image ready for processing. During this step you can specify how large you want the image to be(Default 28500M to fit on most
32G flash drives).
```bash
# This step takes around 3-5minutes depending on system/internet speed.
./create_baseimg.sh # optionally add '-s 28500M' for 32GB images, or --no-usb remove the extra fat32 partition
```
4. Build the actual contestant image. This step takes the base image, boots it up,
runs ansible to configure everything, performs a few final cleanup steps, and finally
powers it off. Take a walk, this step takes some time(10-30minutes)
```bash
./build-final.sh
```
5. Take the newly minted image and copy it to a usb drive (or hard drive) (as root)
```
# WARNING: Make sure to replace /dev/sdx with your actual device
sudo dd if=output/2020-09-01_image-amd64.img of=/dev/sdx bs=1M status=progress oflag=direct conv=sparse
```
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

## DOMjudge Configuration

To ensure consistency between the contestant environment and judging system, configure DOMjudge with these exact compiler flags:

### languages.yaml Configuration

```yaml
c:
  name: "C"
  extensions: ["c"]
  compile_script: "gcc -x c -g -O2 -std=gnu11 -static -o $DEST $SOURCES -lm"
  
cpp:
  name: "C++"
  extensions: ["cc", "cpp", "cxx", "c++"]
  compile_script: "g++ -x c++ -g -O2 -std=gnu++20 -static -o $DEST $SOURCES"
  
java:
  name: "Java"
  extensions: ["java"]
  compile_script: "javac -encoding UTF-8 -sourcepath . -d . $SOURCES"
  run_script: "java -Dfile.encoding=UTF-8 -XX:+UseSerialGC -Xss64m -Xms{memlim}m -Xmx{memlim}m $MAINCLASS"
  
kotlin:
  name: "Kotlin"
  extensions: ["kt"]
  compile_script: "kotlinc -d . $SOURCES"
  run_script: "kotlin -Dfile.encoding=UTF-8 -J-XX:+UseSerialGC -J-Xss64m -J-Xms{memlim}m -J-Xmx{memlim}m $MAINCLASS"
  
python3:
  name: "Python 3"
  extensions: ["py"]
  run_script: "pypy3 $MAINFILE"  # Use PyPy3, not CPython
```

### Compiler Versions

The contestant environment now includes:
- **Java**: OpenJDK 21 (updated from 11 to match ICPC 2025 standards)
- **Kotlin**: Version 1.9.24 (updated from 1.7.10)
- **C/C++**: gcc/g++ 13.x (installed from ubuntu-toolchain-r PPA to match ICPC 2025 standards)
- **Python**: PyPy3 (primary interpreter for judging)

**Note**: GCC/G++ 13 is installed from the ubuntu-toolchain-r PPA and set as the default compiler to ensure ICPC 2025 compliance.
