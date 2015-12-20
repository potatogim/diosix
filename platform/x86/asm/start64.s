; diosix microkernel 'menchi'
;
; Continue booting an x86 machine in 64-bit long mode
;
; Maintainer: Chris Williams (diosix.org)
;

global start64
global serial_write_byte
global tidy_boot_pg_tables

extern kmain	; kernel entry point

; linker symbols
extern __kernel_ro_start
extern __kernel_ro_end
extern __kernel_rw_start
extern __kernel_rw_end

; page tables
extern boot_pd_table
extern boot_pt0_table
extern boot_pt1_table

; needed to check for stack overflow
extern boot_stack_bottom

section .text
bits 64

; start64
;
; Jumped to from the 32-bit startup code.
; Now running in 64-bit long mode with our own
; GDT and basic paging system enabled. Interrupts are off.
;
start64:
; write 'Done' to 4th line of video text to signal we're here
  mov rax, 0x0a650a6e0a6f0a44
  mov qword [0xb8000 + (3 * 160)], rax

; enable the COM1 serial port for kernel debugging.
; it's easier to capture and analyze debugging info from
; the serial port than reading numbers off a screen.
; we've used video to this point to show the system is
; alive and running. but detailed info should be logged
; to the serial port.
  call serial_init

; enable the virtualization support in hardware
  call enable_vmx

; show that virtualization has been enabled
  mov rax, 0x0e740e720e690e56
  mov qword [0xb8000 + (4 * 160)], rax

; enter the Rust-level kernel
  call kmain

; nowhere else to go - stop this core
halt:
  cli
  hlt
  jmp $


; -------------------------------------------------------------------
;
; enable_vmx 
;
; Flip all the bits needed to switch on Intel's virtualization
; extensoons (VMX / VT-x)
;

; define special purpose registers needed to access VMX requirements
IA32_VMX_CR0_REQUIRED	equ 0x486 ; these bits in cr0 must be set
IA32_VMX_CR0_MASK 	equ 0x487 ; any of these bits in cr0 are allowable
IA32_VMX_CR4_REQUIRED   equ 0x488 ; ... as for cr0
IA32_VMX_CR4_MASK	equ 0x489 ; ... as for cr0

enable_vmx:
  ; the CPU kindly tells us which bits we need to set in cr0 and
  ; cr4 to enable vmx support. it also tells us which bits cannot
  ; be set in cr0 and cr4 in order to be compatible with vmx mode
  mov rcx, IA32_VMX_CR0_REQUIRED 
  rdmsr 	; loads edx:eax with values we need
  shl rdx, 32	; combine edx with upper rax
  or rax, rdx	; rax = edx:eax

  mov rbx, cr0
  or rbx, rax	; these flags must be set in cr0 for VMX code to work
  mov cr0, rbx

  mov rcx, IA32_VMX_CR0_MASK
  rdmsr
  shl rdx, 32
  or rax, rdx	; rax = edx:eax

  mov rbx, cr0
  and rbx, rax	; any flags zero'd are not allowed in VMX mode
  mov cr0, rbx

  ; do what we just did to cr0 to cr4
  mov rcx, IA32_VMX_CR4_REQUIRED
  rdmsr
  shl rdx, 32
  or rax, rdx	; rax = edx:eax

  mov rbx, cr4
  or rbx, rax	; set any required flag bits
  mov cr4, rbx

  mov rcx, IA32_VMX_CR4_MASK
  rdmsr
  shl rdx, 32
  or rax, rdx	; rax = edx:eax

  mov rbx, cr4
  and rbx, rax	; clear any banned flag bits
  mov cr4, rbx

  ret

; -------------------------------------------------------------------
;
; tidy_boot_pg_tables
;
; Tidy up the boot page page tables by clearing out all page
; entries from 4M to 1024M, then mapping the kernel code, read-only
; data and bss scratch space in using 4KB pages.
;
; Safe to call from Rust - preserves all registers
;
tidy_boot_pg_tables:
  push rax
  push rbx
  push rcx
  push rdx

; the page tables sit right below the boot stack. if the stack
; grows too far, we'll crash over the page tables. this happens
; with a 4K stack. 8K appears to give the kernel enough space.
; bail out early if there's a sign that the stack has gone
; past boot_stack_bottom
;
; TODO: use a guard page instead
;
  mov rax, boot_stack_bottom
  sub rax, 8		; check 64-bit word below the stack
  cmp qword [rax], 0	; should be zero
  jne .stack_overflow
  sub rax, 8		; check next word
  cmp qword [rax], 0	; should also be zero
  jne .stack_overflow
  jmp .clear_2m_pages	; no sign of corruption, so continue

; stack overflow detected - write Stck in red to screen and halt
.stack_overflow:
  mov rax, 0x0c6b0c630c740c53
  mov qword [0xb8000 + (5 * 160)], rax
  jmp halt

