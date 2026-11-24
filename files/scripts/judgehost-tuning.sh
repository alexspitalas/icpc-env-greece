#!/bin/bash
# Stabilize CPU frequency, disable Turbo/Boost, and reduce kernel jitter for DOMjudge judgehosts.
set -u

# 1. Lock CPU scaling governor and Energy Performance Preference (EPP) to performance
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$gov" ] && echo performance > "$gov" 2>/dev/null || true
done

for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -w "$epp" ] && echo performance > "$epp" 2>/dev/null || true
done

# 2. Disable Intel Turbo Boost / AMD Precision Boost so single-core and all-core clocks match
if [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
fi

if [ -w /sys/devices/system/cpu/cpufreq/boost ]; then
    echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
fi

for boost in /sys/devices/system/cpu/cpu*/cpufreq/boost; do
    [ -w "$boost" ] && echo 0 > "$boost" 2>/dev/null || true
done

# 3. Avoid synchronous Transparent Huge Pages compaction stalls
if [ -w /sys/kernel/mm/transparent_hugepage/defrag ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
fi

exit 0
