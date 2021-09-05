import
  os,
  net,
  strutils,
  strformat,
  parseopt

import
  ipc,
  ../config/configloader,
  ../wmcommands,
  ../logger

const version* = "v0.7.28"
const commit* = getEnv("LATEST_COMMIT")

proc handleWMCommand(commandStr: string): bool =
  ## Returns if the command was sent.
  var socket: Socket
  try:
    socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    let socketLoc = findSocketPath()
    socket.connectUnix(socketLoc)
  except Exception:
    log "Failed to connect to live socket", lvlError
    return false

  let message = fmt"{ipcPrefix} {commandStr}"
  let success = socket.trySend(message)
  if not success:
    log "Failed to send message to socket", lvlError

  socket.close()
  return success

proc handleSpecialCommand(strArr: seq[string]): bool =
  ## Returns if Nimdow execution should continue.
  if strArr.len < 1:
    return true

  case strArr[0]:
    of "v", "version":
      if commit.len > 0:
        echo fmt"Nimdow {version} - Commit {commit}"
      else:
        echo fmt"Nimdow {version}"
    of "c", "config":
      configloader.configLoc = strArr[1]
      return true
    else:
      log "Unknown command", lvlError
      discard

proc handleCommandLineParams*(): bool =
  ## Executes actions based on cli params.
  ## Returns if Nimdow is intended to be ran normally.
  when not declared(commandLineParams):
    return true

  var p = initOptParser()
  var strArr: seq[string]

  while true:
    p.next()

    case p.kind:
      of cmdEnd: break
      of cmdShortOption, cmdLongOption, cmdArgument:
        let option = p.key.replace("-")
        strArr.add option
        if p.val.len > 0:
          strArr.add p.val

  let commandStr = strArr.join(" ")
  try:
    # Ensure the first param is a valid command.
    discard parseEnum[WMCommand](strArr[0])
    discard handleWMCommand(commandStr)
    return false
  except Exception:
    return handleSpecialCommand(strArr)

