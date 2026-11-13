#!/bin/sh
# Build and install this Emacs for the Mac it runs on (-mcpu=native targets this CPU).
# Usage: ./build-macos.sh   (replaces /Applications/Emacs.app)
set -eu
cd "$(dirname "$0")"

brew install gcc libgccjit gnutls tree-sitter texinfo autoconf pkgconf
# libgccjit links against gcc's runtime libs; their bottles must target the same macOS.
brew reinstall gcc libgccjit

JIT=$(brew --prefix libgccjit)
GCC=$(brew --prefix gcc)
export PATH="$(brew --prefix texinfo)/bin:$PATH"

# libgccjit rejects -mcpu=native, so resolve it to this Mac's CPU name via the gcc driver.
GCCBIN=$(ls "$GCC"/bin/gcc-[0-9]* | head -1)
CPU=$("$GCCBIN" -mcpu=native -### -x c /dev/null 2>&1 | grep -oE 'mcpu=[a-z0-9.+-]+' | head -1)
[ -n "$CPU" ] || { echo "could not detect CPU" >&2; exit 1; }
# The CPU edit is per-machine; put comp.el back on exit so the tree stays clean for git pull.
trap 'git checkout -- lisp/emacs-lisp/comp.el' EXIT
sed -i '' -E "s/^\(defcustom native-comp-compiler-options '\(\"-O3\" \"-mcpu=[^\"]*\"\)/(defcustom native-comp-compiler-options '(\"-O3\" \"-$CPU\")/" lisp/emacs-lisp/comp.el
grep -q "\"-$CPU\")" lisp/emacs-lisp/comp.el || { echo "failed to set $CPU in comp.el" >&2; exit 1; }
echo "Native-comp target: $CPU"

[ -f configure ] || ./autogen.sh
CFLAGS="-O2 -mcpu=native -I$JIT/include" \
LDFLAGS="-L$JIT/lib/gcc/current -L$GCC/lib/gcc/current -Wl,-rpath,$JIT/lib/gcc/current" \
./configure --with-ns --with-native-compilation=aot --with-tree-sitter --with-gnutls --without-dbus

make -j"$(sysctl -n hw.ncpu)"
make install

# ditto keeps timestamps: cp -R makes .el.gz look newer than .elc, breaking load-prefer-newer.
rm -rf /Applications/Emacs.app
ditto nextstep/Emacs.app /Applications/Emacs.app

mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nexec /Applications/Emacs.app/Contents/MacOS/Emacs "$@"\n' > "$HOME/.local/bin/emacs"
chmod +x "$HOME/.local/bin/emacs"
ln -sf /Applications/Emacs.app/Contents/MacOS/bin/emacsclient "$HOME/.local/bin/emacsclient"

/Applications/Emacs.app/Contents/MacOS/Emacs --batch \
  --eval '(progn (require (quote comp)) (princ (format "%s native=%s opts=%S\n" emacs-version (native-comp-available-p) native-comp-compiler-options)))'
