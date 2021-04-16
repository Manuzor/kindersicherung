const std = @import("std");
usingnamespace std.os.windows;
const W = std.unicode.utf8ToUtf16LeStringLiteral;
usingnamespace @import("vk_codes.zig");

const WH_KEYBOARD_LL = 13;
const HHOOK = HANDLE;

// typedef LRESULT (CALLBACK *HOOKPROC) (int code, WPARAM wParam, LPARAM lParam)
const HOOKPROC = fn (nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

extern "user32" fn SetWindowsHookExW(idHook: c_int, lpfn: HOOKPROC, hmod: ?HMODULE, dwThreadId: DWORD) callconv(WINAPI) HHOOK;
extern "user32" fn UnhookWindowsHookEx(hhk: HHOOK) callconv(WINAPI) BOOL;
extern "user32" fn CallNextHookEx(hhk: HHOOK, nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

const KBDLLHOOKSTRUCT = extern struct {
    vkCode: DWORD,
    scanCode: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: ULONG_PTR,
};

var global_hook: HHOOK = INVALID_HANDLE_VALUE;

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    global_hook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc, kernel32.GetModuleHandleW(null), 0);
    defer _ = UnhookWindowsHookEx(global_hook);
    _ = try user32.messageBoxW(null, W("Zum Beenden auf 'OK' drücken"), W("Kindersicherung"), user32.MB_OK | user32.MB_ICONINFORMATION);
}

export fn LowLevelKeyboardProc(nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT {
    if (nCode >= 0) {
        if (@intToPtr(?*KBDLLHOOKSTRUCT, @bitCast(usize, lParam))) |keyboard| {
            std.log.info("KB: {}", .{keyboard.*});
            var allow = switch (keyboard.vkCode) {
                VK_BACK => true,
                VK_SPACE => true,
                VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN => true,
                0x30...0x39 => true, // 0-9
                0x41...0x5A => true, // A-Z
                VK_NUMPAD0...VK_NUMPAD9 => true, // Numpad 0-9
                VK_ADD => true,
                VK_MULTIPLY => true,
                VK_SEPARATOR => true,
                VK_SUBTRACT => true,
                VK_DECIMAL => true,
                VK_DIVIDE => true,
                VK_SHIFT, VK_LSHIFT, VK_RSHIFT => true,
                0xBA...0xF5 => true, // OEM specific
                VK_OEM_CLEAR => true,
                else => false,
            };
            if (!allow) {
                std.log.info("INTERCEPT", .{});
                return 1;
            }
        }
    }
    return CallNextHookEx(global_hook, nCode, wParam, lParam);
}
