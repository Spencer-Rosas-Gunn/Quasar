# Quasar

Quasar is a microkernel-style toolchain for embedded systems programming. It provides memory virtualization and protection, task management facilities, permissions managemnet facilities, page management, inter-process communication via shared memory, and message-passing interfaces between processes. Quasar is not a full-blown microkernel, as it doesn't provide an IVT or task-switching mechanism, though a per-core scheduling mechanism is provided. Quasar uses UEFI, and through UEFI the FAT32 & IPv4/IPv6 protocols can be used for filesystem and networking facilities. All quasar utilities are hard realtime and therefore have worst-case CPU cycle counts.

### Building

Run `make help` to get instructions for how to build and test. The project structure is relatively simple--each architecture gets a subdirectory of `arch/` called `arch/ARCH`, which contains a folder `src/` (which is symlinked as `src/arch/`) and scripts `build.sh`, `debug.sh`, & `run.sh` for running qemu, running qemu in debug, and building a `.efi` (respectively). By default, ARCH is set to x86_64 which is, currently, the only supported ISA.
