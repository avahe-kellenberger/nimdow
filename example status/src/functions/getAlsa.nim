proc getAlsa(): string = 
  let sAlsaVol = execProcess("amixer get Master")
  if sAlsaVol.contains("off"):
    return MUTE_ICON & sAlsaVol[succ(sAlsaVol.find("["))..pred(sAlsaVol.find("]"))]
  else:
    return VOL_ICON & sAlsaVol[succ(sAlsaVol.find("["))..pred(sAlsaVol.find("]"))]
   
