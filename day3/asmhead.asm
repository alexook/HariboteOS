; haribote-os

BOTPAK  EQU   0x00280000  ; 加载bootpack
DSKCAC  EQU   0x00100000  ; 磁盘缓存的位置
DSKCAC0 EQU   0x00008000  ; 实模式磁盘缓存的位置

; 有关BOOT_INFO
CYLS    EQU   0x0ff0      ; 设置启动区
LEDS    EQU   0x0ff1
VMODE   EQU   0x0ff2      ; 关于颜色数目的信息，颜色的位数
SCRNX   EQU   0x0ff4      ; 分辨率X
SCRNY   EQU   0x0ff6      ; 分辨率Y
VRAM    EQU   0x0ff8      ; 图像缓冲区的起始位置

  ORG   0xc200            ; 程序被加载的内存地址

; 设置屏幕模式
  MOV   AL, 0x13          ; VGA显卡，320x200x8 bit
  MOV   AH, 0x00
  INT   0x10

  MOV   BYTE [VMODE], 8   ; 屏幕的模式
  MOV   WORD [SCRNX], 320
  MOV   WORD [SCRNY], 200
  MOV   DWORD [VRAM], 0x000a0000

; 用BIOS取得键盘上各种LED指示灯的状态
  MOV   AH, 0x02
  INT   0x16              ; 键盘BIOS
  MOV   [LEDS], AL

; 防止PIC接受所有中断
;   根据AT兼容机的规范初始化PIC
;   如果没有在CLI指令前执行可能会挂起
;   并继续初始化PIC
  MOV   AL, 0xff
  OUT   0x21, AL
  NOP                     ; 有些机器不能连续执行NOP指令
  OUT   0xa1, AL

; 设置A20GATE使CPU支持1M以上的内存
  CALL  waitkbdout
  MOV   AL, 0xd1
  OUT   0x64, AL
  CALL  waitkbdout
  MOV   AL, 0xdf          ; 开启A20
  OUT   0x60, AL
  CALL  waitkbdout

; 切换到保护模式
; [INSTRSET "i486p"]        ; 使用486指令
  LGDT  [GDTR0]           ; 设置临时GDT
  MOV   EAX, CR0
  AND   EAX, 0x7fffffff
  OR    EAX, 0x00000001
  MOV   CR0, EAX
  JMP   pipelineflush

pipelineflush:
  MOV   AX, 1 * 8
  MOV   DS, AX
  MOV   ES, AX
  MOV   FS, AX
  MOV   GS, AX
  MOV   SS, AX

;
  MOV   ESI, bootpack
  MOV   EDI, BOTPAK
  MOV   ECX, 512 * 1024 / 4
  CALL  memcpy

;

;
  MOV   ESI, 0x7c00
  MOV   EDI, DSKCAC
  MOV   ECX, 512 / 4
  CALL  memcpy

;
  MOV   ESI, DSKCAC0 + 512
  MOV   EDI, DSKCAC + 512
  MOV   ECX, 0
  MOV   CL, BYTE [CYLS]
  IMUL  ECX, 512 * 18 * 2 / 4
  SUB   ECX, 512 / 4
  CALL  memcpy

;
;

;
  MOV   EBX, BOTPAK
  MOV   ECX, [EBX + 16]
  ADD   ECX, 3
  SHR   ECX, 2
  JZ    skip
  MOV   ESI, [EBX + 20]
  ADD   ESI, EBX
  MOV   EDI, [EBX + 12]
  CALL  memcpy

skip:
  MOV   ESP, [EBX + 12]
  JMP   DWORD 2 * 8:0x0000001b

waitkbdout:
  IN    AL, 0x64
  AND   AL, 0x02
  JNZ   waitkbdout
  RET

memcpy:
  MOV   EAX, [ESI]
  AND   ESI, 4
  MOV   [EDI], EAX
  ADD   EDI, 4
  SUB   ECX, 1
  JNZ   memcpy
  RET
;

  ALIGN 16
GDT0:
  RESB  8
  DW    0xffff, 0x0000, 0x9200, 0x00cf
  DW    0xffff, 0x0000, 0x9a28, 0x0047

  DW    0

GDTR0:
  DW    8 * 3 - 1
  DD    GDT0

  ALIGN 16
bootpack:
