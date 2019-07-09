# diosix

[![Build Status](https://travis-ci.org/diodesign/diosix.svg?branch=master)](https://travis-ci.org/diodesign/diosix)

This is a lightweight, secure, multithreaded, and multiprocessor container-based hypervisor-microkernel
operating system written in Rust for 32-bit and 64-bit RISC-V systems.

### Rationale

It is a work in progress: I'm starting from scratch
after [previously writing](https://github.com/diodesign/diosix-legacy) a working microkernel for
32-bit SMP x86 computers in C and assembly.

I learned a lot from that foray, and so this is the second iteration of diosix. Crucially,
it will be written [in Rust](https://www.rust-lang.org/), a C/C++-like programming language that has a fierce emphasis
on performance, guaranteed memory safety, threads without data races, and other security features.
I chose [RISC-V](https://riscv.org/) because it's interesting new ground to explore,
whereas there are countless x86 and Arm operating system kernels out there.
For one thing, highly capable RISC-V cores can fit in FPGAs, paving the way for
systems that have the freedom to boot truly open-source custom CPUs, peripheral controllers,
hypervisors, kernels, and operating systems as required.

For one thing, highly capable RISC-V cores can fit in FPGAs, paving the way for
systems that have the freedom to boot truly open-source custom CPUs, peripheral controllers,
hypervisors, kernels, and operating systems as required.

### Running and building

Below is a screenshot of the hypervisor-microkernel booting in a quad-core 64-bit RISC-V Qemu Virt hardware environment
with the default 128MB of physical RAM. It starts up a very basic supervisor-level container, and writes some debug out to the
virtual serial port, including logging a hypercall from the supervisor within its container via CPU core 2:

[![Screenshot of SMP diosix in Qemu](https://raw.githubusercontent.com/diodesign/diosix/screenshots/docs/screenshots/riscv64-smp-qemu-boot.png)](https://raw.githubusercontent.com/diodesign/diosix/screenshots/docs/screenshots/riscv64-smp-qemu-boot.png)

The command to build this code for 64-bit RISC-V, once you've installed the necessary toolchain, and run it in Qemu is simply:

```
cargo run --release
```

Press `Ctrl-a` then `c` to escape to the Qemu monitor, then `q` to quit. To build and run diosix within a 32-bit RISC-V environment, try:

```
cargo run --release --target riscv32imac-unknown-none-elf
```

See the [build instructions](BUILDING.md) for step-by-step guides to compiling and running this project.

### Todo

There are a number of goals to hit before this can be considered a useful kernel and operating system.
Here's a non-complete todo list, some of which is partially done:

* Update wiki with relevant documentation
* Introduce unit tests
* Bring-up for RV32
* Bring-up for RV64
* Hyprevisor-kernel level:
    * Physical RAM region management
    * Exception handling
    * Interrupt handling
    * CPU core scheduling
    * Supervisor environment management

### Branches

The `master` branch contains the latest bleeding-edge code that people can work on and develop further; it should at least build, though it may crash. It is not for production use. Releases will be worked on in designated release branches. The `x86` branch holds an early port of the Rust microkernel for Intel-compatible PC systems. The `x86hypervisor` branch holds an early attempt to build hypervisor features into the `x86` branch. You're welcome to update these so they catch up with `master`, however my focus will be on the RISC-V port. Other branches contain experimental work that may not even build.

### Contact

<<<<<<< HEAD
Feel free to [email the project lead](mailto:diodesign@tuta.io), Chris Williams, if you have any questions, want to get involved, have source to contribute, or have [found a security flaw](SECURITY.md). You can also find Chris online in [various forums](https://discordapp.com/invite/rust-lang) as well as [on Twitter](https://twitter.com/diodesign). Ultimately, you can submit pull requests or issues on GitHub. Please observe the project's [code of conduct](CODE_OF_CONDUCT.md) if you wish to participate.
=======
Feel free to [email the project lead](mailto:diodesign@tuta.io), Chris Williams, if you have any questions, want to get involved, have source to contribute, or have [found a security flaw](SECURITY.md). You can also find Chris online in [various forums](https://discordapp.com/invite/rust-lang) as well as [on Twitter](https://twitter.com/diodesign). Ultimately, you can submit pull requests or issues on GitHub. Please bear in mind the project's [code of conduct](CODE_OF_CONDUCT.md) if you wish to participate.
>>>>>>> d9379b8510ed12f27b3e6ae4df16a1d674f1522e

### Copyright, license, and thanks

Copyright &copy; Chris Williams and contributors, 2018-2019. See LICENSE for distribution and use of source code and binaries. A few software components have been imported, modified under license where needed to run within the diosix kernel context, and placed in the `src/contrib` directory. See the included licences for more details on usage. With thanks to:

- src/contrib/hermit-dtb: Copyright &copy; 2018 Colin Finck, RWTH Aachen University.
- src/contrib/lazy-static.rs: Copyright 2016 lazy-static.rs Developers. Copyright &copy; 2010 The Rust Project Developers.
- src/contrib/hashmap_core: Copyright &copy; 2016 The Rust Project Developers.
- src/contrib/spin-rs: Copyright &copy; 2014 Mathijs van de Nes.
- src/contrib/spin-rs/src/atomic.rs: Reimplements Rust's MIT-licensed [core::sync::atomic](https://github.com/rust-lang/rust/blob/master/src/libcore/sync/atomic.rs) API. Original implementation: Copyright &copy; The Rust Project Developers.

And thanks to [David Craven](https://github.com/dvc94ch), [Alex Bradbury](https://github.com/asb), [Vadim Kaushan](https://github.com/Disasm), and everyone else who brought Rust, LLVM, and RISC-V together; the RISC-V world for designing the CPU cores and system-on-chips in the first place; [Michael Clark](https://github.com/michaeljclark) and everyone else who worked on [Qemu](https://github.com/riscv/riscv-qemu) and other RISC-V emulators; Philipp Oppermann for his guide to writing [kernel-level Rust code](https://os.phil-opp.com/); and to the OSdev community for its [notes and documentation](http://wiki.osdev.org/Main_Page).
