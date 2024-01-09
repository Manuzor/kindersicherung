@echo off

zig build --prefix-exe-dir C:\tools\.bin -Dstrip -Drelease %*
