/* diosix machine/hypervisor kernel main entry code
 *
 * (c) Chris Williams, 2018.
 *
 * See LICENSE for usage and copying.
 */

/* let the compiler know we're on our own here in bare-metal world */
#![no_std]
#![no_main]

/* this will bring in all the hardware-specific code */
extern crate platform;

#[macro_use]
mod debug; /* get us some kind of debug output, typically to a serial port */
mod abort; /* implement abort() and panic() handlers */
mod irq; /* handle hw interrupts and sw exceptions, collectively known as IRQs */
mod physmem; /* manage physical memory */
mod cpu; /* manage CPU cores */
mod lock; /* multi-threading locking primitives */

/* function naming note: machine kernel entry points start with a k, such as kmain,
kirq_handler. supervisor kernel entry points start with an s, such as smain.
generally, kernel = machine/hypervisor kernel, supervisor = supervisor kernel. */

/* pointer sizes: do not assume this is a 32-bit or 64-bit system. it could be either.
stick to usize as much as possible */

/* kmain
   This code runs at the machine/hypervisor level, with full physical memory access.
   Its job is to create environments in which supervisor kernels run. Thus, the standard diosix
   kernel is split into two halves: a machine/hv lower half, and an upper half supervisor that
   manages user-mode code. This code here is starts that lower half.
   If we want to run a Linux or BSD-like environment, the upper half will be a Linux or BSD
   compatibility layer. The hypervisor allocates regions of memory and CPU time to supervisor
   kernels, which run applications in their own environments.

   Assumes all CPUs enter this function during startup.
   The boot CPU is chosen to initialize the system in pre-SMP mode.
   If we're on a single CPU core then everything should run OK.

   => is_boot_cpu = true if we're chosen to be the boot CPU, or false for every other CPU core
      device_tree_buf = pointer to device tree describing the hardware
   <= return to halt kernel on this core
*/
#[no_mangle]
pub extern "C" fn kmain(is_boot_cpu: bool, device_tree_buf: &u8)
{
    /* make the boot CPU setup physical memory etc for other cores to come online. 
    when the boot CPU is done, it should allow cores to exit cpu::int() */
    if is_boot_cpu == true
    {
        klog!("Welcome to diosix {} ... using device tree at {:p}", env!("CARGO_PKG_VERSION"), device_tree_buf);
        if pre_smp_init(device_tree_buf) == false 
        {
            /* bail out on error */
            return;
        }

        /* everything's set up for all cores to run so unblock any waiting in cpu::init() */
        klog!("Warming up all CPU cores");
        cpu::unblock_smp();
    }

    /* set up all processor cores, including the boot CPU. all CPU cores will block in cpu::init()
    until released by the boot CPU, allowing physical memory and other global resources to be prepared */
    match cpu::init()
    {
        true => klog!("CPU core initialized"),
        false =>
        {
            kalert!("Failed to initialize CPU core");
            return;
        }
    }
}

/* have the boot cpu perform any preflight checks and initialize the kernel prior to SMP.
   <= return true on success, or false for failure */
fn pre_smp_init(device_tree: &u8) -> bool
{
    /* set up the physical memory management */
    match physmem::init(device_tree)
    {
        Some(s) => klog!("Total physical memory available: {} MiB ({} bytes)", s / 1024 / 1024, s),
        None =>
        {
            kalert!("Physical memory failure: too little RAM, or config error");
            return false;
        }
    };

    return true;
}
