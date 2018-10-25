import os, terminal, termios, unicode, lists, unicodedb/widths, system, strutils
from strutils import parseInt
from sequtils import delete

system.addQuitProc(resetAttributes)

const
  ESC* = 27
  ENTER* = 13
  KEY_NULL* = 0
  CTRL_A* = 1
  CTRL_B* = 2
  CTRL_C* = 3
  CTRL_D* = 4
  CTRL_E* = 5
  CTRL_F* = 6
  CTRL_H* = 8
  TAB* = 9
  CTRL_J* = 10
  CTRL_K* = 11
  CTRL_L* = 12
  CTRL_N* = 14
  CTRL_P* = 16
  CTRL_R* = 18
  CTRL_S* = 19
  CTRL_T* = 20
  CTRL_U* = 21
  CTRL_W* = 23
  CTRL_X* = 24
  CTRL_Y* = 25
  CTRL_Z* = 26

const defaultpromptIndicator = "> "

type
  Visiblity = enum
    Inline,
    Box,
    Hidden

  Size = object
    height, width: int

  TerminalLayout* = object
    widgets: seq[Widget]
    activeWidget: int
    cursorLine: int

  Widget* = ref object of RootObj
    visibility: Visiblity
    size: Size

  StatusBarItem* = tuple[label: string, content: string]

  Prompt* = ref object of Widget
    promptIndicator: string
    line: seq[Rune]
    cursorPos: int
    history: seq[seq[Rune]]
    histIndex: int
    historyPath*: string
    maxHistory*: int
    historyFileLines: int
    autoComplete: AutoCompleteProc
    menu: seq[string]
    menuReplacedChars: int
    activeMenuItem: int
    statusBar: seq[StatusBarItem]
    drawnMenuItems: int
    statusDrawn: bool

  ProgressBar* = ref object of Widget

  AutoCompleteProc = proc(line: seq[Rune], cursorpos: int): seq[string] {.gcsafe.}

proc init*(_: type Prompt,
           promptIndicator = defaultpromptIndicator,
           autoComplete: AutoCompleteProc = nil): Prompt =
  result = Prompt(
    cursorPos: 0,
    line: @[],
    promptIndicator: promptIndicator,
    history: @[],
    histIndex: 0,
    historyFileLines: 0,
    autoComplete: autoComplete,
    menu: @[],
    menuReplacedChars: 0,
    activeMenuItem: 0,
    drawnMenuItems: 0,
    statusBar: @[],
    statusDrawn: false
  )

proc calcWidth(c: Rune): int =
  let r = c.unicodeWidth()
  if r == uwdtWide or r == uwdtFull:
    return 2
  else:
    return 1

proc hidePrompt*(p: Prompt) =
  eraseLine()
  let drawnLines = p.drawnMenuItems + ord(p.statusDrawn)
  if drawnLines > 0:
    cursorDown(drawnLines)
    for i in 0 ..< drawnLines:
     eraseLine()
     cursorUp()

proc showPrompt*(p: Prompt) =
  hideCursor()

  eraseLine()
  stdout.write(p.promptIndicator, $p.line)

  p.drawnMenuItems = p.menu.len
  if p.menu.len > 0:
    let menuOffset = repeat(" ", p.promptIndicator.len + p.cursorPos - p.menuReplacedChars - 1)
    var longestMenuItem = 0
    for item in p.menu:
      if item.len > longestMenuItem:
        longestMenuItem = item.len
    for i in 0 ..< p.menu.len:
      let itemPadding = repeat(" ", longestMenuItem - p.menu[i].len + 1)
      stdout.write "\n\r"
      if i == p.activeMenuItem:
        stdout.styledWrite(menuOffset, bgCyan, fgWhite, " ", p.menu[i], itemPadding, resetStyle)
      else:
        stdout.styledWrite(menuOffset, bgMagenta, fgWhite, " ", p.menu[i], itemPadding, resetStyle)

  p.statusDrawn = p.statusBar.len > 0
  if p.statusDrawn:
    stdout.write "\n\r"
    # let width = terminalWidth()
    # stdout.styledWrite(bgGreen, repeat(" ", width), "\r")
    for item in p.statusBar:
      stdout.styledWrite({styleBright}, fgMagenta, item.label, ": ",
                         {styleBright}, fgWhite, item.content, " ")
    cursorUp()

  if p.drawnMenuItems > 0:
    cursorUp(p.drawnMenuItems)

  setCursorXPos(0)
  var cursorPos = 0
  for i in 0 ..< min(p.line.len, p.cursorPos):
    cursorPos += calcWidth(p.line[i])
  cursorForward(p.promptIndicator.len + cursorPos)
  showCursor()

  stdout.flushFile()

