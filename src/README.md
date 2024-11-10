# Quasar

Quasar is a microkernel for 32 & 64-bit ARM, Intel/AMD, MIPS, OpenRISC, PowerPC, RISC-V, & SPARC CPUs. It provides FIFO pre-emptive multiprocessing, a freelist based PMM, and a virtual memory system. It's SMP-aware, and is a soft RTOS with one core, but can scale to arbitrarily many cores.

### Building

Run `make help` to get instructions for how to build and test. The project structure is relatively simple--each architecture gets a subdirectory of `arch/` called `arch/ARCH`, which contains a folder `src/` (which is symlinked as `src/arch/`) and scripts `build.sh`, `debug.sh`, & `run.sh` for running qemu, running qemu in debug, and building a `.efi` (respectively).
