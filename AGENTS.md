This repository is a personal fork of GNU Emacs, used only by its
owner.  It is not GNU Emacs mainline and nothing here is submitted
upstream, so upstream's policy against LLM-generated contributions
does not apply: write and edit code freely.

Upstream changes are merged in regularly.  Keep the fork's changes
small and self-contained so those merges stay clean: prefer new
functions and new files to rewriting upstream code, and leave
unrelated code and formatting alone.

Do not prepare patches, bug reports or other text for the Emacs
project from this repository.  Upstream still does not accept
LLM-generated ones.

The fork's own work targets macOS (the NS port).  ./build-macos.sh
builds and installs it, replacing /Applications/Emacs.app, so run it
only when asked.

What the fork adds
==================

Everything is on top of an upstream import (commit 8471e49) and lives
in the NS port: src/nsterm.m, src/nsterm.h, src/nsfns.m, src/nsfont.m,
src/macfont.m, plus small hooks in src/frame.c, src/image.c and
configure.ac.  'git diff 8471e49 --stat' shows the whole fork.

Build tuning (build-macos.sh)
  Native compilation ahead of time, tree-sitter, GnuTLS, no D-Bus, and
  -O2 -mcpu=native for C.  Lisp is native-compiled at -O3 for the
  local CPU: the script resolves "native" to the real CPU name,
  because libgccjit rejects "native", and patches that into
  native-comp-compiler-options in lisp/emacs-lisp/comp.el for the
  length of the build only.  A trap restores the file, so the tree
  stays clean for merges.  The app is copied with ditto, which keeps
  timestamps so that .elc files stay newer than their .el.gz.

Frame parameters
  alpha-background       Honoured on macOS: background fills take the
                         frame's alpha, text stays solid.
  ns-background-image    An image file under the text, filling the
                         window including the title bar, tinted.
  ns-background-glitch   Now and then the background image drifts out
                         of focus or breaks up like damaged video.
                         Plist: :interval, :intensity, :style.
  ns-crt                 A CRT after RetroArch's CRT-Royale: scanlines,
                         halation, phosphor mask, curvature.  Plist:
                         :target, :intensity, :scanline, :mask,
                         :curvature.
  ns-interference        Television snow.  Plist: :target, :intensity.
  The setters are in src/nsfns.m and the parameters are registered in
  src/frame.c.

Display
  After drawing, the view's layer is displayed and the transaction
  flushed at once, because ns_select_1 skips the AppKit run loop while
  subprocess output is pending and the frame would stay unpainted.

Tab bar
  Dragging a tab carries a picture of it along the tab bar under the
  pointer (dragTabGhost: in src/nsterm.m; tab_bar_tab_rect in
  src/xdisp.c gives the tab's rectangle).  Lisp still does the
  reordering when the button comes up, in tab-bar-mouse-move-tab.
  Dragged below the tab bar, the tab can be dropped on a side of the
  windows: a translucent block shows the half it would take and
  settles into place on release.  Within 40 pixels of the outer edge
  the side is of all the windows, elsewhere of the window under the
  pointer.  nsterm.m leaves the side in ns-tab-drop-side and the
  window (nil for all) in ns-tab-drop-window, and
  tab-bar-mouse-move-tab hands them to
  tab-bar-merge-tab-at-side (lisp/tab-bar.el), which moves the tab's
  windows beside the recent tab's and closes it.  The tab under the
  pointer gets a soft highlight (hoverTab:).

How it is built
===============

The effects are Core Animation layers attached to the window's frame
view (the superview of the content view), ordered by zPosition: the
background image at -1, the tab drop zone at 0.4, the tab hover at
0.45, the tab drag ghost at 0.5, snow at 1, the CRT glass pane at 2.
See
attachOverlays: and placeEffect:in:z: in src/nsterm.m.

EmacsEffect is the one general effect layer: a CAMetalLayer whose
shader is compiled at run time from source held in src/nsterm.m.  It
renders on its own thread and only while it has something to show.

EmacsLayer holds what redisplay draws.  Its contents is an IOSurface
that is recycled on every display, so anything that wants the drawn
pixels must copy them.

Rules learned the hard way
  Change the layer tree (add, remove, resize, hide) only on the main
  thread.  A render thread may only draw; doing more crashed in
  CALayer setBounds.
  Wrap layer changes in a CATransaction with actions disabled, or Core
  Animation animates them.
  Honour the Reduce Motion setting: animated effects rest under it.
  Memory management in the NS port is manual retain and release.
  Effects that copy another program's look are checked against it side
  by side, not by eye from memory (the CRT's average colour is within
  about 1% of CRT-Royale).

Working in the tree
  The tree is built in place, so after a change to src/ an ordinary
  'make' in the top directory is enough to check that it compiles.
  Run the result as src/emacs -Q; nextstep/Emacs.app does not start
  after an incremental build, because its dump file and native-lisp
  directory are only refreshed by 'make install'.
  To test mouse gestures without taking the pointer, start src/emacs
  with a server and drive its window with 'orca computer drag --app
  pid:N', taking pictures with 'screencapture -l WINDOW-ID'.  Events
  posted with CGEventPostToPid do not arrive.
  Commit messages follow upstream's style: an imperative summary line
  and a prose body that says why.
