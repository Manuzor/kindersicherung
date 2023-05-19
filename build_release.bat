@echo off

zig build install -Drelease -Dstrip --prefix zig-out\release

set PATH=%PATH%;C:\tools\ResourceHacker
where /q ResourceHacker.exe && (
    echo Patching executable resources to add an icon...
    ResourceHacker.exe -open zig-out\release\bin\kindersicherung.exe -save zig-out\release\bin\kindersicherung.exe -action addskip -res app.ico -mask ICONGROUP,MAINICON,
) || (
    echo WARNING: ResourceHacker not found. Executable will have the default icon.
)
