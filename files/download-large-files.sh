#!/bin/bash
# Download large files to speed up build process
# Run this once before building to cache large downloads

set -e

echo "Downloading large files for ICPC environment build..."
echo "This will download ~500MB of files"
echo ""

cd "$(dirname "$0")"

if [ ! -f "eclipse-java-2022-12-R-linux-gtk-x86_64.tar.gz" ]; then
    echo "[1/5] Downloading Eclipse (350MB)..."
    wget -c "http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2022-12/R/eclipse-java-2022-12-R-linux-gtk-x86_64.tar.gz&r=1" \
        -O eclipse-java-2022-12-R-linux-gtk-x86_64.tar.gz
else
    echo "[1/5] Eclipse already downloaded ✓"
fi

if [ ! -f "kotlin-compiler-1.9.24.zip" ]; then
    echo "[2/5] Downloading Kotlin (80MB)..."
    wget -c https://github.com/JetBrains/kotlin/releases/download/v1.9.24/kotlin-compiler-1.9.24.zip
else
    echo "[2/5] Kotlin already downloaded ✓"
fi

if [ ! -f "html_book_20190607.zip" ]; then
    echo "[3/5] Downloading C++ Documentation (20MB)..."
    wget -c https://github.com/PeterFeicht/cppreference-doc/releases/download/v20190607/html-book-20190607.zip
else
    echo "[3/5] C++ Documentation already downloaded ✓"
fi

if [ ! -f "html-book-20250415.7z" ]; then
    echo "[4/5] Downloading Latest C++ Docs HTML (30MB)..."
    wget -c https://github.com/myfreeer/cppreference2mshelp/releases/download/2025.04/html-book-20250415.7z
else
    echo "[4/5] Latest C++ Docs HTML already downloaded ✓"
fi

if [ ! -f "qch-book-20250415.7z" ]; then
    echo "[5/5] Downloading Latest C++ Docs QCH (20MB)..."
    wget -c https://github.com/myfreeer/cppreference2mshelp/releases/download/2025.04/qch-book-20250415.7z
else
    echo "[5/5] Latest C++ Docs QCH already downloaded ✓"
fi

echo ""
echo "✓ All large files downloaded successfully!"
echo "You can now run ./build-final.sh"
echo ""
echo "Total downloaded: $(du -sh . | cut -f1)"
