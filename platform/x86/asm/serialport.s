; diosix microkernel 'menchi'
;
; Write out data to the COM1 serial port on x86 machines
;
; Maintainer: Chris Williams (diosix.org)
;

global serial_init, serial_write_byte, serial_write_hex


section .text
bits 64

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
  jmp serial_write_nl	; inserts newline and returns from call

.hex_table:
  db "0123456789abcdef"

;  serial_write_nl
;
;
serial_write_nl:
  mov rdi, 0x0a
  call serial_write_byte
  ret