; clear the 4M-1GB entries in the page directory. that's entry 2 to
; 511. we don't need them any more - the kernel's mapped all physical
; memory into the upper virtual space.
.clear_2m_pages:
  xor rax, rax
  mov ebx, 2
.clear_2m_pg_loop:
  mov qword [boot_pd_table + ebx * 8], rax
  inc ebx
  cmp ebx, 512
  jb .clear_2m_pg_loop

; the first 2MB of kernel virtual memory will be described by
; boot_pt0_table. the next 2MB of virtual memory will be described
; by boot_pt1_table. both are placed consecutively in memory so
; we can treat them as a contiguous 1024 x 64-bit array.

; identity map the kernel's components to their physical
; addresses.

; first create mappings for the read-only part of the kernel.
; in future the rodata should be non-execute but it's not a major
; problem as long as it's not writeable.
  mov rax, __kernel_ro_start
  shr rax, 12
  and rax, 0x3ff		; turn start address into table index
  mov rbx, __kernel_ro_end
  shr rbx, 12
  and rbx, 0x3ff		; turn end address into table index

  mov rcx, __kernel_ro_start	; this should be page aligned
  or rcx, 0x101			; present, read-only, kernel-only, global
.setup_kernel_4k_ro_pg:
  mov qword [boot_pt0_table + eax * 8], rcx
  add rcx, 4096
  inc eax
  cmp eax, ebx
  jb .setup_kernel_4k_ro_pg

; next, create mappings for the writeable section of the kernel
  mov rax, __kernel_rw_start
  shr rax, 12
  and rax, 0x3ff		; turn start address into table index
  mov rbx, __kernel_rw_end
  shr rbx, 12
  and rbx, 0x3ff		; turn end address into table index

  mov rcx, __kernel_rw_start	; this should be page aligned
  or rcx, 0x103			; present, read-write, kernel-only, global
  mov rdx, 1
  shl rdx, 63			; set bit 63 (the nx bit)
  or rcx, rdx			; prevent execution in the writeable area
.setup_kernel_4k_rw_pg:
  mov qword [boot_pt0_table + eax * 8], rcx
  add rcx, 4096
  inc eax
  cmp eax, ebx
  jb .setup_kernel_4k_rw_pg

; now point the PD table entries for the 0-4M range at the above
; two page tables
  mov rax, boot_pd_table
  mov rbx, boot_pt0_table
  or rbx, 0x3			; present, read-write, kernel-only use a 4K PT
  mov [rax], rbx
  
  mov rbx, boot_pt1_table
  or rbx, 0x3			; ditto
  mov [rax + 8], rbx

  pop rdx
  pop rcx
  pop rbx
  pop rax
  ret

; -------------------------------------------------------------------

; serial_init
; 
; Initialize the first serial port (COM1) for kernel debugging.
; the IO port number for the serial port is 0x3f8
; TODO: check this initialization sequence - it may fail on real hardware
;
serial_init:

serial_port equ 0x3f8

  mov ax, 0x00      ; disable interrupts
  mov dx, serial_port + 1
  out dx, al
  
  mov ax, 0x80      ; prepare to set baud rate divisor
  mov dx, serial_port + 3
  out dx, al

  mov ax, 0x03      ; set baud rate divisor (low byte) to 0x3
  mov dx, serial_port + 0
  out dx, al
  
  mov ax, 0x00      ; set baud rate divisor (high byte) to 0x0
  mov dx, serial_port + 1
  out dx, al
  
  mov ax, 0x03      ; 8 bits, no parity, one stop bit
  mov dx, serial_port + 3
  out dx, al

  ret


; serial_write_byte
; 
; Write a byte to the serial port
; => rdi = character to write; lowest byte is sent to the serial port
;    Corrupts rax, rdx. All registers preserved.
;    Can be called externally from Rust.
;
serial_write_byte:
  mov dx, serial_port + 5 ; get serial port status
.tx_loop:
  in al, dx  		  ; read in flags
  and al, 1 << 5          ; check if transmit buffer is empty (bit 5 set)
  jz .tx_loop	 	  ; loop until it is empty (bit 5 is set)

  mov rax, rdi
  mov dx, serial_port + 0
  out dx, al              ; write byte out to the data port
  ret

; serial_write_hex
;
; Write a 64-bit unsigned integer out to the serial port
; as an ASCII hexadecimal string.
; => rsi = value to write
; Corrupts rcx, rax, rdx, rdi. All other registers preserved.
;
serial_write_hex:
  mov cx, 64		; keep track of how many times we need to shift down rsi

.write_hex_loop:
  sub cx, 4
  mov rdi, rsi
  shr rdi, cl
  and rdi, 0x0f
  add rdi, .hex_table
  mov dil, [rdi]
  call serial_write_byte

  cmp cx, 0
  jnz .write_hex_loop
  jmp serial_write_nl

.hex_table:
  db "0123456789abcdef"

;  serial_write_nl
;
;
serial_write_nl:
  mov rdi, 0x0a
  call serial_write_byte
  ret

