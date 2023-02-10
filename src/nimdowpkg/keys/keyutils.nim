import
  x11 / [x, xlib, keysym],
  tables

converter toInt(x: KeyCode): int = x.int

## A table of key modifier names to their respective masks.
const ModifierTable* = {
  "control": ControlMask,
  "shift": ShiftMask,
  "alt": Mod1Mask,
  "super": Mod4Mask,
  "caps lock": LockMask,
  "mod1": Mod1Mask,
  "mod2": Mod2Mask,
  "mod3": Mod3Mask,
  "mod4": Mod4Mask,
  "mod5": Mod5Mask,
}.toTable()

var numlockmask*: cuint = 0

proc cleanMask*(mask: int): int =
  ## Creates a uniform mask that can be used with
  ## masks defined in x11/x.nim and TXKeyEvent.state
  mask and (not (numlockmask.int or LockMask)) and
  (ShiftMask or ControlMask or Mod1Mask or Mod2Mask or Mod3Mask or Mod4Mask or Mod5Mask)

func toKeycode*(key: string, display: PDisplay): int =
  XKeysymToKeycode(display, XStringToKeysym(key))

func toString*(key: KeyCode, display: PDisplay): string =
  let keySym = XKeycodeToKeysym(display, key, cint(0))
  return $XKeysymToString(keySym)

proc updateNumlockMask*(display: PDisplay) =
  numlockmask = 0
  let pModmap = XGetModifierMapping(display)
  let pModifierMap = cast[ptr UncheckedArray[cuchar]](pModmap[].modifiermap)
  let maxKeyPerMod = pModmap[].max_keypermod
  for i in 0..<8:
    for j in 0..maxKeyPerMod:
      let modifier = pModifierMap[][i * maxKeyPerMod + j]
      if modifier == XKeysymToKeycode(display, XK_Num_Lock):
        numlockmask = 1.cuint shl i
  discard XFreeModifiermap(pModmap)

