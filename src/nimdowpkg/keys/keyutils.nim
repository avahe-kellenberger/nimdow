import
  x11 / x

func cleanMask*(mask: int): int = 
  ## Creates a uniform mask that can be used with
  ## masks defined in x11/x.nim and TXKeyEvent.state
  mask and (not LockMask) and
  (ShiftMask or ControlMask or Mod1Mask or Mod2Mask or Mod3Mask or Mod4Mask or Mod5Mask)


