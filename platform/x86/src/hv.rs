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
    fn vmxon(phys_addr: usize, virt_addr: usize) -> u64;
    fn vmx_init_vcms(phys_addr: usize, virt_addr: usize) -> u64;
}

/* describe a per-processor vmxon region, used to maintain a hypevisor's state */
struct VMXONRegion
{
    phys_addr: usize,           /* physical address of region's base */
    virt_addr: usize,           /* kernel virtual address of region's base */
}

/* describe a per-guest VMCS region, used to maintain a guest's state */
struct VMGuestRegion
{
    phys_addr: usize,           /* physical address of region's base */
    virt_addr: usize,           /* kernel virtual address of region's base */
}

/* define a common interface for our VMX regions */
trait VMXRegion: Sized /* Sized needed for the Result<Self, ...> return type */
{
    fn new() -> Result<Self, KernelInternalError>;
}

/* manage a VMXON region */
impl VMXRegion for ::Box<VMXONRegion>
{
    fn new() -> Result<::Box<VMXONRegion>, KernelInternalError>
    {
        let phys_base = try!(pgstack::SYSTEMSTACK.lock().pop());
        let virt_base = physmem::phys_to_kernel(phys_base);

        if unsafe{ vmxon(phys_base, virt_base) } != 0
        {
            try!(pgstack::SYSTEMSTACK.lock().push(phys_base));
            return Err(KernelInternalError::HVInitFailed);
        }

        let region = box VMXONRegion { phys_addr: phys_base, virt_addr: virt_base };
        kprintln!("[hv] initialized vmxon region (phys = {:x})", phys_base);
        Ok(region)
    }
}

/* manage a guest's VCMS region */ 
impl VMXRegion for ::Box<VMGuestRegion>
{
    fn new() -> Result<::Box<VMGuestRegion>, KernelInternalError>
    {
        let phys_base = try!(pgstack::SYSTEMSTACK.lock().pop());
        let virt_base = physmem::phys_to_kernel(phys_base);

        if unsafe{ vmx_init_vcms(phys_base, virt_base) } != 0
        {
            try!(pgstack::SYSTEMSTACK.lock().push(phys_base));
            return Err(KernelInternalError::VMInitFailed);
        }

        let region = box VMGuestRegion { phys_addr: phys_base, virt_addr: virt_base };
        kprintln!("[hv] initialized guest vcms region (phys = {:x})", phys_base);
        Ok(region)
    }
}


pub fn init() -> Result<(), KernelInternalError>
{
    let vmxon_region: ::Box<VMXONRegion> = try!(VMXRegion::new());
    let guest1: ::Box<VMGuestRegion> = try!(VMXRegion::new());

    kprintln!("[hv] VMX root mode entered, guest created!");

    Ok(())
}


