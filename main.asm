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
extrn RegOpenKeyExA : proc
extrn RegSetValueExA : proc
extrn RegQueryValueExA : proc
extrn RegCloseKey : proc
extrn SHEmptyRecycleBinA : proc
extrn lstrlenA : proc
extrn SetWindowTextA:proc
extrn GetVolumeNameForVolumeMountPointA:proc
extrn GetStdHandle:proc
extrn WriteConsoleA:proc




includelib kernel32.lib
includelib user32.lib
includelib advapi32.lib
includelib shell32.lib

; ���������
WM_DESTROY      equ 2
WM_COMMAND      equ 111h
CS_HREDRAW      equ 2
CS_VREDRAW      equ 1
WS_OVERLAPPEDWINDOW equ 0CF0000h
WS_VISIBLE      equ 10000000h
WS_CHILD        equ 40000000h
WS_BORDER       equ 800000h
SW_SHOW         equ 5
COLOR_WINDOW    equ 5
ID_BUTTON_TOGGLE equ 1001
ID_BUTTON_CLEAR  equ 1002
BN_CLICKED      equ 0
HKEY_CURRENT_USER     equ 80000001h
KEY_SET_VALUE         equ 20002h
KEY_QUERY_VALUE       equ 20001h
REG_DWORD             equ 4
SHERB_NOCONFIRMATION  equ 1h
SHERB_NOPROGRESSUI    equ 2h
SHERB_NOSOUND         equ 4h

.data
ClassName       db "RecycleBinControl",0
AppName         db "Recycle Bin ",0
ButtonToggleText db "Toggle Recycle Bin",0
ButtonClearText db "Clear Recycle Bin",0
BUTTON_CLASS    db "BUTTON",0

.data?
hInstance       dq ?
hWndMain        dq ?
hButtonToggle   dq ?
hButtonClear    dq ?
wc              db 80 dup(?)
msg             db 48 dup(?)

.data
RecycleKeyPath  db 200 dup(0)
ValueName       db "NukeOnDelete",0
MsgEnabled      db "ON",0
MsgDisabled     db "OFF",0
EmptySuffix db " (Empty)",0
DebugMessage db "GetRecycleBinState returned: %d",0
DebugTitle   db "Debug Info",0
MsgSuccess   db "Success! Value: %d",0
MsgErrorGeneral db "Error reading registry value",0
RecycleBinFileCount dq 1  


RecycleBinPath db "C:\$Recycle.Bin\*",0


.data
BaseKeyPath db "Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume",0
mountPoint db "C:\",0
volumeGUID db 50 dup(0)
bytesWritten dq 0

; ��������� ��� �����������
MsgEmptyPath     db "Error: Path is empty!",0
MsgOpenError     db "Error: Cannot open registry key!",0
MsgReadError     db "Error: Cannot read registry value!",0
MsgToggleError  db "Error toggling Recycle Bin state",0

.data?
hKey            dq ?
dwType          dd ?
dwValue         dd ?
dwSize          dd ?

.code

; === ������� ===
SaveRegs MACRO
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
ENDM

RestoreRegs MACRO
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
ENDM


GetRecycleKeyPath proc
    SaveRegs
    sub rsp, 20h
    
    ; �������� GUID ����
    mov rcx, offset mountPoint
    mov rdx, offset volumeGUID
    mov r8, sizeof volumeGUID
    call GetVolumeNameForVolumeMountPointA
    test rax, rax
    jz fail

    ; �������� ������� ���� � ���������� ����������
    mov rdi, offset RecycleKeyPath
    mov rsi, offset BaseKeyPath
copy_base:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz copy_base
    dec rdi ; ������������ �� ������������ ����

    ; ��������� �������� ����!
    mov byte ptr [rdi], '\'
    inc rdi

    ; �������� GUID
    mov rsi, offset volumeGUID
    add rsi, 10
copy_guid:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    cmp al, '}'
    jne copy_guid

    ; ��������� 0
    mov byte ptr [rdi], 0
    jmp success

fail:
    ; � ������ ������ ������ �������� ����
    mov byte ptr [RecycleKeyPath], 0

success:
    add rsp, 20h
    RestoreRegs
    ret
GetRecycleKeyPath endp




