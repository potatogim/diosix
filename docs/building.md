## Building and running the hypervisor

Once you have installed a [RISC-V Binutils and Rust toolchain](toolchain.md), built a boot capsule [kernel and filesystem](buildroot.md), and compiled a RISC-V-capable version of [Qemu](qemu.md), the remaining steps to run the Diosix hypervisor are straightforward. This is deliberately so that once all the various support components are in place, the hypervisor can be built, run, and tested with single commands to make development as smooth as possible.

These instructions assume you know your way around a Linux or Unix-like system, are comfortable using your system's command-line interface, and are using a [Debian](https://www.debian.org/)-like GNU/Linux operating system. This guide also assumes you have followed the aforementioned processes to ensure you have a toolchain, boot capsule kernel, and Qemu build in place. By now you should have Git and Cargo installed.

## Table of contents

1. [Getting started](#start)
1. [Building the hypervisor](#build)
1. [Common errors](#errors)
1. [Running the hypervisor, including tests](#run)

### Getting started <a name="start"></a>

First, open a terminal, and fetch the latest Diosix source code, and enter its directory. As is the case throughout this documentation, these instructions will use `src` within your home directory to organize your projects:

```
mkdir -p $HOME/src
cd $HOME/src
git clone --recurse-submodules https://github.com/diodesign/diosix.git
cd diosix
```

### Building the hypervisor <a name="build"></a>

To build the hypervisor for a particular CPU architecture, use `cargo build`, with `<target>` specifying the architecture you wish to support:

```
cargo build --target <target>
```

This not only compiles the hypervisor, it also links the boot capsule kernel, which should contain an initial filesystem, to form the single executable `target/<target>/release/hypervisor`. If a boot capsule kernel cannot be found, an error will be raised. If no `<target>` is supplied on the `cargo` command line, the default, `riscv64gc-unknown-none-elf`, is used. Essentially, this command generates a build of the hypervisor that can bring up systems, physical or emulated, that use the chosen supported CPU architecture.

Below is a list of supported targets, known as target triples in Rust jargon, and a brief description of the CPU architectures they support:

| Target                         | Description                                 |
|:-------------------------------|:--------------------------------------------|
| `riscv32imac-unknown-none-elf` | Basic 32-bit RISC-V cores (RV32IMAC)        |
| `riscv64imac-unknown-none-elf` | Basic 64-bit RISC-V cores (RV64IMAC)        |
| `riscv64gc-unknown-none-elf`   | Fully featured 64-bit RISC-V cores (RV64GC) |


Use `cargo clean` to delete hypervisor builds, and their intermediate files, while leaving the source code untouched, so that the subsequent build occurs afresh. This command should not normally be necessary and is mentioned here for completeness. If a build unexpectedly fails, trying cleaning it out, and starting again with `cargo clean` followed by the desired `cargo build` command.

### 'Expected boot capsule supervisor ... can't find it' <a name="errors"></a>

If you encounter this error after running `cargo build`, the Diosix build system could not find a guest kernel and filesystem binary in its `boot/binaries` directory to boot.

Follow the instructions to build a Linux guest [kernel and filesystem](buildroot.md), or use a [prebuilt](https://github.com/diodesign/diosix/tree/boot-binaries/boot/binaries) kernel and filesystem. Ensure the combined kernel and filesystem binary is stored at `boot/binaries/<arch>/supervisor` where `<arch>` is the architecture targeted in this build, such as `riscv32imac`, `riscv64imac`, or `riscv64gc`.

For example, if you are missing `boot/binaries/riscv64gc/supervisor`, run these commands:

```
mkdir -p boot/binaries/riscv64gc
wget -O boot/binaries/riscv64gc/supervisor https://github.com/diodesign/diosix/raw/boot-binaries/boot/binaries/riscv64gc/supervisor
```

Then re-run `cargo build`. Note: these prebuilt kernel and filesystem binaries are for testing purposes only. They are not frequently updated. It is highly recommended you follow the instructions to build fresh kernel and filesystem binaries.

### Running the hypervisor, including tests <a name="run"></a>

To go straight to running the hypervisor within the Qemu emulator, use `cargo run` with a given `<target>`:

```
cargo run --target <target>
```

This will automatically build the hypervisor, as described above, if one has not been compiled yet. The hypervisor will run within a Qemu Virt-type system with 512MiB of RAM and four CPU cores, with the terminal connected to the emulated hardware's serial port for debugging and communication. Press `control-a` followed by `c` to open the Qemu command console, and then type `q` and hit `enter` to end the emulation. See Diosix's [Qemu documentation](qemu.md) for more information on using the emulator.

Finally, to run Diosix's built-in tests, using Qemu, use, with `<target>` specifying the CPU architecture:

```
cargo test --target <target>
```

This will terminate silently with no error, and an exit code of 0, if all tests pass, or a failure code if a test fails. These automated tests are in their infancy; any contributed tests will be most welcome.
