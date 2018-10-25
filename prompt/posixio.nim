import posix

const
  BACKSPACE* = 127
  UP* = 65
  LEFT* = 68
  DOWN* = 66
  RIGHT* = 67

var
  oldt: Termios
  rawModeEnabled = false

proc enableRawMode*() =
  if rawModeEnabled: return
  discard tcgetattr(STDIN_FILENO, oldt.addr)
  var newt = oldt
  newt.c_iflag = newt.c_iflag and not(BRKINT or ICRNL or INPCK or ISTRIP or IXON)
  newt.c_oflag = newt.c_oflag and not(OPOST)
  newt.c_cflag = newt.c_cflag or CS8
  newt.c_lflag = newt.c_lflag and not(ECHO or ICANON or IEXTEN or ISIG)
  newt.c_cc[VMIN] = 1.cuchar
  newt.c_cc[VTIME] = 0.cuchar
  discard tcsetattr(STDIN_FILENO, TCSANOW, newt.addr)
  rawModeEnabled = true

proc disableRawMode*() {.noconv.} =
  if not rawModeEnabled: return
  discard tcsetattr(STDIN_FILENO, TCSANOW, oldt.addr)
  rawModeEnabled = false

addQuitProc disableRawMode

proc readRune(): Rune =
  var utf8string = newStringOfCap(4)

  while true:
    var
      c: char
      nread: csize

    # Continue reading if interrupted by signal.
    while true:
      nread = read(STDIN_FILENO, c.addr, 1)
      if not (nread == -1 and errno == EINTR): break

    if nread <= 0: return Rune(0)
    if c <= char(0x7F): #short circuit ASCII
      return Rune(c)
    elif utf8string.len < 4:
      utf8string.add(c)
      if validateUtf8(utf8string) == -1:
        return runeAt(utf8string, 0)
    else:
      # this shouldn't happen: got four bytes but no UTF-8 character
      utf8string.setLen(0)

proc readEscapeChar(): char =
  var r = read(STDIN_FILENO, result.addr, 1)
  if r == -1: raiseOSError(osLastError())

proc inputAvailable(): bool =
  var s: TFdSet
  FD_ZERO(s)
  FD_SET(STDIN_FILENO, s)
  var timeout: Timeval
  timeout.tv_sec = 0.Time
  timeout.tv_usec = 25
  let res = posix.select(1, s.addr, nil, nil, timeout.addr)
  if res == -1:
    raiseOsError(osLastError())
  return res == 1

proc getCursorPos*(): tuple[col, row: int] =
  var
    i = 0
    buf: array[32, char]
    col, row: int
    c, r = ""
    str = "\e[6n"

  discard write(1, addr(str[0]), 4)
  while i < buf.len:
    if read(STDIN_FILENO, addr(buf[i]), 1) != 1: break
    if buf[i] == 'R': break
    inc(i)

  if buf[0] != '\e' or buf[1] != '[': return (-1, -1)
  i = 2
  while true:
    if buf[i] == ';':
      col = parseInt(c)
      inc(i)
      break
    c.add(buf[i])
    inc(i)

  while true:
    if not(buf[i] in {'0' .. '9'}):
      row = parseInt(r)
      return (col, row)
    r.add(buf[i])
    inc(i)

proc ignoreNextChar() =
  if inputAvailable():
    discard readEscapeChar()

template handleKeyPress() =
  try:
    enableRawMode()
    var r: Rune
    try:
      r = readRune()
    except:
      p.writeLine(getCurrentExceptionMsg())
      sleep 100
      continue

    # p.writeLine("KEY1: " & $(r.int))

    case r.int:
    of ENTER, CTRL_J:
      handleEnter()
    of BACKSPACE:
      p.backspace()
    of CTRL_H:
      p.backspaceWord()
    of CTRL_A:
      p.home()
    of CTRL_B:
      p.cursorLeft()
    of CTRL_C:
      discard posix.`raise`(SIGINT)
    of CTRL_D:
      p.deleteKey()
    of CTRL_E:
      p.endKey()
    of CTRL_F:
      p.cursorRight()
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
      if not inputAvailable():
        p.escapeKey()
        continue
      var k2, k3: char
      k2 = readEscapeChar()
      # p.writeLine("KEY2:" & $k2)
      if k2 == 'f':
        # alt-f
        p.skipWordRight()
        continue
      elif k2 == 'b':
        p.skipWordLeft()
        continue
      if not inputAvailable(): continue
      k3 = readEscapeChar()
      # p.writeLine("KEY3: " & $k3)
      if k2 == '[':
        if k3 >= '0' and k3 <= '9':
          case k3
          of '1':
            # alt combination
            # 3 characters to consume
            var code = ""
            for i in 0..2: code.add(readEscapeChar())
            case code
            of ";3A":
              # alt-up
              p.pageUp()
            of ";3B":
              # alt-down
              p.pageDown()
            of ";3C":
              # alt-right
              p.skipWordRight()
            of ";3D":
              # alt-left
              p.skipWordLeft()
            of ";5D":
              # ctrl-left
              p.skipWordLeft()
            of ";5C":
              # ctrl-right
              p.skipWordRight()
            else:
              # p.writeLine("unhandled code: " & code)
              discard
          of '3':
            # delete key
            if not inputAvailable():
              continue
            let c2 = int(readEscapeChar())
            if c2 == 59:
              # ctrl-delete
              p.deleteWord()
              ignoreNextChar()
              ignoreNextChar()
            elif c2 == 126:
              p.deleteKey()
          of '5':
            # page up
            p.pageUp()
            ignoreNextChar()
          of '6':
            # page down
            p.pageDown()
            ignoreNextChar()
          else:
            discard
        else:
          case k3
          of 'A':
            # up arrow
            p.verticalArrowKey(-1)
          of 'B':
            # down arrow
            p.verticalArrowKey(1)
          of 'H':
            # home button
            p.home()
          of 'F':
            # end button
            p.endKey()
          of 'C':
            p.cursorRight()
          of 'D':
            p.cursorLeft()
          else:
            discard
      elif k2 == 'o':
        discard
    else:
      p.insert(r)

  finally:
    disableRawMode()
