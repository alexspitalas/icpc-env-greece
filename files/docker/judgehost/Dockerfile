FROM domjudge/judgehost:9.0.0

ARG KOTLIN_VERSION=2.2.20

# Layer 1: Install unzip (outer container) and GCC 14 / G++ 14 inside /chroot/domjudge
# so judgehost C/C++ compilers match the contestant image (GCC/G++ 14.2.0).
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip; \
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
        g++-14; \
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

# Layer 2: Install Kotlin compiler inside /chroot/domjudge (used by DOMjudge 9.0.0 kt/run)
# and run build-time sanity checks (full JVM compile/run test runs post-build with --privileged).
COPY kotlin-compiler-${KOTLIN_VERSION}.zip /tmp/kotlin-compiler.zip

RUN set -eux; \
    rm -rf /chroot/domjudge/opt/kotlinc; \
    mkdir -p /chroot/domjudge/opt /chroot/domjudge/usr/local/bin; \
    unzip -q /tmp/kotlin-compiler.zip -d /chroot/domjudge/opt; \
    chmod -R a+rX /chroot/domjudge/opt/kotlinc; \
    chmod 755 /chroot/domjudge/opt/kotlinc/bin/*; \
    for bin in kotlinc kotlin kotlinc-jvm kapt; do \
        ln -sf "/opt/kotlinc/bin/${bin}" "/chroot/domjudge/usr/local/bin/${bin}"; \
    done; \
    rm -f /tmp/kotlin-compiler.zip; \
    chroot /chroot/domjudge gcc --version | sed -n '1p' | grep -q '14\.'; \
    chroot /chroot/domjudge g++ --version | sed -n '1p' | grep -q '14\.'; \
    chroot /chroot/domjudge python3 --version; \
    chroot /chroot/domjudge pypy3 --version; \
    chroot /chroot/domjudge bash -c 'KDIR="$(dirname "$(realpath "$(command -v kotlinc)")")"; test -x "${KDIR}/kotlinc" && test -x "${KDIR}/kotlin" && test -r "$(dirname "${KDIR}")/lib/kotlin-stdlib.jar"'; \
    grep -q "^${KOTLIN_VERSION}" /chroot/domjudge/opt/kotlinc/build.txt
