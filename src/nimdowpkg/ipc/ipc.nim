import
  os,
  net,
  re,
  strformat

const ipcPrefix* = "nimdow-ipc"

var ipcChannel*: Channel[string]

proc getSocketDir*(): string
proc findSocketPath*(): string

proc getSocketDir*(): string =
  let runtimeDir = getEnv("XDG_RUNTIME_DIR")
  return fmt"{runtimeDir}/nimdow"

proc findSocketPath*(): string =
  let socketDir = getSocketDir()
  for kind, filePath in walkDir(socketDir):
    if kind == pcFile and filePath.match(re".*?\/ipc-socket\.[\d]*+"):
      return filePath

proc deleteOldIPCSockets() =
  let socketDir = getSocketDir()
  for kind, filePath in walkDir(socketDir):
    if kind == pcFile:
      removeFile(filePath)

proc listen*() {.thread.} =
  # TODO: Is there a way I can use the logger?
  # Maybe need another channel...

  ipcChannel.open()

  let
    socketDir = getSocketDir()
    pid = getCurrentProcessId()
    socketLoc = fmt"{socketDir}/ipc-socket.{pid}"

  try:
    if not dirExists(socketDir):
      createDir(socketDir)
    else:
      deleteOldIPCSockets()

    let socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
    socket.bindUnix(socketLoc)
    socket.listen()

    echo fmt"Created ipc socket: {socketLoc}"

    while true:
      # TODO: Keep the socket open.
      # We should allow multiple connections (use case: Keybindings + another ipc program)
      var client: Socket
      socket.accept(client)
      let received = client.recv(MaxLineLength)
      ipcChannel.send(received)
      client.close()

  except Exception as e:
    echo "ipc failure!\n" & e.msg

  let deletedSocket = tryRemoveFile(socketLoc)
  if not deletedSocket:
    echo fmt"Failed to delete ipc socket at {socketLoc}"

