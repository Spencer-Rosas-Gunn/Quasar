const uefi = @import("std").os.uefi;

pub var con_out: *uefi.protocol.SimpleTextOutput = undefined;
pub var boot_services: *uefi.tables.BootServices = undefined;