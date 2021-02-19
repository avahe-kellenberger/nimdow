# Socket loc
`$XDG_RUNTIME_DIR/nimdow/ipc-socket.%p` where %p is the PID of nimdow.

# See https://github.com/i3/i3/blob/next/i3-msg/main.c#L247

## Sending messages

Each time nimdow is invoked with args,
we connect to the socket,
send the message,
and disconnect.

## On Startup

When Nimdow is started,
create the socket.
If it exists,
delete it first?

Delete it upon exit.

