# curses-irc

Originally a bare-bones learning project called Let's Type, `curses-irc` is a small terminal-based IRC client made in Ruby using its implementation of C's `curses` library. For simplicity and novelty, `curses-irc` forgoes the tab system commonly seen in IRC clients, and instead displays messages from all channels the user has joined in the same window.

Can be launched from any size terminal window, and conforms to that window's dimensions. Supports logging, scrolling, and automatic adjustment of the input field for multiline input.