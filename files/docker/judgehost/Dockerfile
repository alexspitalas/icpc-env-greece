FROM domjudge/judgehost:9.0.0

ARG KOTLIN_VERSION=2.2.20

# Layer 1: Install GCC 14 / G++ 14 in BOTH the outer container (used by DOMjudge
# to compile jury executables/validators and for direct container inspection) and
# inside /chroot/domjudge (used for all contestant compilation, version checks,
# and execution), plus CPython 3 inside /chroot/domjudge so judgehost toolchains
# match the contestant image (GCC/G++ 14.2.0, OpenJDK 21, Python 3.12, PyPy 3).
# Note: unzip and python3 are already pre-installed in the outer container of
# domjudge/judgehost:9.0.0.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    if [ -f /etc/apt/sources.list ] \
       && ! grep -Eq '^[[:space:]]*deb[[:space:]].*\buniverse\b' /etc/apt/sources.list; then \
        sed -i '/^[[:space:]]*deb[[:space:]]/ s/$/ universe/' /etc/apt/sources.list; \
    fi; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ] \
       && ! grep -Eq '^Components:.*\buniverse\b' /etc/apt/sources.list.d/ubuntu.sources; then \
        sed -i '/^Components:/ s/$/ universe/' /etc/apt/sources.list.d/ubuntu.sources; \
    fi; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gcc-14 \
        g++-14; \
    if [ -x /usr/bin/gcc-13 ]; then \
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 50; \
    fi; \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100; \
    update-alternatives --set gcc /usr/bin/gcc-14; \
    if [ -x /usr/bin/g++-13 ]; then \
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 50; \
    fi; \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100; \
    update-alternatives --set g++ /usr/bin/g++-14; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    RESOLV_HAD_ORIG=0; \
    if [ -e /chroot/domjudge/etc/resolv.conf ] || [ -L /chroot/domjudge/etc/resolv.conf ]; then \
        mv /chroot/domjudge/etc/resolv.conf /tmp/chroot-resolv.conf.orig; \
        RESOLV_HAD_ORIG=1; \
    fi; \
    cp /etc/resolv.conf /chroot/domjudge/etc/resolv.conf; \
    if [ -f /chroot/domjudge/etc/apt/sources.list ] \
       && ! grep -Eq '^[[:space:]]*deb[[:space:]].*\buniverse\b' /chroot/domjudge/etc/apt/sources.list; then \
        sed -i '/^[[:space:]]*deb[[:space:]]/ s/$/ universe/' /chroot/domjudge/etc/apt/sources.list; \
    fi; \
    if [ -f /chroot/domjudge/etc/apt/sources.list.d/ubuntu.sources ] \
       && ! grep -Eq '^Components:.*\buniverse\b' /chroot/domjudge/etc/apt/sources.list.d/ubuntu.sources; then \
        sed -i '/^Components:/ s/$/ universe/' /chroot/domjudge/etc/apt/sources.list.d/ubuntu.sources; \
    fi; \
    chroot /chroot/domjudge env DEBIAN_FRONTEND=noninteractive apt-get update; \
    chroot /chroot/domjudge env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        gcc-14 \
        g++-14 \
        python3; \
    if [ -x /chroot/domjudge/usr/bin/gcc-13 ]; then \
        chroot /chroot/domjudge update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 50; \
    fi; \
    chroot /chroot/domjudge update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100; \
    chroot /chroot/domjudge update-alternatives --set gcc /usr/bin/gcc-14; \
    if [ -x /chroot/domjudge/usr/bin/g++-13 ]; then \
        chroot /chroot/domjudge update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 50; \
    fi; \
    chroot /chroot/domjudge update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100; \
    chroot /chroot/domjudge update-alternatives --set g++ /usr/bin/g++-14; \
    if [ "$RESOLV_HAD_ORIG" -eq 1 ]; then \
        mv /tmp/chroot-resolv.conf.orig /chroot/domjudge/etc/resolv.conf; \
    else \
        rm -f /chroot/domjudge/etc/resolv.conf; \
    fi; \
    chroot /chroot/domjudge apt-get clean; \
    rm -rf /chroot/domjudge/var/lib/apt/lists/*

# Layer 2: Install Kotlin compiler under /chroot/domjudge/usr/lib/kotlinc (MUST be
# inside /usr because DOMjudge's chroot-startstop.sh only bind-mounts etc/usr/lib/bin/lib64,
# NOT /opt) and expose it in both the chroot and the outer container via /usr/local/bin.
# Full JVM compile/run tests run post-build with --privileged using chroot-startstop.sh.
COPY kotlin-compiler-${KOTLIN_VERSION}.zip /tmp/kotlin-compiler.zip

RUN set -eux; \
    rm -rf /chroot/domjudge/opt/kotlinc /chroot/domjudge/usr/lib/kotlinc; \
    mkdir -p /chroot/domjudge/usr/lib /chroot/domjudge/usr/local/bin /usr/local/bin; \
    unzip -q /tmp/kotlin-compiler.zip -d /chroot/domjudge/usr/lib; \
    mkdir -p /chroot/domjudge/usr/lib/kotlinc/lib/jansi; \
    unzip -j -o -q /chroot/domjudge/usr/lib/kotlinc/lib/kotlin-compiler.jar \
        '*/native/Linux/x86_64/libjansi.so' \
        -d /chroot/domjudge/usr/lib/kotlinc/lib/jansi; \
    test -f /chroot/domjudge/usr/lib/kotlinc/lib/jansi/libjansi.so; \
    grep -q 'KOTLIN_HOME="$(findKotlinHome)"' /chroot/domjudge/usr/lib/kotlinc/bin/kotlinc; \
    sed -i '/^KOTLIN_HOME="$(findKotlinHome)"$/a java_args=("-Dlibrary.jansi.path=${KOTLIN_HOME}/lib/jansi")' \
        /chroot/domjudge/usr/lib/kotlinc/bin/kotlinc; \
    sed -i 's/^declare -a java_args$/# java_args initialized with library.jansi.path above/' \
        /chroot/domjudge/usr/lib/kotlinc/bin/kotlinc; \
    chmod -R a+rX /chroot/domjudge/usr/lib/kotlinc; \
    chmod 755 /chroot/domjudge/usr/lib/kotlinc/bin/* /chroot/domjudge/usr/lib/kotlinc/lib/jansi/libjansi.so; \
    for bin in kotlinc kotlin kotlinc-jvm kapt; do \
        ln -sf "/usr/lib/kotlinc/bin/${bin}" "/chroot/domjudge/usr/local/bin/${bin}"; \
        ln -sf "/chroot/domjudge/usr/lib/kotlinc/bin/${bin}" "/usr/local/bin/${bin}"; \
    done; \
    rm -f /tmp/kotlin-compiler.zip; \
    gcc --version | sed -n '1p' | grep -q '14\.'; \
    g++ --version | sed -n '1p' | grep -q '14\.'; \
    python3 --version; \
    bash -c 'KDIR="$(dirname "$(realpath "$(command -v kotlinc)")")"; test -x "${KDIR}/kotlinc" && test -x "${KDIR}/kotlin" && test -r "$(dirname "${KDIR}")/lib/kotlin-stdlib.jar"'; \
    chroot /chroot/domjudge gcc --version | sed -n '1p' | grep -q '14\.'; \
    chroot /chroot/domjudge g++ --version | sed -n '1p' | grep -q '14\.'; \
    chroot /chroot/domjudge python3 --version; \
    chroot /chroot/domjudge pypy3 --version; \
    chroot /chroot/domjudge bash -c 'KDIR="$(dirname "$(realpath "$(command -v kotlinc)")")"; case "$KDIR" in /usr/*) ;; *) echo "ERROR: kotlinc must live under /usr (got $KDIR)" >&2; exit 1 ;; esac; test -x "${KDIR}/kotlinc" && test -x "${KDIR}/kotlin" && test -r "$(dirname "${KDIR}")/lib/kotlin-stdlib.jar"'; \
    grep -q "^${KOTLIN_VERSION}" /chroot/domjudge/usr/lib/kotlinc/build.txt
