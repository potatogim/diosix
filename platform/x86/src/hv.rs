/*
 * diosix microkernel 'menchi'
 *
 * Providea hypervisor using Intel Virtualization Extensions on x86 systems
 *
 * See Chapter 23 onwards in Volume 3C of the Intel SDM.
 *
 * Maintainer: Chris Williams (diosix.org)
 *
 */

use errors::KernelInternalError;
use ::hardware::pgstack;
use ::hardware::physmem;

extern
{
    fn vmxon(phys_addr: usize, virt_addr: *mut vmxon_region) -> u8;
}

/* this is 4K page, aligned to a 4K page boundary */
#[repr(C, packed)]
struct vmxon_region
{
    revision: u32
}

pub fn init() -> Result<(), KernelInternalError>
{
    let vmxon_phys_base = try!(pgstack::SYSTEMSTACK.lock().pop());
    let vmxon_virt_base = physmem::phys_to_kernel(vmxon_phys_base) as *mut vmxon_region;

    kprintln!("[hv] vmxon region: physical {:x} virtual {:p}", vmxon_phys_base, vmxon_virt_base);

    /* do the low-level VM management setup */
    if unsafe{ vmxon(vmxon_phys_base, vmxon_virt_base) } != 0
    {
        return Err(KernelInternalError::HVInitFailed);
    }

    kprintln!("[hv] Now running in VMX root mode");

    Ok(())
}


