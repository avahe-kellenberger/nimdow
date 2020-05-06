import
  x11 / [x, xlib]

converter boolToTBool(x: bool): TBool = TBool(x)

type
  XAtomID* = enum
    NetWMState, NetWMFullScreen

proc createXAtoms*(display: PDisplay): array[2, TAtom] =
  ## Creates an array of all atoms in order of the defined enum states in `XAtomID`
  ##
  ## ** Examples:**
  ##
  ##  .. code-block::
  ##    let atoms = createAtoms(display)
  ##    echo atoms[ord(XAtomID.NetWMFullScreen)]
  [
    XInternAtom(display, "_NET_WM_STATE", false),
    XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", false)
  ]

