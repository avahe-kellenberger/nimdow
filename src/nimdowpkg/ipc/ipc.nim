import
  os,
  net,
  re,
  strformat

import ../logger

const ipcPrefix* = "nimdow-ipc"

let
  runtimeDir = if existsEnv("XDG_RUNTIME_DIR"): getEnv("XDG_RUNTIME_DIR") else: "/tmp"
  socketDir = fmt"{runtimeDir}/nimdow"
  pid = getCurrentProcessId()
  socketLoc* = fmt"{socketDir}/ipc-socket.{pid}"

proc findSocketPath*(): string =
  for kind, filePath in walkDir(socketDir):
    if kind == pcFile and filePath.match(re".*?\/ipc-socket\.[\d]*+"):
      return filePath

proc deleteOldIPCSockets() =
  for kind, filePath in walkDir(socketDir):
    if kind == pcFile:
      discard tryRemoveFile(filePath)

proc initIPCSocket*(): Socket =
  ## Creates and initializes a socket at socketLoc.
  ## This proc can raise an Exception.
  if not dirExists(socketDir):
    createDir(socketDir)
  else:
    deleteOldIPCSockets()

  result = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  result.bindUnix(socketLoc)
  result.listen()
  log fmt"Created ipc socket: {socketLoc}"

