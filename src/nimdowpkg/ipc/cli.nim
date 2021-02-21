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

const version* = "v0.7.17"

proc handleWMCommand(command: WMCommand, option: string = ""): bool =
  ## Returns if the command was sent.
  var socket: Socket
  try:
    socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    let socketLoc = findSocketPath()
    socket.connectUnix(socketLoc)
  except Exception:
    log "Failed to connect to live socket", lvlError
    return false

  let message =
    if option.len > 0:
      fmt"{ipcPrefix} {command} {option}"
    else:
      fmt"{ipcPrefix} {command}"

  if not socket.trySend(message):
    log "Failed to send message to socket", lvlError
    return false

  return true

proc handleSpecialCommand(key, value: string): bool =
  ## Returns if Nimdow execution should continue.
  case key:
    of "v", "version":
      echo "Nimdow ", version
    of "c", "config":
      configloader.configLoc = value
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
  p.next()

  case p.kind:
    of cmdEnd: return true
    of cmdShortOption, cmdLongOption, cmdArgument:
      let option = p.key.replace("-")
      try:
        let command = parseEnum[WMCommand](option)
        discard handleWMCommand(command, p.val)
      except Exception:
        return handleSpecialCommand(option, p.val)

