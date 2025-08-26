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
extrn MessageBoxA : proc

; Константы
WM_DESTROY      equ 2
WM_COMMAND      equ 111h
CS_HREDRAW      equ 2
CS_VREDRAW      equ 1
CW_USEDEFAULT   equ 80000000h
WS_OVERLAPPEDWINDOW equ 0CF0000h
WS_VISIBLE      equ 10000000h
WS_CHILD        equ 40000000h
WS_BORDER       equ 800000h
SW_SHOW         equ 5
COLOR_WINDOW    equ 5
ID_BUTTON_TOGGLE equ 1001
ID_BUTTON_CLEAR  equ 1002
BN_CLICKED      equ 0

.data
ClassName       db "RecycleBinControl",0
AppName         db "Recycle Bin Control",0
ButtonToggleText db "Toggle Recycle Bin",0
ButtonClearText db "Clear Recycle Bin",0
BUTTON_CLASS    db "BUTTON",0
TestMessage     db "Button clicked!",0

.data?
hInstance       dq ?
hWndMain        dq ?
hButtonToggle   dq ?
hButtonClear    dq ?
wc              db 80 dup(?)
msg             db 48 dup(?)

.code
main proc
    sub rsp, 28h
    
    ; Получаем handle модуля
    xor rcx, rcx
    call GetModuleHandleA
    mov hInstance, rax
    
    ; Заполняем структуру WNDCLASSEXA
    mov dword ptr [wc], 80        ; cbSize
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
    
    ; Создаем главное окно
    xor rcx, rcx                ; dwExStyle
    lea rdx, ClassName          ; lpClassName
    lea r8, AppName             ; lpWindowName
    mov r9d, WS_OVERLAPPEDWINDOW ; dwStyle
    
    mov qword ptr [rsp+20h], 100    ; X
    mov qword ptr [rsp+28h], 100    ; Y
    mov qword ptr [rsp+30h], 300    ; nWidth
    mov qword ptr [rsp+38h], 200    ; nHeight
    mov qword ptr [rsp+40h], 0      ; hWndParent
    mov qword ptr [rsp+48h], 0      ; hMenu
    mov rax, hInstance
    mov qword ptr [rsp+50h], rax    ; hInstance
    mov qword ptr [rsp+58h], 0      ; lpParam
    
    call CreateWindowExA
    mov hWndMain, rax
    test rax, rax
    jz Exit
    
    ; Создаем кнопку "Toggle Recycle Bin"
    xor rcx, rcx                ; dwExStyle
    lea rdx, BUTTON_CLASS       ; lpClassName
    lea r8, ButtonToggleText    ; lpWindowName
    mov r9d, WS_CHILD or WS_VISIBLE or WS_BORDER ; dwStyle
    
    mov qword ptr [rsp+20h], 20     ; X
    mov qword ptr [rsp+28h], 20     ; Y
    mov qword ptr [rsp+30h], 150    ; nWidth
    mov qword ptr [rsp+38h], 30     ; nHeight
    mov rax, hWndMain
    mov qword ptr [rsp+40h], rax    ; hWndParent
    mov qword ptr [rsp+48h], ID_BUTTON_TOGGLE ; hMenu (ID)
    mov rax, hInstance
    mov qword ptr [rsp+50h], rax    ; hInstance
    mov qword ptr [rsp+58h], 0      ; lpParam
    
    call CreateWindowExA
    mov hButtonToggle, rax
    
    ; Создаем кнопку "Clear Recycle Bin"
    xor rcx, rcx                ; dwExStyle
    lea rdx, BUTTON_CLASS       ; lpClassName
    lea r8, ButtonClearText     ; lpWindowName
    mov r9d, WS_CHILD or WS_VISIBLE or WS_BORDER ; dwStyle
    
    mov qword ptr [rsp+20h], 20     ; X
    mov qword ptr [rsp+28h], 60     ; Y
    mov qword ptr [rsp+30h], 150    ; nWidth
    mov qword ptr [rsp+38h], 30     ; nHeight
    mov rax, hWndMain
    mov qword ptr [rsp+40h], rax    ; hWndParent
    mov qword ptr [rsp+48h], ID_BUTTON_CLEAR ; hMenu (ID)
    mov rax, hInstance
    mov qword ptr [rsp+50h], rax    ; hInstance
    mov qword ptr [rsp+58h], 0      ; lpParam
    
    call CreateWindowExA
    mov hButtonClear, rax
    
    ; Показываем окно
    mov rcx, hWndMain
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
    ; Параметры УЖЕ в регистрах: RCX=hwnd, RDX=uMsg, R8=wParam, R9=lParam
    
    ; Сохраняем оригинальные параметры в стеке
    push rcx
    push rdx
    push r8
    push r9
    
    cmp edx, WM_DESTROY
    je OnDestroy
    
    cmp edx, WM_COMMAND
    je OnCommand
    
    ; Восстанавливаем параметры и прыгаем на стандартный обработчик
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp DefWindowProcA
    
OnDestroy:
    ; Восстанавливаем стек
    add rsp, 32 ; 4 параметра * 8 байт = 32 байта
    
    xor rcx, rcx
    call PostQuitMessage
    xor rax, rax
    ret
    
OnCommand:
    ; Проверяем, что это сообщение от кнопки
    mov rax, r8
    shr rax, 16          ; HIWORD(wParam) = notification code
    cmp ax, BN_CLICKED
    jne DefWindowProcAfterRestore
    
    ; LOWORD(wParam) = ID контрола
    mov rax, r8
    and eax, 0FFFFh      ; LOWORD(wParam)
    
    cmp eax, ID_BUTTON_TOGGLE
    je ButtonToggleClicked
    
    cmp eax, ID_BUTTON_CLEAR
    je ButtonClearClicked
    
DefWindowProcAfterRestore:
    ; Восстанавливаем параметры и прыгаем на стандартный обработчик
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp DefWindowProcA
    
ButtonToggleClicked:
    ; Восстанавливаем только то, что нужно для MessageBox
    pop r9
    pop r8
    pop rdx
    pop rcx
    
    ; Временное сообщение для теста
    push rcx  ; Сохраняем hwnd для возврата
    mov rcx, 0
    lea rdx, TestMessage
    lea r8, AppName
    xor r9, r9
    call MessageBoxA
    pop rcx   ; Восстанавливаем hwnd
    
    ; Возвращаем 0 - сообщение обработано
    xor rax, rax
    ret
    
ButtonClearClicked:
    ; Восстанавливаем только то, что нужно для MessageBox
    pop r9
    pop r8
    pop rdx
    pop rcx
    
    ; Временное сообщение для теста
    push rcx  ; Сохраняем hwnd для возврата
    mov rcx, 0
    lea rdx, TestMessage
    lea r8, AppName
    xor r9, r9
    call MessageBoxA
    pop rcx   ; Восстанавливаем hwnd
    
    ; Возвращаем 0 - сообщение обработано
    xor rax, rax
    ret
    
WndProc endp

end