const
  MEMINFO_PATH: string = "/proc/meminfo"
  GIB_DIVISOR: float = 1024.0 * 1024.0
  MIB_DIVISOR: int = 1024

proc getMemInfo(key: string): int =
  for line in readFile(MEMINFO_PATH).splitLines():
    let parts = line.split(":")
    if parts.len == 2 and parts[0].strip() == key:
      return parts[1].strip().split()[0].parseInt()
  return 0

proc getMemory(): string =
  if not fileExists(MEMINFO_PATH):
    return "Memory info not available"

  let
    iMemTotal = getMemInfo("MemTotal")
    iMemFree = getMemInfo("MemFree")
    iMemAvailable = getMemInfo("MemAvailable")
    iBuffers = getMemInfo("Buffers")
    iCached = getMemInfo("Cached")
    iShmem = getMemInfo("Shmem")
    iSReclaimable = getMemInfo("SReclaimable")

    # Htop method of calculating used memory
    iUsedMem = iMemTotal - (iMemFree + iBuffers + iCached) + (iShmem - iSReclaimable)

    # Standard method, free, btop pytop ect..
    # iUsedMem = iMemTotal - iMemAvailable

  if iUsedMem >= 1048576: # Check to see if used mem is 1GB or greater
    result = fmt"{MEMORY_ICON} {iUsedMem.float / GIB_DIVISOR:0.2f} GiB"
  else:
    result = fmt"{MEMORY_ICON} {iUsedMem div MIB_DIVISOR} MiB"

