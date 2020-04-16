import x11/xlib, x11/x

converter toCint*(x: TKeyCode): cint = x.cint
converter int32toCUint*(x: int32): cuint = x.cuint
converter toTBool*(x: bool): TBool = x.TBool
converter toBool*(x: TBool): bool = x.bool