main proc
    sub rsp, 28h

    ; �������� handle ������
    xor rcx, rcx
    call GetModuleHandleA
    mov hInstance, rax
    
    
    ; ��������� ��������� WNDCLASSEXA
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
    
    ; ������������ ����� ����
    lea rcx, wc
    call RegisterClassExA
    test rax, rax
    jz Exit
    
    ; ������� ������� ����
    xor rcx, rcx                ; dwExStyle
    lea rdx, ClassName          ; lpClassName
    lea r8, AppName             ; lpWindowName
    mov r9d, WS_OVERLAPPEDWINDOW ; dwStyle
    
    mov qword ptr [rsp+20h], 100    ; X
    mov qword ptr [rsp+28h], 100    ; Y
    mov qword ptr [rsp+30h], 300   ; nWidth
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
    
    ; ������� ������ "Toggle Recycle Bin"
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
    
    ; ������� ������ "Clear Recycle Bin"
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

    call GetRecycleKeyPath

    call UpdateWindowTitle

    ; ���������� ����
    mov rcx, hWndMain
    mov edx, SW_SHOW
    call ShowWindow
    
    ; ���� ���������
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
    ; ��������� ��� � ���������: RCX=hwnd, RDX=uMsg, R8=wParam, R9=lParam
    
    ; ��������� ������������ ��������� � �����
    push rcx
    push rdx
    push r8
    push r9
    
    cmp edx, WM_DESTROY
    je OnDestroy
    
    cmp edx, WM_COMMAND
    je OnCommand
    
    ; ��������������� ��������� � ������� �� ����������� ����������
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp DefWindowProcA
    
OnDestroy:
    ; ��������������� ����
    add rsp, 32 ; 4 ��������� * 8 ���� = 32 �����
    
    xor rcx, rcx
    call PostQuitMessage
    xor rax, rax
    ret
    
OnCommand:
    ; ���������, ��� ��� ��������� �� ������
    mov rax, r8
    shr rax, 16          ; HIWORD(wParam) = notification code
    cmp ax, BN_CLICKED
    jne DefWindowProcAfterRestore
    
    ; LOWORD(wParam) = ID ��������
    mov rax, r8
    and eax, 0FFFFh      ; LOWORD(wParam)
    
    cmp eax, ID_BUTTON_TOGGLE
    je ButtonToggleClicked
    
    cmp eax, ID_BUTTON_CLEAR
    je ButtonClearClicked
    
DefWindowProcAfterRestore:
    ; ��������������� ��������� � ������� �� ����������� ����������
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp DefWindowProcA
    
ButtonToggleClicked:
    ; ��������������� ������ ��, ��� ����� ��� MessageBox
    pop r9
    pop r8
    pop rdx
    pop rcx
    
    call ToggleRecycleBin
    
    ; ���������� 0 - ��������� ����������
    xor rax, rax
    ret
    
ButtonClearClicked:
    pop r9
    pop r8
    pop rdx
    pop rcx
    
    ; ������ �������� ������� �������
    call ClearRecycleBin
    
    xor rax, rax
    ret

WndProc endp



UpdateWindowTitle proc
    SaveRegs
    sub rsp, 100h
    
    call GetRecycleBinState
    mov ebx, eax
    
    ; ��������� ����� ��� ���������
    lea rdi, [rsp+20h]
    
    ; �������� ������� ��������
    mov rsi, offset AppName
copy_base:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz copy_base
    dec rdi
    
    mov word ptr [rdi], ' -'
    add rdi, 2
    
    cmp ebx, 0
    je add_enabled
    cmp ebx, 1
    je add_disabled
    jmp add_unknown
    
add_enabled:
    mov rsi, offset MsgEnabled
    jmp copy_status
    
add_disabled:
    mov rsi, offset MsgDisabled
    jmp copy_status
    
add_unknown:
    mov rsi, offset MsgErrorGeneral
    
copy_status:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz copy_status
    
    ; ��������� ���������� ������ � ������� ����� ���������� RecycleBinFileCount
    cmp RecycleBinFileCount, 0
    jg set_title          ; ���� ����� ���� - �� ��������� Empty
    
    ; ��������� " (Empty)"
    mov rsi, offset EmptySuffix
add_empty:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz add_empty
    
set_title:
    mov rcx, hWndMain
    lea rdx, [rsp+20h]
    call SetWindowTextA
    
    add rsp, 100h
    RestoreRegs
    ret
UpdateWindowTitle endp

; ������� ������ �������� ��������� �������
; ����������: RAX = 0 (��������) ��� 1 (���������)
GetRecycleBinState proc
    SaveRegs    
    sub rsp, 40h
    
    
    ; ��������� ��� ���� �� ������
    lea rcx, RecycleKeyPath
    call lstrlenA
    test eax, eax
    jnz path_not_empty
    
    ; ���� ������ - ���������� ������
    mov rcx, 0
    lea rdx, MsgEmptyPath
    mov r8, offset DebugTitle
    mov r9, 0
    call MessageBoxA
    mov eax, 0FFFFFFFFh
    jmp ExitGetState
    
path_not_empty:
    ; �������������� ����������
    mov hKey, 0
    mov dwValue, 0
    mov dwSize, 4
    
    ; ��������� ���� �������
    mov rcx, HKEY_CURRENT_USER
    lea rdx, RecycleKeyPath
    xor r8, r8
    mov r9, KEY_QUERY_VALUE
    lea rax, hKey
    mov [rsp+20h], rax
    call RegOpenKeyExA
    
    ; ���������� ��������� �������� �����
    test rax, rax
    jz open_success
    
    ; ������ ��������
    mov rcx, 0
    lea rdx, MsgOpenError
    mov r8, offset DebugTitle
    mov r9, 0
    call MessageBoxA
    jmp ErrorGetState
    
