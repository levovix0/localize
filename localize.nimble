version       = "0.3.4"
author        = "levovix0"
description   = "Compile time localization for applications and libraries"
license       = "MIT"
srcDir        = "src"

requires "nim >= 1.6.12"
requires "fusion"

task testCrossCompilation, "test cross-compilation":
  exec "nim c -r -d:mingw --os:windows --cc:gcc --gcc.exe:/usr/bin/x86_64-w64-mingw32-gcc --gcc.linkerexe:/usr/bin/x86_64-w64-mingw32-gcc -o:tests/test.exe tests/test.nim"
