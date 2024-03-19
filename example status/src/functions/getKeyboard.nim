proc getKeyboard(): string = 
  let sKbmap = execProcess("setxkbmap -query | awk 'NR==3 {print $2}'")
  return KB_ICON & sKbmap




  
