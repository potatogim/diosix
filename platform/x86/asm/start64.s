; diosix microkernel 'menchi'
;
; Continue booting an x86 machine in 64-bit long mode
;
; Maintainer: Chris Williams (diosix.org)
;

global start64
global tidy_boot_pg_tables

extern serial_init	; defined in serialport.s
extern enable_vmx	; defined in vmx.s
extern kmain		; Rust kernel entry point

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
  call enable_vmx	; returns 0 in RAX on success
  cmp rax, 0
  je .vmx_successful

; flag up the failure to the user on screen and halt
  mov rax, 0x0c6c0c690c610c46
  mov qword [0xb8000 + (4 * 160)], rax
  jmp halt

.vmx_successful:
; show that virtualization has been enabled
  mov rax, 0x0e740e720e690e56
  mov qword [0xb8000 + (4 * 160)], rax

; enter the Rust-level kernel (should not return)
  call kmain

; nowhere else to go - stop this core
halt:
  cli
  hlt
  jmp halt


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


