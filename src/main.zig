// TODO
//   * Allow äöüß
//
const std = @import("std");

const win = struct {
    usingnamespace std.os.windows;
    pub const user32 = struct {
        const SW_HIDE = 0;
        const MB_OK = 0x00;
        const MB_ICONINFORMATION = 0x00000040;
    };
};

const W = std.unicode.utf8ToUtf16LeStringLiteral;
const vk = @import("vk_codes.zig");

const DWORD = win.DWORD;
const UINT = win.UINT;
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

var call_index: i64 = 0;

extern "kernel32" fn GetConsoleWindow() callconv(WINAPI) ?HWND;
extern "user32" fn SetWindowsHookExW(idHook: c_int, lpfn: *const HOOKPROC, hmod: ?HMODULE, dwThreadId: DWORD) callconv(WINAPI) ?HHOOK;
extern "user32" fn UnhookWindowsHookEx(hhk: ?HHOOK) callconv(WINAPI) BOOL;
extern "user32" fn CallNextHookEx(hhk: HHOOK, nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;
extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(WINAPI) win.SHORT;
extern "user32" fn ShowWindow(hWnd: ?HWND, nCmdShow: c_int) callconv(WINAPI) c_int;
extern "user32" fn MessageBoxW(hWnd: ?HWND, lpText: [*:0]const u16, lpCaption: [*:0]const u16, uType: UINT) callconv(WINAPI) c_int;

const KBDLLHOOKSTRUCT = extern struct {
    vkCode: DWORD,
    scanCode: DWORD,
    flags: DWORD,
    time: DWORD,
    dwExtraInfo: ULONG_PTR,
};

var global_hook: HHOOK = INVALID_HANDLE_VALUE;

pub fn main() anyerror!void {
    if (SetWindowsHookExW(WH_KEYBOARD_LL, &LowLevelKeyboardProc, win.kernel32.GetModuleHandleW(null), 0)) |hook| {
        global_hook = hook;
    }
    if (global_hook == INVALID_HANDLE_VALUE) {
        std.log.err("failed to install hook.", .{});
        return error.HookInstallFailed;
    }
    if (GetConsoleWindow()) |console_window| {
        _ = ShowWindow(console_window, win.user32.SW_HIDE);
    }
    std.log.info("hook is installed.", .{});
    defer _ = UnhookWindowsHookEx(global_hook);
    _ = MessageBoxW(null, W("Zum Beenden auf 'OK' drücken"), W("Kindersicherung"), win.user32.MB_OK | win.user32.MB_ICONINFORMATION);
}

export fn LowLevelKeyboardProc(nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT {
    defer call_index += 1;
    if (nCode >= 0) {
        if (@as(?*KBDLLHOOKSTRUCT, @ptrFromInt(@as(usize, @bitCast(lParam))))) |keyboard| {
            // std.log.debug("KB: {}", .{keyboard.*});
            const ctrl_state = @as(u16, @bitCast(GetKeyState(vk.CONTROL)));
            const ctrl = (ctrl_state & 0b10000000_00000000) != 0;
            var allow = switch (keyboard.vkCode) {
                vk.BACK => true,
                vk.SPACE => true,
                vk.LEFT, vk.UP, vk.RIGHT, vk.DOWN => true,
                vk.HOME, vk.END, vk.PRIOR, vk.NEXT => true,
                vk.@"0"...vk.@"9" => !ctrl, // 0-9
                vk.A...vk.Z => !ctrl, // A-Z
                vk.NUMPAD0...vk.NUMPAD9 => true, // Numpad 0-9
                vk.ADD => true,
                vk.MULTIPLY => true,
                vk.SEPARATOR => true,
                vk.SUBTRACT => true,
                vk.DECIMAL => true,
                vk.DIVIDE => true,
                vk.SHIFT, vk.LSHIFT, vk.RSHIFT => true,
                vk.CONTROL, vk.LCONTROL, vk.RCONTROL => true,
                0xBA...0xF5 => true, // OEM specific
                vk.OEM_CLEAR => true,
                vk.RETURN => true,
                vk.ESCAPE => true,
                else => false,
            };
            if (ctrl and keyboard.vkCode == vk.A) { // CTRL+A
                allow = true;
            }
            if (ctrl and keyboard.vkCode == vk.Z) { // CTRL+Z
                allow = true;
            }
            if (ctrl and keyboard.vkCode == vk.Y) { // CTRL+Y
                allow = true;
            }
            if (!allow) {
                std.log.info("[{} 0b{b:0<16}] INTERCEPT vk code 0x{x}", .{ call_index, ctrl_state, keyboard.vkCode });
                return 1;
            }
        }
    }
    return CallNextHookEx(global_hook, nCode, wParam, lParam);
}
