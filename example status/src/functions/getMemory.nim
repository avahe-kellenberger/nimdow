proc getMemory(): string =
    let
      sMemory = "/proc/meminfo".readLines(3)
      sTotalMem = sMemory[0].split(" ")[^2]
      sAvailableMem = sMemory[2].split(" ")[^2]
      iTotalMem =  sTotalMem.parseInt div 1024
      iAvailableMem = sAvailableMem.parseInt div 1024

    result = MEMORY_ICON & $(iTotalMem - iAvailableMem) & " MiB"
