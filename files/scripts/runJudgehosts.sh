#!/bin/bash
set -euo pipefail

# Set the DOMSERVER_BASEURL IP address
DOMSERVER_IP="192.168.31.200"
DOMSERVER_PORT="80"

# Set the password for all containers
JUDGEDAEMON_PASSWORD="your-secure-password"

# Set the hostname of the judgehost (MUST be unique for each physical PC!)
HOSTNAME="judgedaemon-0"

# Custom judgehost image built by playbooks/domserver.yml (GCC/G++ 14 + Kotlin 2.2.20 on DOMjudge 9.0.0)
JUDGEHOST_IMAGE="icpc/judgehost:9.0.0"

# Optional cap on number of judgehost containers on this PC (0 = all available physical P-cores except CPU 0).
# For strict timing on memory-bound problems, capping below total physical cores reduces L3/DRAM contention.
MAX_CONTAINERS=0

# Ensure the pre-built custom judgehost image exists locally (avoid offline pull attempts)
if ! docker image inspect "$JUDGEHOST_IMAGE" >/dev/null 2>&1; then
    echo "ERROR: Docker image '$JUDGEHOST_IMAGE' was not found locally." >&2
    echo "       Rebuild the judgehost image or check 'docker images'." >&2
    exit 1
fi

# Verify cgroup v2 is active (required by DOMjudge 9.0+)
CGROUP_FS=$(stat -fc %T /sys/fs/cgroup 2>/dev/null || echo "unknown")
if [ "$CGROUP_FS" != "cgroup2fs" ]; then
    echo "WARNING: /sys/fs/cgroup is '$CGROUP_FS' (expected 'cgroup2fs' for DOMjudge 9.0.0)." >&2
    echo "         Ensure systemd.unified_cgroup_hierarchy=0 is removed from /etc/default/grub and reboot." >&2
fi

# Helper: expand a Linux CPU range list (e.g. "0-7,12,14-15") into newline-separated IDs
expand_cpulist() {
    local list="$1"
    local part start end i
    IFS=',' read -ra parts <<< "$list"
    for part in "${parts[@]}"; do
        if [[ "$part" == *-* ]]; then
            start=${part%-*}
            end=${part#*-}
            for ((i=start; i<=end; i++)); do
                echo "$i"
            done
        elif [[ -n "$part" ]]; then
            echo "$part"
        fi
    done
}

# Detect Intel hybrid P-cores if exposed by kernel (/sys/devices/cpu_core/cpus)
declare -A PCORE_SET=()
HAS_HYBRID_PCORES=0
if [ -r /sys/devices/cpu_core/cpus ]; then
    while read -r cid; do
        if [ -n "$cid" ]; then
            PCORE_SET["$cid"]=1
        fi
    done < <(expand_cpulist "$(cat /sys/devices/cpu_core/cpus)")
    if [ "${#PCORE_SET[@]}" -gt 0 ]; then
        HAS_HYBRID_PCORES=1
    fi
fi

# Collect online physical cores (first online logical CPU per physical package:core),
# excluding SMT siblings and hybrid E-cores.
declare -A SEEN_PHYS=()
PHYS_CPUS=()
PHYS_MAXF=()
BEST_MAXF=0

while read -r cpu_id; do
    c="/sys/devices/system/cpu/cpu${cpu_id}"
    # Skip offline CPUs (e.g. offlined by nosmt)
    if [ -f "$c/online" ] && [ "$(cat "$c/online")" != "1" ]; then
        continue
    fi
    # Skip E-cores on hybrid Intel systems
    if [ "$HAS_HYBRID_PCORES" -eq 1 ] && [ -z "${PCORE_SET[$cpu_id]:-}" ]; then
        continue
    fi
    pkg=$(cat "$c/topology/physical_package_id" 2>/dev/null || echo 0)
    core=$(cat "$c/topology/core_id" 2>/dev/null || echo "$cpu_id")
    key="${pkg}:${core}"
    # Only keep the first online logical thread per physical core (never SMT siblings)
    if [ -n "${SEEN_PHYS[$key]:-}" ]; then
        continue
    fi
    SEEN_PHYS["$key"]=1
    maxf=$(cat "$c/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo 0)
    if [ "$maxf" -gt "$BEST_MAXF" ]; then
        BEST_MAXF="$maxf"
    fi
    PHYS_CPUS+=("$cpu_id")
    PHYS_MAXF+=("$maxf")
done < <(find /sys/devices/system/cpu -maxdepth 1 -type d -regex '.*/cpu[0-9]+' -printf '%f\n' | sed 's/^cpu//' | sort -n)

# Fallback E-core filter when /sys/devices/cpu_core/cpus isn't present: keep cores within 85% of top max_freq
ELIGIBLE_CPUS=()
for idx in "${!PHYS_CPUS[@]}"; do
    cpu_id="${PHYS_CPUS[$idx]}"
    maxf="${PHYS_MAXF[$idx]}"
    if [ "$HAS_HYBRID_PCORES" -eq 0 ] && [ "$BEST_MAXF" -gt 0 ] && [ "$maxf" -gt 0 ]; then
        if [ $((maxf * 100)) -lt $((BEST_MAXF * 85)) ]; then
            continue
        fi
    fi
    ELIGIBLE_CPUS+=("$cpu_id")
done

# Reserve the first physical core (CPU 0) for the OS, IRQs, Docker daemon, and SSH
TARGET_CPUS=()
if [ "${#ELIGIBLE_CPUS[@]}" -gt 1 ]; then
    TARGET_CPUS=("${ELIGIBLE_CPUS[@]:1}")
elif [ "${#ELIGIBLE_CPUS[@]}" -eq 1 ]; then
    echo "WARNING: Only 1 physical core detected; falling back to CPU ${ELIGIBLE_CPUS[0]}." >&2
    TARGET_CPUS=("${ELIGIBLE_CPUS[0]}")
else
    echo "ERROR: No online CPUs detected." >&2
    exit 1
fi

if [ "$MAX_CONTAINERS" -gt 0 ] && [ "${#TARGET_CPUS[@]}" -gt "$MAX_CONTAINERS" ]; then
    TARGET_CPUS=("${TARGET_CPUS[@]:0:$MAX_CONTAINERS}")
fi

echo "Creating ${#TARGET_CPUS[@]} judgehost container(s) on physical P-core(s): ${TARGET_CPUS[*]} (reserving CPU ${ELIGIBLE_CPUS[0]} for OS)"

for core in "${TARGET_CPUS[@]}"; do
    docker create \
        --privileged \
        --cgroupns=host \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        --cpuset-cpus="$core" \
        --name "judgehost-$core" \
        --hostname "$HOSTNAME" \
        -e "DAEMON_ID=$core" \
        -e CONTAINER_TIMEZONE=Europe/Athens \
        -e "DOMSERVER_BASEURL=http://$DOMSERVER_IP:$DOMSERVER_PORT/" \
        -e "JUDGEDAEMON_PASSWORD=$JUDGEDAEMON_PASSWORD" \
        "$JUDGEHOST_IMAGE"
done
