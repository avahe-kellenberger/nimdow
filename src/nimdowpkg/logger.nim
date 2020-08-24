import
  os,
  logging,
  strutils,
  times

var logger: RollingFileLogger

template log*(message: string, level: logging.Level = lvlInfo) =
  if logger == nil:
    try:
      logger = newRollingFileLogger(getHomeDir() & ".nimdow.log", fmAppend)
    except:
      let err = getCurrentExceptionMsg()
      echo "Failed to open log file for logging:"
      echo err

  if logger != nil:
    const module = instantiationInfo().filename[0 .. ^5]
    let line = "[$# $#][$#]: $#" % [getDateStr(), getClockStr(), module, message]
    logger.log(level, line)
    logger.file.flushFile()
    echo line