proc redrawPrompt(p: Prompt) =
  hidePrompt(p)
  showPrompt(p)

template writeLine*(p: Prompt, args: varargs[untyped]) =
  p.hidePrompt()
  styledEcho(args)
  p.showPrompt()

proc withOutput*(p: Prompt, outputFunction: proc()) =
  p.hidePrompt()
  outputFunction()
  p.showPrompt()

proc setIndicator*(p: var Prompt, value: string) =
  p.promptIndicator = value
  p.redrawPrompt()

proc setStatusBar*(p: Prompt, statusBar: seq[StatusBarItem]) =
  p.statusBar = statusBar
  p.redrawPrompt()

proc clear*(p: Prompt) =
  p.line.setLen(0)
  p.cursorPos = 0

proc hideMenu(p: Prompt) =
  if p.menu.len > 0:
    p.menu = @[]
    p.activeMenuItem = -1
    p.menuReplacedChars = 0

proc escapeKey(p: Prompt) =
  if p.menu.len > 0:
    p.hideMenu()
  else:
    p.clear()

proc insertCompletion(p: Prompt, completion: string) =
  let runes = toRunes(completion)
  let newCursorPos = p.cursorPos - p.menuReplacedChars + runes.len
  p.line[p.cursorPos - p.menuReplacedChars .. p.cursorPos - 1] = runes
  p.menuReplacedChars = runes.len
  p.cursorPos = newCursorPos

proc moveInMenu(p: Prompt, steps: int) =
  p.activeMenuItem = (p.menu.len + p.activeMenuItem + steps) mod p.menu.len
  p.insertCompletion(p.menu[p.activeMenuItem])

proc longestCommonPrefix(strings: seq[string]): int =
  result = strings[0].len
  for i in 1 ..< strings.len:
    result = min(result, strings[i].len)
    for j in 0 ..< result:
      if strings[0][j] != strings[i][j]:
        result = j
        break

proc insertSureCharacters(p: Prompt, completion: string) =
  let completionRunes = toRunes(completion)
  for i in countdown(completionRunes.len - 1, 0):
    let lineLast = p.cursorPos - 1
    if lineLast < i: continue
    if completionRunes[0 .. i] == p.line[lineLast - i .. lineLast]:
      for j in i + 1 ..< completionRunes.len:
        let inserted = completionRunes[j]
        if p.cursorPos < p.line.len:
          if p.line[p.cursorPos] in [Rune(' '), Rune('\t')]:
            p.line.insert(inserted, p.cursorPos)
          else:
            p.line[p.cursorPos] = inserted
        else:
          p.line.add(inserted)
        inc p.cursorPos
      return

proc tab*(p: Prompt) =
  if p.menu.len > 0:
    p.moveInMenu(1)
  else:
    if p.autoComplete == nil: return
    let completions = p.autoComplete(p.line, p.cursorPos)
    if completions.len == 1:
      p.insertSureCharacters(completions[0])
    elif completions.len > 0:
      let commonPrefix = longestCommonPrefix(completions)
      p.insertSureCharacters(completions[0][0..commonPrefix-1])
      p.menu = completions
      p.activeMenuItem = -1
      p.menuReplacedChars = commonPrefix

proc clearScreen(p: Prompt) =
  hideCursor()
  eraseScreen()
  setCursorpos(0, 0)
  showCursor()

proc printHistory(p: Prompt) =
  var res = "-- history ------\n"
  for i in 0 ..< p.history.len:
    if i == p.histIndex:
      res.add(" *")
    else:
      res.add("  ")
    res.add($p.history[i])
    res.add("\n")
  res.add("-----------------")
  p.writeLine(res)

