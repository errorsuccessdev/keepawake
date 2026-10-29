package keepawake

import win "core:sys/windows"
import "base:runtime"

IDI_ON :: 101
WMAPP_NOTIFYICON :: (win.WM_APP + 1)
NOTIFYICON_VERSION_4 :: 4 // TODO: Add to Odin?

showContextMenu :: proc(hwnd: win.HWND)
{
    exitId :: 1
    menu := win.CreatePopupMenu()
    win.InsertMenuW(menu, 1, win.MF_BYPOSITION | win.MF_STRING, exitId, "Exit")

    cursor: win.POINT
	win.GetCursorPos(&cursor)
	// Properly displaying the popup menu requires these ceremonies
	win.SetForegroundWindow(hwnd)
	selection := win.TrackPopupMenu(menu, 
		win.TPM_LEFTALIGN | win.TPM_BOTTOMALIGN | 
        win.TPM_RETURNCMD | win.TPM_LEFTBUTTON,
		cursor.x, cursor.y, 
		0, hwnd, nil)
	win.PostMessageW(hwnd, win.WM_NULL, 0, 0)
    if selection == exitId
    {
        win.PostMessageW(hwnd, win.WM_CLOSE, 0, 0)
    }
}

getIconData :: proc(hwnd: win.HWND) -> ^win.NOTIFYICONDATAW
{    
    userdata := win.GetWindowLongPtrW(hwnd, win.GWLP_USERDATA)
    return cast(^win.NOTIFYICONDATAW)uintptr(userdata)
}

wndproc :: proc "system" (hwnd: win.HWND, msg: u32, 
    wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT
{
    result: win.LRESULT
    context = runtime.default_context()
    switch msg
    {
        case WMAPP_NOTIFYICON:
		{
			notifyMsg := win.LOWORD(lparam)
			if (notifyMsg == win.WM_CONTEXTMENU)
			{
				showContextMenu(hwnd)
			}
		}
        case win.WM_DESTROY:
        {
            win.PostQuitMessage(0)
        }
        case win.WM_CLOSE:
        {
            win.Shell_NotifyIconW(win.NIM_DELETE, getIconData(hwnd))
            win.DestroyWindow(hwnd)
        }
        case:
        {
            result = win.DefWindowProcW(hwnd, msg, wparam, lparam)   
        }
    }
    return result
}

showTrayApplet :: proc(hinst: win.HINSTANCE, hwnd: win.HWND) -> 
    ^win.NOTIFYICONDATAW
{
    iconData := new(win.NOTIFYICONDATAW)
    hicon := win.LoadImageW(hinst, 
        cast(win.LPCWSTR)win.MAKEINTRESOURCEW(IDI_ON), 
        win.IMAGE_ICON, 0, 0, 
        win.LR_SHARED | win.LR_DEFAULTSIZE)
    iconData^ = {
        cbSize = size_of(win.NOTIFYICONDATAW),
        hWnd = hwnd,
        uID = 1,
        uFlags = win.NIF_MESSAGE | win.NIF_ICON | win.NIF_TIP | win.NIF_SHOWTIP,
        uCallbackMessage = WMAPP_NOTIFYICON,
        uVersion = NOTIFYICON_VERSION_4, 
        hIcon = win.HICON(hicon),
    }
    copy_from_string16(iconData.szTip[:], string16("Keep Awake"))
    win.Shell_NotifyIconW(win.NIM_ADD, iconData)
    win.Shell_NotifyIconW(win.NIM_SETVERSION, iconData)
    return iconData
}

main :: proc()
{
    win.SetProcessDpiAwarenessContext(
        win.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    hinst := win.HINSTANCE(win.GetModuleHandleW(nil))
    wc: win.WNDCLASSW = {
        style = win.CS_OWNDC | win.CS_HREDRAW | win.CS_VREDRAW,
        lpfnWndProc = wndproc,
        lpszClassName = "KeepAwakeDebugWindow",
        hInstance = hinst,
    }
    regresult := win.RegisterClassW(&wc)
    assert(regresult != 0)
    hwnd := win.CreateWindowExW(0, 
        wc.lpszClassName, "Keep Awake Debug Window", 
        0, 0, 0, 0, 0, nil, nil, hinst, nil)
    assert(hwnd != nil)    

    win.SetThreadExecutionState(
        win.ES_SYSTEM_REQUIRED | win.ES_DISPLAY_REQUIRED | win.ES_CONTINUOUS)
    iconDataPtr := showTrayApplet(hinst, hwnd)
    defer free(iconDataPtr)
    win.SetWindowLongPtrW(hwnd, win.GWLP_USERDATA, int(uintptr(iconDataPtr)))
    
    msg: win.MSG
    for win.GetMessageW(&msg, hwnd, 0, 0) > 0
    {
        win.TranslateMessage(&msg)
        win.DispatchMessageW(&msg)
    }
}