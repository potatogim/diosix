; diosix microkernel 'menchi'
;
; Low-level support for Intel's Virtual Machine Extensions (VMX / VT-x)
;
; Maintainer: Chris Williams (diosix.org)
;

global enable_vmx
global vmxon
global vmx_init_vcms

section .text
bits 64

; define special purpose registers needed to access VMX requirements
IA32_VMX_BASIC          equ 0x480 ; revision ID number for the CPU's VT-x implmentation
IA32_VMX_CR0_REQUIRED	equ 0x486 ; these bits in cr0 must be set
IA32_VMX_CR0_MASK 	equ 0x487 ; any of these bits in cr0 are allowable
IA32_VMX_CR4_REQUIRED   equ 0x488 ; ... as for cr0
IA32_VMX_CR4_MASK	equ 0x489 ; ... as for cr0

; enable_vmx 
;
; Flip all the bits needed to switch on Intel's virtualization
; extensions (VMX / VT-x)
; <= rax = 0 for success or 1 for failure
; Corrupts rbx, rcx, rdx. All other registers preserved.
;
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

; we must set bit 2 and 0 of IA32_FEATURE_CONTROL to enable VMX operations
; and lock out further changes. we can only change bit 2 if bit 0 is
; clear. so set bit 2 first then flip bit 0 to 1.
  mov rcx, IA32_FEATURE_CONTROL
  rdmsr	; MSR copied into edx:eax - the bits we need are in eax

; is the lock bit already set?
  bt eax, IA32_LOCK_BIT
  jnc .enable_vmx_operations	; no -> make changes then lock
; uh-oh, the BIOS has locked us out, but if bit 2 (ENABLE_VMX) is
; set then this part of the setup has been done for us already
  bt eax, IA32_ENABLE_VMX_OUTSIDE_SMX
  jc .lock_bit_done		; ENABLE_VMX set -> no changes needed
  mov rax, 1			; we can't enable VMX - return failure :(
  ret

.enable_vmx_operations:
  or eax, 1 << IA32_ENABLE_VMX_OUTSIDE_SMX
  wrmsr			; enable VMX operations

  or eax, 1 << IA32_LOCK_BIT
  wrmsr			; > > > Changes lockout < < <

.lock_bit_done:
  mov rax, 0		; indicate success
  ret


IA32_FEATURE_CONTROL		equ 0x03a ; controls VMX and SMX operations
IA32_LOCK_BIT			equ 0	  ; bit 0 of IA32_FEATURE_CONTROL
IA32_ENABLE_VMX_OUTSIDE_SMX 	equ 2	  ; bit 2 of IA32_FEATURE_CONTROL

; vmxon
;
; Initialize a VMXON region and execute the instruction VMXON.
; => rdi = physical address of VMXON region
;    rsi = virtual address of VMXON region
; <= rax = 0 for success, or 1 for failure
; Corrupts rdx. All other registers preserved.
; Safe to call from Rust.
;
vmxon:
; set up the VMXON region: store the revision number in the first
; four bytes. Make sure bit 31 is clear.
  call region_revision_write	; uses rsi for virt address

; disable the A20 gate line - because Intel said so :-(
  mov al, 0xdf	; command 0xdf = disable a20 (0xdd to enable)
  out 0x64, al	; send command to keyboard controller

; now we're all clear to enable VMX root mode
; stash the physical address into the stack and pass a pointer
; to the stacked address to the VMXON instruction
  push rdi
  vmxon [rsp]

; check to see if it worked
  jnc .success	; carry clear -> success, set = failure
  mov rax, 1	; indicate failure to the caller
  jmp .done

; welcome to VMX root mode
.success:
  mov rax, 0	; indicate success to the caller
.done:
  add esp, 0x8	; fix up stack
  ret


; vmread/wmwrite offsets


; vmx_init_vcms
;
; Initialize a guest VM's VCMS region. Assumes the region is 4K in size.
; => rdi = physical address of VCMS region
;    rsi = virtual address of VCMS region
; <= rax = 0 for success, or 1 for failure
; Corrupts rdx. All other registers preserved.
; Safe to call from Rust.
;
vmx_init_vcms:
; zero VCMS
  mov rdx, 0
.zero_vcms:
  mov qword [rsi + rdx], 0x0
  add rdx, 0x8
  cmp rdx, 512	; clear a 512 x 8 = 4096 byte page
  jb .zero_vcms

  ; initialize region for a new guest
  call region_revision_write	; uses rsi for virt address
  push rdi
  vmclear [rsp]
  add rsp, 0x8			; fix up stack

  ; select the guest as the active VCMS region so we can
  ; perform vmread/vmwrite operations on it
  call region_revision_write	; ensure revision word is in there
  call vmx_select_guest		; uses rdi for phys address

  

  mov rax, 0			; indicate success to caller
  ret

; vmx_select_guest
; 
; Select a guest for vmread/vmwrite ops
; => rdi = physical address of VCMS region
; All registers preserved.
; Safe to call from Rust.
;
vmx_select_guest:
  push rdi
  vmptrld [rsp]			; use pointer to phys address
  add esp, 0x8			; fix up stack
  ret

; get_vmx_revision
;
; Ask the CPU for the current VMX revision so data structures
; passed to the processor are accepted.
; <= rax = revision number
; All other registers preserved.
;
get_vmx_revision:
  push rcx
  push rdx
  
  mov rcx, IA32_VMX_BASIC
  rdmsr	; result in edx:eax - but we only care about eax
  
  pop rdx
  pop rcx
  ret

; region_revision_write
; 
; Write the VMX revision to a given region's base address
; => rsi = virtual kernel address of the VMX region's base
; All registers preserved.
;
region_revision_write:
  push rax
  call get_vmx_revision	; eax = VMX revision from the CPU
  
  and eax, 0x7fffffff	; mask out bit 31 as per Intel's instructions
  mov [rsi], rax	; write the revision code to the region's first four bytes

  pop rax
  ret