proc insert(p: Prompt, c: Rune) =
  var
    l = p.line[0 ..< p.cursorPos]
    r = p.line[p.cursorPos ..< p.line.len]

  l.add(c)
  l.add(r)
  p.line = l
  inc(p.cursorPos)

  if p.menu.len > 0:
    if p.activeMenuItem != -1:
      p.hideMenu()
    else:
      var newMenu = newSeq[string](0)
      for item in p.menu:
        let i = p.menuReplacedChars
        if i < item.len and Rune(item[i]) == c:
          newMenu.add item

      if newMenu.len > 0:
        p.menu = newMenu
        inc p.menuReplacedChars
      else:
        p.hideMenu()

proc deleteAt(p: Prompt, pos: int): bool =
  if pos >= 0 and pos < p.line.len:
    var c = p.line[pos]
    p.line.delete(pos, pos)
    return true
  return false

proc backspace(p: Prompt) =
  p.hideMenu()
  if p.deleteAt(p.cursorPos - 1):
    dec(p.cursorPos)

proc deleteKey(p: Prompt) =
  p.hideMenu()
  discard p.deleteAt(p.cursorPos)

proc cursorRight(p: Prompt) =
  p.hideMenu()
  if p.cursorPos < p.line.len:
    inc(p.cursorPos)

proc cursorLeft(p: Prompt) =
  p.hideMenu()
  if p.cursorPos > 0:
    dec(p.cursorPos)

proc enter(p: Prompt): bool =
  if p.menu.len > 0 and p.activeMenuItem != -1:
    p.hideMenu()
    return false
  else:
    p.redrawPrompt()
    return true

proc moveInHistory(p: Prompt, steps: int) =
  if p.history.len == 0:
    return
  if p.histIndex == p.history.len and p.line.len > 0:
    p.history.add(p.line)
  p.histIndex = clamp(p.histIndex + steps, 0, p.history.len)
  if p.histIndex == p.history.len:
    p.line = @[]
  else:
    p.line = p.history[p.histIndex]
  p.cursorPos = p.line.len

proc verticalArrowKey(p: Prompt, step: int) =
  if p.menu.len > 0:
    p.moveInMenu(step)
  else:
    p.moveInHistory(step)

proc isearchForward(p: Prompt) =
  p.writeLine("isearch")

proc isearchBackwards(p: Prompt) =
  p.writeLine("isearch-r")

proc skipWordLeft*(p: Prompt) =
  if p.cursorPos == 0:
    return
  p.cursorPos -= 1
  while true:
    if p.cursorPos == 0 or p.line[p.cursorPos] == Rune(' '):
      return
    else:
      dec p.cursorPos

proc skipWordRight*(p: Prompt) =
  if p.cursorPos >= p.line.len - 1:
    return
  p.cursorPos += 1
  while true:
    if p.cursorPos == p.line.len or p.line[p.cursorPos] == Rune(' '):
      return
    else:
      inc p.cursorPos

const wordSeparators = [Rune(' '), Rune(','), Rune(';'), Rune('\t'), Rune('\n')] #array

proc rfind(line: seq[Rune], searched: openArray[Rune], startPos: int): int =
  for i in countdown(startPos, 0):
    if line[i] in searched:
      return i
  return -1

proc find(line: seq[Rune], searched: openArray[Rune], startPos: int): int =
  for i in countup(startPos, line.len - 1):
    if line[i] in searched:
      return i
  return -1

proc backspaceWord*(p: Prompt) =
  if p.line.len == 0 or p.cursorPos == 0:
    return
  var startPos = p.cursorPos - 1
  while startPos > 0 and p.line[startPos] in wordSeparators:
    dec startPos
  var sepPos = rfind(p.line, wordSeparators, startPos)
  p.line.delete(sepPos + 1, p.cursorPos - 1)
  p.cursorPos = sepPos + 1

proc deleteWord*(p: Prompt) =
  if p.line.len == 0:
    return
  var startPos = p.cursorPos
  while startPos < p.line.len - 1 and p.line[startPos] in wordSeparators:
    inc startPos
  var sepPos = p.line.find(wordSeparators, startPos)
  if sepPos == -1:
    sepPos = p.line.len
  p.line.delete(p.cursorPos, sepPos - 1)

