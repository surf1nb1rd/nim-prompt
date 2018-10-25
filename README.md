# nim-prompt

![Software License](https://img.shields.io/badge/license-BSD-brightgreen.svg?style=flat-square)

A library for building powerful interactive prompts inspired by [python-prompt-toolkit](https://github.com/jonathanslenders/python-prompt-toolkit), making it easier to build cross-platform command line tools using Nim.

#### Projects using nim-prompt

* [nim-chronicles](https://github.com/status-im/nim-chronicles/). The log filtering tool chronicles_tail was the original project that lead to the creation of this library.

## Features

### Powerful auto-completion

### Keyboard Shortcuts

The provided shortcuts should be familiar to most Windows, macOS and Linux users.

Key Binding                                           | Description
------------------------------------------------------|------------------------------------------------
<kbd>Home</kbd>, <kbd>Ctrl + A</kbd>                  | Go to the beginning of the line
<kbd>End</kbd>,  <kbd>Ctrl + E</kbd>                  | Go to the end of the line
<kbd>Up Arrow</kbd>, <kbd>Ctrl + P</kbd>              | Previous command, Previous completion
<kbd>Down Arrow</kbd>, <kbd>Ctrl + N</kbd>            | Next command, Next completion
<kbd>Right Arrow</kbd>, <kbd>Ctrl + F</kbd>           | Forward one character
<kbd>Left Arrow</kbd>, <kbd>Ctrl + B</kbd>            | Backward one character
<kbd>Ctrl + Right Arrow</kbd>, <kbd> Alt + F</kbd>    | Move to next word
<kbd>Ctrl + Left Arrow</kbd>, <kbd> Alt + B</kbd>     | Move to previous word
<kbd>Delete</kbd>, <kbd>Ctrl + D</kbd>                | Delete character under the cursor
<kbd>Backspace</kbd>, <kbd>Ctrl + H</kbd>             | Delete character before the cursor
<kbd>Ctrl + Delete</kbd>                              | Delete to end of word
<kbd>Ctrl + Backspace</kbd>                           | Delete to beginning of word
<kbd>Tab</kbd>                                        | Trigger auto-complete, Select next completion
<kbd>Ctrl + L</kbd>                                   | Clear the screen
<kbd>Enter</kbd>, <kbd>Ctrl + J</kbd>                 | Accept line

### History

You can use <kbd>Up arrow</kbd> and <kbd>Down arrow</kbd> to walk through the history of commands executed.
An optional history file can be specified for each user program.

### Unicode aware

nim-prompt will correctly handle and display all unicode characters. In the public API, all procs use UTF-8 encoded strings on all platforms.

### Multiple platform support

We have confirmed nim-prompt works fine in the following terminals:

* iTerm2, Terminal.app (macOS)
* Command Prompt (Windows)
* gnome-terminal (Ubuntu)

## License

This software is licensed under the BSD 2-Clause license, see [LICENSE](./LICENSE) for more information.
