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
    fn get_vmx_revision() -> u32;
    fn vmxon(phys_addr: usize);
}

/* this is 4K page, aligned to a 4K page boundary */
#[repr(C, packed)]
struct vmon_region
{
    revision: u32
}

pub fn init() -> Result<(), KernelInternalError>
{
    let vmon_phys_base = try!(pgstack::SYSTEMSTACK.lock().pop());
    let mut vmon_virt_base = physmem::phys_to_kernel(vmon_phys_base) as *mut vmon_region;

    kprintln!("[hv] vcms: physical {:x} virtual {:p}", vmon_phys_base, vmon_virt_base);

    /* store the revision in the base of the structure and give the physical base to the processor */
    unsafe
    {
        (*vmon_virt_base).revision = get_vmx_revision();
        vmxon(vmon_phys_base);
    }

    let mut btest = box(vmon_region{revision: unsafe{get_vmx_revision()}});
    
    kprintln!("btest = {:p}", &(btest.revision));

    kprintln!("[hv] still here!");

    Ok(())
}


