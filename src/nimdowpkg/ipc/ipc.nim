import
  os,
  net,
  tables,
  re,
  options,
  strformat,
  strutils

import
  ../wmcommands,
  ../config/configloader

const ipcPrefix* = "nimdow-ipc"

var channel*: Channel[WMCommand]

proc getSocketDir*(): string
proc findSocket*(): string

let
  pid = getCurrentProcessId()

proc getSocketDir*(): string =
  let runtimeDir = getEnv("XDG_RUNTIME_DIR")
  return fmt"{runtimeDir}/nimdow"

proc findSocket*(): string =
  let socketDir = getSocketDir()
  for kind, filePath in walkDir(socketDir):
    if kind == pcFile and filePath.match(re".*?\/ipc-socket\.[\d]*+"):
      return filePath

proc deleteOldIPCSockets() =
  let socketDir = getSocketDir()
  for kind, filePath in walkDir(socketDir):
    if kind == pcFile:
      removeFile(filePath)

proc parseCommand(str: string): Option[WMCommand] =
  try:
    let split = str.split()
    let command = split[1]
    return some(parseEnum[WMCommand](command))
  except:
    return none[WMCommand]()

proc listen*() {.thread.} =
  channel.open()
  let socketDir = getSocketDir()
  let socketLoc = fmt"{socketDir}/ipc-socket.{pid}"
  try:
    if not dirExists(socketDir):
      createDir(socketDir)
    else:
      deleteOldIPCSockets()

    echo fmt"Created ipc socket: {socketLoc}"

    let socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    socket.bindUnix(socketLoc)
    socket.listen()

    while true:
      var client: Socket
      socket.accept(client)
      let received = client.recv(MaxLineLength)
      if received.startsWith(ipcPrefix):
        let commandOpt = parseCommand(received)
        if commandOpt.isSome:
          let command = commandOpt.get
          echo "Received command: " & $commandOpt.get
          channel.send(command)
      client.close()

  except Exception as e:
    echo "ipc failure!\n" & e.msg

  let deletedSocket = tryRemoveFile(socketLoc)
  if not deletedSocket:
    echo fmt"Failed to delete ipc socket at {socketLoc}"

