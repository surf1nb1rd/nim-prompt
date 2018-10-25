import winlean

const
  utf8Table = [
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0
  ]

const
  SPCH = 224
  UP = 72
  LEFT = 75
  DOWN = 80
  RIGHT = 77
  PAGEUP = 73
  PAGEDOWN = 81
  DEL = 83
  HOME = 71
  END = 79
  ALT_UP = 152
  ALT_DOWN = 160
  ALT_LEFT = 155
  ALT_RIGHT = 157
  CTRL_LEFT = 115
  CTRL_RIGHT = 116
  CTRL_DEL = 147

proc getChar*(): char {.importc: "getch", header: "<conio.h>".}
proc kbhit*(): int {.header: "<conio.h>", importc: "kbhit".}

template handleKeyPress() =
  var
    ch = getChar()
    uch = Rune(ch)

  # p.writeLine("KEY: " & $ch.int)

  case ch.int
  of 0:
    if kbhit() == 0: continue
    var c = getChar()
    # p.writeLine("NEXT: " & $c.int)
    case c.int
    of ALT_RIGHT:
      p.skipWordRight()
    of ALT_LEFT:
      p.skipWordLeft()
    of ALT_UP:
      p.pageUp()
    of ALT_DOWN:
      p.pageDown()
    else:
      discard
  of ENTER, CTRL_J:
    handleEnter()
  of CTRL_H:
    p.backspace()
  of CTRL_A:
    p.home()
  of CTRL_B:
    p.cursorLeft()
  of CTRL_C:
    quit 1
  of CTRL_D:
    p.deleteKey()
  of CTRL_E:
    p.endKey()
  of CTRL_K:
    discard
  of CTRL_L:
    p.clearScreen()
  of CTRL_P:
    p.verticalArrowKey(-1)
  of CTRL_N:
    p.verticalArrowKey(1)
  of CTRL_R:
    p.isearchBackwards()
  of CTRL_S:
    p.isearchForward()
  of CTRL_T:
    discard
  of CTRL_U:
    p.printHistory()
  of CTRL_W:
    discard
  of TAB:
    p.tab()
  of ESC:
    p.escapeKey()
  of SPCH:
    if kbhit() == 0: continue
    var c = getChar()
    # p.writeLine("C1: " & $(c.int))
    case c.int
    of UP:
      p.verticalArrowKey(-1)
    of DOWN:
      p.verticalArrowKey(1)
    of LEFT:
      p.cursorLeft()
    of RIGHT:
      p.cursorRight()
    of HOME:
      p.home()
    of END:
      p.endKey()
    of DEL:
      p.deleteKey()
    of PAGEUP:
      p.pageUp()
    of PAGEDOWN:
      p.pageDown()
    of CTRL_RIGHT:
      p.skipWordRight()
    of CTRL_LEFT:
      p.skipWordLeft()
    of CTRL_DEL:
      p.deleteWord()
    else:
      discard
  else:
    var buf = ""
    case utf8Table[ch.int]
    of 2:
      buf.add($ch)
      for _ in 1 ..< 2:
        var c  = getChar()
        buf.add($c)
      p.insert(runeAt(buf, 0))
    of 3:
      buf.add($ch)
      for _ in 1 ..< 3:
        var c  = getChar()
        buf.add($c)
      p.insert(runeAt(buf, 0))
    of 4:
      buf.add($ch)
      for _ in 1 ..< 4:
        var c  = getChar()
        buf.add($c)
      p.insert(runeAt(buf, 0))
    else:
      p.insert(uch)
