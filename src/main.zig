const std = @import("std");
const win = std.os.windows;
const W = std.unicode.utf8ToUtf16LeStringLiteral;
const vk = @import("vk_codes.zig");

const DWORD = win.DWORD;
const ULONG_PTR = win.ULONG_PTR;
const HWND = win.HWND;
const WINAPI = win.WINAPI;
const HANDLE = win.HANDLE;
const WPARAM = win.WPARAM;
const LPARAM = win.LPARAM;
const LRESULT = win.LRESULT;
const HMODULE = win.HMODULE;
const BOOL = win.BOOL;
const INVALID_HANDLE_VALUE = win.INVALID_HANDLE_VALUE;

const WH_KEYBOARD_LL = 13;
const HHOOK = HANDLE;

// typedef LRESULT (CALLBACK *HOOKPROC) (int code, WPARAM wParam, LPARAM lParam)
const HOOKPROC = fn (nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

extern "kernel32" fn GetConsoleWindow() callconv(WINAPI) ?HWND;
extern "user32" fn SetWindowsHookExW(idHook: c_int, lpfn: HOOKPROC, hmod: ?HMODULE, dwThreadId: DWORD) callconv(WINAPI) ?HHOOK;
extern "user32" fn UnhookWindowsHookEx(hhk: ?HHOOK) callconv(WINAPI) BOOL;
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
    if (SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc, win.kernel32.GetModuleHandleW(null), 0)) |hook| {
        global_hook = hook;
    }
    if (global_hook == INVALID_HANDLE_VALUE) {
        std.log.err("failed to install hook.", .{});
        return error.HookInstallFailed;
    }
    if (GetConsoleWindow()) |console_window| {
        _ = win.user32.ShowWindow(console_window, win.user32.SW_HIDE);
    }
    std.log.info("hook is installed.", .{});
    defer _ = UnhookWindowsHookEx(global_hook);
    _ = try win.user32.messageBoxW(null, W("Zum Beenden auf 'OK' drücken"), W("Kindersicherung"), win.user32.MB_OK | win.user32.MB_ICONINFORMATION);
}

export fn LowLevelKeyboardProc(nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT {
    if (nCode >= 0) {
        if (@intToPtr(?*KBDLLHOOKSTRUCT, @bitCast(usize, lParam))) |keyboard| {
            std.log.debug("KB: {}", .{keyboard.*});
            var allow = switch (keyboard.vkCode) {
                vk.VK_BACK => true,
                vk.VK_SPACE => true,
                vk.VK_LEFT, vk.VK_UP, vk.VK_RIGHT, vk.VK_DOWN => true,
                0x30...0x39 => true, // 0-9
                0x41...0x5A => true, // A-Z
                vk.VK_NUMPAD0...vk.VK_NUMPAD9 => true, // Numpad 0-9
                vk.VK_ADD => true,
                vk.VK_MULTIPLY => true,
                vk.VK_SEPARATOR => true,
                vk.VK_SUBTRACT => true,
                vk.VK_DECIMAL => true,
                vk.VK_DIVIDE => true,
                vk.VK_SHIFT, vk.VK_LSHIFT, vk.VK_RSHIFT => true,
                0xBA...0xF5 => true, // OEM specific
                vk.VK_OEM_CLEAR => true,
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
