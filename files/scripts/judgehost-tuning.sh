#!/bin/bash
# Stabilize CPU frequency, disable Turbo/Boost, and reduce kernel jitter for DOMjudge judgehosts.
set -u

# 1. Disable Intel Turbo Boost / AMD Precision Boost so single-core and all-core clocks match
if [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
fi

if [ -w /sys/devices/system/cpu/cpufreq/boost ]; then
    echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
fi

for boost in /sys/devices/system/cpu/cpu*/cpufreq/boost; do
    [ -w "$boost" ] && echo 0 > "$boost" 2>/dev/null || true
done

# 2. Record each core's hardware base_frequency (if exposed) before switching intel_pstate mode
declare -A BASE_FREQS=()
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
    [ -d "$c" ] || continue
    if [ -r "$c/base_frequency" ]; then
        BASE_FREQS["$c"]="$(cat "$c/base_frequency" 2>/dev/null || true)"
    fi
done

# 3. Switch intel_pstate from active (HWP) to passive mode so the kernel enforces exact
#    pinned min/max frequencies instead of letting HWP/PL1 drift clocks under load
if [ -w /sys/devices/system/cpu/intel_pstate/status ]; then
    echo passive > /sys/devices/system/cpu/intel_pstate/status 2>/dev/null || true
fi

# 4. Lock CPU scaling governor and Energy Performance Preference (EPP) to performance
#    (must run after switching intel_pstate to passive, which resets the governor)
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$gov" ] && echo performance > "$gov" 2>/dev/null || true
done

for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -w "$epp" ] && echo performance > "$epp" 2>/dev/null || true
done

# 5. Pin scaling_min_freq == scaling_max_freq == base_frequency per core to eliminate
#    idle ramp-up and all-core PL1 power-limit throttling
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
    [ -d "$c" ] || continue
    freq="${BASE_FREQS[$c]:-}"
    if [ -z "$freq" ] && [ -r "$c/base_frequency" ]; then
        freq="$(cat "$c/base_frequency" 2>/dev/null || true)"
    fi
    if [ -n "$freq" ]; then
        [ -w "$c/scaling_min_freq" ] && echo "$freq" > "$c/scaling_min_freq" 2>/dev/null || true
        [ -w "$c/scaling_max_freq" ] && echo "$freq" > "$c/scaling_max_freq" 2>/dev/null || true
        [ -w "$c/scaling_min_freq" ] && echo "$freq" > "$c/scaling_min_freq" 2>/dev/null || true
    fi
done

# 6. Avoid synchronous Transparent Huge Pages compaction stalls
if [ -w /sys/kernel/mm/transparent_hugepage/defrag ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
fi

exit 0
