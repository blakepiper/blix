{ ... }:

{
  # A wedged display leaves no way to reach a terminal, and cutting the power
  # loses the journal that would explain it. Magic SysRq keeps a path out:
  # Alt+SysRq+R E I S U B releases the keyboard, ends processes, flushes the
  # filesystems, and reboots cleanly instead.
  boot.kernel.sysctl."kernel.sysrq" = 1;
}
