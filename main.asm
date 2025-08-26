option casemap:none

extrn GetModuleHandleA : proc
extrn ExitProcess : proc
extrn RegisterClassExA : proc
extrn CreateWindowExA : proc
extrn DefWindowProcA : proc
extrn GetMessageA : proc
extrn TranslateMessage : proc
extrn DispatchMessageA : proc
extrn ShowWindow : proc
extrn PostQuitMessage : proc

; Константы
WM_DESTROY equ 2
CS_HREDRAW equ 2
CS_VREDRAW equ 1
CW_USEDEFAULT equ 80000000h
WS_OVERLAPPEDWINDOW equ 0CF0000h
SW_SHOW equ 5
COLOR_WINDOW equ 5

.data
ClassName db "MyWindowClass",0
AppName   db "Test Window",0

.data?
hInstance dq ?
wc        db 80 dup(?) ; WNDCLASSEXA структура (80 байт)
msg       db 48 dup(?) ; MSG структура (48 байт)

.code
main proc
    sub rsp, 28h
    
    ; Получаем handle модуля
    xor rcx, rcx
    call GetModuleHandleA
    mov hInstance, rax
    
    ; Заполняем структуру WNDCLASSEXA
    mov dword ptr [wc], 80        ; cbSize = sizeof(WNDCLASSEXA)
    mov dword ptr [wc+4], CS_HREDRAW or CS_VREDRAW
    lea rax, WndProc
    mov qword ptr [wc+8], rax     ; lpfnWndProc
    mov dword ptr [wc+16], 0      ; cbClsExtra
    mov dword ptr [wc+20], 0      ; cbWndExtra
    mov rax, hInstance
    mov qword ptr [wc+24], rax    ; hInstance
    mov qword ptr [wc+32], 0      ; hIcon
    mov qword ptr [wc+40], 0      ; hCursor
    mov qword ptr [wc+48], COLOR_WINDOW + 1 ; hbrBackground
    mov qword ptr [wc+56], 0      ; lpszMenuName
    lea rax, ClassName
    mov qword ptr [wc+64], rax    ; lpszClassName
    mov qword ptr [wc+72], 0      ; hIconSm
    
    ; Регистрируем класс окна
    lea rcx, wc
    call RegisterClassExA
    test rax, rax
    jz Exit
    
    ; Создаем окно
    xor rcx, rcx                ; dwExStyle = 0
    lea rdx, ClassName          ; lpClassName
    lea r8, AppName             ; lpWindowName
    mov r9d, WS_OVERLAPPEDWINDOW ; dwStyle
    
    mov qword ptr [rsp+20h], CW_USEDEFAULT  ; X
    mov qword ptr [rsp+28h], CW_USEDEFAULT  ; Y
    mov qword ptr [rsp+30h], 800            ; nWidth
    mov qword ptr [rsp+38h], 600            ; nHeight
    mov qword ptr [rsp+40h], 0              ; hWndParent
    mov qword ptr [rsp+48h], 0              ; hMenu
    mov rax, hInstance
    mov qword ptr [rsp+50h], rax            ; hInstance
    mov qword ptr [rsp+58h], 0              ; lpParam
    
    call CreateWindowExA
    test rax, rax
    jz Exit
    
    ; Показываем окно
    mov rcx, rax
    mov edx, SW_SHOW
    call ShowWindow
    
    ; Цикл сообщений
MessageLoop:
    lea rcx, msg
    xor rdx, rdx
    xor r8, r8
    xor r9, r9
    call GetMessageA
    test eax, eax
    jz Exit
    
    lea rcx, msg
    call TranslateMessage
    
    lea rcx, msg
    call DispatchMessageA
    jmp MessageLoop
    
Exit:
    xor rcx, rcx
    call ExitProcess
main endp

WndProc proc
    ; Параметры: RCX = hwnd, RDX = uMsg, R8 = wParam, R9 = lParam
    
    cmp edx, WM_DESTROY
    jne DefProc
    
    ; Выход из приложения
    xor rcx, rcx
    call PostQuitMessage
    xor rax, rax
    ret
    
DefProc:
    jmp DefWindowProcA
WndProc endp

end