@echo off

zig build install -Drelease-small -Dstrip --prefix "%~dp0zig-out\release"

set PATH=%PATH%;C:\tools\ResourceHacker
where /q ResourceHacker.exe && (
    echo "Patching executable resources to add an icon..."
    ResourceHacker.exe -open "%~dp0zig-out\release\bin\kindersicherung.exe" -save "%~dp0zig-out\release\bin\kindersicherung.exe" -action addskip -res "%~dp0app.ico" -mask ICONGROUP,MAINICON,
)
