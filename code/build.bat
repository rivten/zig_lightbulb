@echo off

pushd ..\build
zig build-exe ..\code\lightbulb.zig
popd
