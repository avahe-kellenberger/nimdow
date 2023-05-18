import
  os,
  logging,
  strutils,
  times

export logging

var
  logger: RollingFileLogger
  enabled*: bool = false

template log*(message: string, level: Level = lvlInfo) =
  const module = instantiationInfo().filename[0 .. ^5]
  let line = "[$# $#][$#]: $#" % [getDateStr(), getClockStr(), module, message]
  echo "$# $#" % [LevelNames[level], line]

  if enabled:
    if logger == nil:
      try:
        logger = newRollingFileLogger(getHomeDir() & ".nimdow.log", fmAppend)
      except CatchableError:
        let err = getCurrentExceptionMsg()
        echo "Failed to open log file for logging:"
        echo err

    if logger != nil:
      logger.log(level, line)
      logger.file.flushFile()