proc home*(p: Prompt) =
  p.cursorPos = 0

proc endKey(p: Prompt) =
  p.cursorPos = p.line.len

proc pageUp(p: Prompt) =
  p.hideMenu()
  p.moveInHistory(-p.histIndex)

proc pageDown(p: Prompt) =
  p.hideMenu()
  p.moveInHistory(p.history.len - p.histIndex - 1)

proc getAppConfigDir*(): string =
  let appName = getAppFilename().splitFile.name
  return getConfigDir() / appName

proc defaultHistoryLocation*(): string =
  return getAppConfigDir() / "prompt-history.txt"

proc useHistoryFile*(p: Prompt, path = defaultHistoryLocation(), maxHistory = 5000) =
  try:
    p.historyPath = path
    p.maxHistory = maxHistory
    var inputHistory = open(path, fmRead)
    for line in inputHistory.lines:
      p.history.add(toRunes(line))
    p.historyFileLines = p.history.len
    p.histIndex = p.history.len
    inputHistory.close()
  except IOError:
    discard

proc saveHistory*(p: Prompt) =
  p.writeLine p.historyPath
  let dir = splitFile(p.historyPath).dir
  if dir.len > 0:
    os.createDir(dir)
  var outputHistory: File
  if p.history.len > p.maxHistory:
    outputHistory = open(p.historyPath, fmWrite)
    for i in countdown(p.maxHistory, 1):
      outputHistory.writeLine(p.history[^i])
  else:
    outputHistory = open(p.historyPath, fmAppend)
    for i in p.historyFileLines ..< p.history.len:
      outputHistory.writeLine(p.history[i])
  outputHistory.close()

when defined(windows):
  include prompt/windowsio
else:
  include prompt/posixio

proc readLine*(p: Prompt): string =
  p.clear()

  while true:
    p.redrawPrompt()

    template handleEnter =
      if p.enter:
        add(p.history, p.line)
        p.histIndex = p.history.len
        return $p.line

    handleKeyPress()

when isMainModule:
  import unittest

  var text = "one two three"

  test "backspace word":
    template testCase(pos, finalText, finalPos) =
      var unicodeText = toRunes(text)
      var p = new Prompt
      p.line = toRunes(text)
      p.cursorPos = pos
      p.backspaceWord()

      check:
        p.line == toRunes(finalText)
        p.cursorPos == finalPos

    testCase 0, "one two three", 0
    testCase 1, "ne two three", 0
    testCase 3, " two three", 0
    testCase 4, "two three", 0
    testCase 6, "one o three", 4
    testCase text.len, "one two ", 8

  test "delete word":
    template testCase(pos, finalText) =
      var unicodeText = toRunes(text)
      var p = new Prompt
      p.line = toRunes(text)
      p.cursorPos = pos
      p.deleteWord()

      check p.line == toRunes(finalText)

    testCase 0, " two three"
    testCase 1, "o two three"
    testCase 3, "one three"
    testCase 4, "one  three"
    testCase 6, "one tw three"
    testCase text.len - 6, "one two"
    testCase text.len - 5, "one two "
    testCase text.len - 3, "one two th"
    testCase text.len, "one two three"

  test "longest common prefix":
    check:
      longestCommonPrefix(@["abc", "ab", "ad"]) == 1
      longestCommonPrefix(@["abc", "ab"]) == 2
      longestCommonPrefix(@["abc", "abcd", "abcr"]) == 3
      longestCommonPrefix(@["abcd", "abc", "abdr"]) == 2

  test "sure chars":
    template testCase(l, pos, prefix, res, resRpos) =
      var p = new Prompt
      p.line = toRunes(l)
      p.cursorPos = pos
      p.insertSureCharacters(prefix)

      check:
        p.line == toRunes(res)
        p.cursorPos == resRpos

    testCase("f", 1, "for", "for", 3)
    testCase("af", 1, "af", "af", 2)
    testCase("-ab", 3, "abcd", "-abcd", 5)
    testCase("-ab abc", 2, "abcd", "-abcd abc", 5)

  test "insert completion":
    template testCase(l, pos, completion) =
      var p = new Prompt
      p.line = l
      p.cursorPos = pos

