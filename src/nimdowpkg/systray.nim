import
  x11 / [x],
  client

# TODO: Put this in the config file
const iconSpacing: int = 4

type Systray* = ref object
  window*: Window
  icons: seq[Client]

proc getWidth*(this: Systray): int =
  for icon in this.icons:
    result += icon.width.int + iconSpacing
  result = max(1, result + iconSpacing)

proc windowToIcon*(this: Systray, window: Window): Client =
  let index = this.icons.find(window)
  if index != -1:
    return this.icons[index]

proc removeIcon*(this: Systray, icon: Client) =
  if icon == nil:
    return
  let index = this.icons.find(client)
  if index != -1:
    this.icons.delete(index)