open_success:
    ; ������ ��������
    mov rcx, hKey
    lea rdx, ValueName
    xor r8, r8
    lea r9, dwType
    lea rax, dwValue
    mov [rsp+20h], rax
    lea rax, dwSize
    mov [rsp+28h], rax
    call RegQueryValueExA
    
    test rax, rax
    jnz ErrorReadValue
    
    ; ��������� ����
    mov rcx, hKey
    call RegCloseKey

    ; ���������� ��������
    mov eax, dwValue
    jmp ExitGetState
    
ErrorReadValue:
    mov rcx, hKey
    call RegCloseKey
    
    ; ���������� ������ ������
    mov rcx, 0
    lea rdx, MsgReadError
    mov r8, offset DebugTitle
    mov r9, 0
    call MessageBoxA
    
    mov eax, 0FFFFFFFEh
    jmp ExitGetState
    
ErrorGetState:
    ; ���������� ������ ��������
    mov rcx, 0
    lea rdx, MsgOpenError
    mov r8, offset DebugTitle
    mov r9, 0
    call MessageBoxA
    
    mov eax, 0FFFFFFFFh
    
ExitGetState:
    add rsp, 40h
    RestoreRegs
    ret
GetRecycleBinState endp


SetRecycleBinState proc
    SaveRegs
    sub rsp, 40h
    
    mov hKey, 0
    mov dwValue, ecx        ; �������� 0 (enabled) ��� 1 (disabled)
    
    ; ��������� ����
    mov rcx, HKEY_CURRENT_USER
    lea rdx, RecycleKeyPath    ; ������ ����� ���������� ����
    xor r8, r8
    mov r9, KEY_SET_VALUE
    lea rax, hKey
    mov [rsp+20h], rax
    call RegOpenKeyExA
    
    test rax, rax
    jnz ErrorSetState
    
    ; ������������� ��������
    mov rcx, hKey           ; hKey
    lea rdx, ValueName      ; lpValueName
    xor r8, r8              ; Reserved = 0
    mov r9d, REG_DWORD      ; dwType
    lea rax, dwValue        ; lpData
    mov [rsp+20h], rax
    mov dword ptr [rsp+28h], 4 ; cbData = sizeof(DWORD)
    call RegSetValueExA
    
    test rax, rax
    jnz ErrorSetValue
    
    ; ��������� ����
    mov rcx, hKey
    call RegCloseKey
    xor eax, eax            ; �����
    jmp ExitSetState
    
ErrorSetValue:
    mov rcx, hKey
    call RegCloseKey
    
ErrorSetState:
    mov eax, 1              ; ������
    
ExitSetState:
    add rsp, 40h
    RestoreRegs
    ret
SetRecycleBinState endp


; ������� ������� �������
ClearRecycleBin proc
    SaveRegs
    sub rsp, 28h
    
    ; �������� SHEmptyRecycleBinA
    xor rcx, rcx
    xor rdx, rdx
    mov r8d, SHERB_NOCONFIRMATION or SHERB_NOPROGRESSUI or SHERB_NOSOUND
    call SHEmptyRecycleBinA
    
    ; ������ ������������� ������� � 0 (������������ �������� �������)
    mov RecycleBinFileCount, 0
    
    ; ��������� ��������� ����� �������
    call UpdateWindowTitle
    
    xor eax, eax  ; ������ ���������� �����
    
    add rsp, 28h
    RestoreRegs
    ret
ClearRecycleBin endp

ToggleRecycleBin proc
    SaveRegs
    sub rsp, 28h
    
    ; �������� ������� ���������
    call GetRecycleBinState
    
    ; ��������� �� ������
    cmp eax, 0FFFFFFFFh
    je ExitToggleError
    cmp eax, 0FFFFFFFEh
    je ExitToggleError
    
    ; ����������� �������� (0->1, 1->0)
    xor eax, 1
    
    ; ������������� ����� ��������
    mov ecx, eax
    call SetRecycleBinState
    test eax, eax
    jnz ExitToggleError

    call UpdateWindowTitle

    
    call GetRecycleBinState  ; ����� ������ ��� �������������
    jmp ExitToggle
    
    
ExitToggleError:
    sub rsp, 20h
    mov rcx, 0
    lea rdx, MsgToggleError
    lea r8, DebugTitle
    xor r9, r9
    call MessageBoxA
    add rsp, 20h
    
ExitToggle:
    add rsp, 28h
    RestoreRegs
    ret
ToggleRecycleBin endp


end