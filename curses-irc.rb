#!/usr/local/bin/ruby

# Curses IRC, based on michsa/lets-type

require 'curses'
require 'socket'

# TODO: make these configurable
NICK="michsa"
IDENT="michsa"
HOST="irc.freenode.net"
REALNAME="Michelle Saad"

class Client
  def initialize server, pad, footer, main, header
    @server = server
    @footer = footer
    @pad = pad
    @main = main
    @header = header
    @footer_height = FOOTER_HEIGHT
    @request = nil
    @response = nil
    sendmsg "NICK #{NICK}"
    sendmsg "USER #{IDENT} #{HOST} bla :#{REALNAME}"
    listen
    send
    @response.join
    @request.join
  end
  
  def listen
    @response = Thread.new do
      loop {
        msg = @server.gets.chomp.split(' ', 3);
        if msg[0] == 'PING'
          sendmsg "PONG #{msg[1]}"
        else
          user = msg[0].match /(?<=\:)(.*?)(?=\!)/
          command = msg[1]
          args = msg[2].split ':', 2
          channels = args[0].chomp.split(' ').join(', ')
          message = args[1]
          
          case command
          when 'JOIN'
            @pad.write (Time.now.strftime "%H:%M:%S "), false, true
            @pad.write "<"
            @pad.write "#{user}", true
            @pad.write "> joined ["
            @pad.write "#{message}", true
            @pad.write "]"
          when 'QUIT'
            @pad.write (Time.now.strftime "%H:%M:%S "), false, true
            @pad.write "<"
            @pad.write "#{user}", true
            @pad.write ">"
            @pad.write " quit: #{message}"
          when 'PRIVMSG'
            @pad.write (Time.now.strftime "%H:%M:%S "), false, true
            @pad.write "["
            @pad.write "#{channels}", true
            @pad.write "] "
            @pad.write "<"
            @pad.write "#{user}", true
            @pad.write ">"
            @pad.write " #{message}"
          else
            @pad.write (Time.now.strftime "%H:%M:%S "), false, true
            @pad.write msg.join
          end
        end
      }
    end
  end
  
  def send
    @header.color_set 10
    @header << "Curses IRC".center(HEADER_WIDTH)
    @header.refresh

    @main.box ?|, ?-
    @main.refresh

    @pad.write_center 0, "Type something and press enter!"
    @pad.write_center 2, "Use arrow keys to scroll."
    @pad.write_center 1, "Enter '/q' to exit. Enter '/c' to clear."
    @pad.write_center 4, "Let's Type!! :)"

    @pad.print 0

    @footer.refresh
    line = ''
    n = 0
    max_n = 0
    @footer.win.keypad true

    @request = Thread.new do
      while (input = @footer.win.getch)
        if @footer.win.curx == WIN_WIDTH - 1
          @footer_height += 1
          @main.resize MAIN_HEIGHT + 1 - @footer_height, MAIN_WIDTH
          @main.box ?|, ?-
          @main.refresh
          @pad.push_up @footer_height - FOOTER_HEIGHT
          @footer.win.move WIN_HEIGHT - @footer_height, 0
          @footer.win.resize @footer_height, FOOTER_WIDTH
        end
        if input == 10
          if line == '/c'
            @pad.wipe
          elsif line == '/q'
            break
          elsif line == '/l'
            @pad.toggle_logging
          else
            # TODO: better input parsing goes here
            # (or move this whole thing to someplace better)
            @server.puts line
            @pad.write (Time.now.strftime "%H:%M:%S "), false, true
            @pad.write "<"
            @pad.write NICK, true
            @pad.write "> #{line}"
          end
          line = ''
          n = max_n = 0
          @footer_height = FOOTER_HEIGHT
          @footer.win.resize FOOTER_HEIGHT, FOOTER_WIDTH
          @footer.win.move WIN_HEIGHT - FOOTER_HEIGHT, 0
          @footer.refresh
          @main.resize MAIN_HEIGHT, MAIN_WIDTH
          @main.box ?|, ?-
          @main.refresh
          @pad.push_up 0
        elsif input == Curses::KEY_UP or input == Curses::KEY_DOWN
          @pad.scroll input
        elsif input == Curses::KEY_BACKSPACE and n > 0
          @footer.win.delch
          line.slice! n-1
          n -= 1
          max_n -= 1
        elsif input == Curses::KEY_LEFT and n > 0
          @footer.win.setpos @footer.win.cury, @footer.win.curx-1
          n -= 1
        elsif input == Curses::KEY_RIGHT and n < max_n
          @footer.win.setpos @footer.win.cury, @footer.win.curx+1
          n += 1
        elsif !CONSTANTS.include? input
          if n < max_n
            @footer.win.insch line[n]
          end
          line.insert n, input
          n += 1
          max_n += 1
        end
      end
    end
  end
  
  def sendmsg msg
    @server.puts msg
  end
end


class Output
  def initialize height, width
    @pad = Curses::Pad.new height, width
    @i = 0
    @size = 0
    @make_log = true
    @log = "lets_type_#{Time.now.strftime "%Y-%m-%d_%H-%M-%S"}.txt"
    @line_length = 0
  end

  def print offset
    @pad.refresh offset, 0, HEADER_HEIGHT + 1, 1, MAIN_HEIGHT - 1, MAIN_WIDTH - 1
  end

  def write_center offset, msg
    @pad.setpos offset, 0
    @pad << msg.center(PAD_WIDTH)
  end
  
  def wipe
    @pad.clear
    @size = 0
    @i = 0
    print @i
  end
  
  def scroll input
    case input
      when Curses::KEY_UP
        @i > 0 and @i -= 1
      when Curses::KEY_DOWN
        @i < @size and @i += 1
    end
    self.print @i
  end
    
  def write string, color=false, newline=false
    (1..string.length).each do |i|
      if (@line_length) % PAD_WIDTH == 0 or ( i == 1 and newline )
        @size += 1
        @i += 1
        @pad.resize PAD_HEIGHT + @size, PAD_WIDTH
        @pad.setpos PAD_HEIGHT + @size - 1, 0
        @line_length = 0
      end
      if color
        @pad.color_set ( (string.hash % 4) + 1)
      else
        @pad.color_set 0
      end
      @pad << string[i-1]
      @line_length += 1
    end
    self.print @size
  end
  
  def push_up lines
    self.print @size + lines
  end
  
  def toggle_logging
    @make_log = !@make_log
  end
end


class Input
  def initialize height, width, y, x
    @win = Curses::Window.new height, width, y, x
    @win.color_set 0
  end

  def refresh
    @win.clear
    @win << " ".center(FOOTER_WIDTH)
    @win.setpos 0, 0
    @win << " > "
    @win.refresh
  end
  
  def win
    return @win
  end
  
end


constants = Array.new
Curses::Key.constants.each do |constant|
  constants.push Curses::Key.const_get constant
end
CONSTANTS = Array.new constants
  
Curses.stdscr.keypad true
Curses.stdscr.nodelay = 1
Curses.init_screen
Curses.start_color
Curses.curs_set 1

WIN_WIDTH = Curses.cols
WIN_HEIGHT = Curses.lines
HEADER_HEIGHT = 1
curr_footer_height = FOOTER_HEIGHT = 1
MAIN_HEIGHT = WIN_HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT
HEADER_WIDTH = FOOTER_WIDTH = MAIN_WIDTH = WIN_WIDTH
PAD_HEIGHT = MAIN_HEIGHT - 2
PAD_WIDTH = MAIN_WIDTH - 2

header = Curses::Window.new HEADER_HEIGHT, HEADER_WIDTH, 0, 0
main = Curses::Window.new MAIN_HEIGHT, MAIN_WIDTH, HEADER_HEIGHT, 0
footer = Input.new FOOTER_HEIGHT, FOOTER_WIDTH, WIN_HEIGHT - FOOTER_HEIGHT, 0
pad = Output.new PAD_HEIGHT, PAD_WIDTH

Curses.init_pair 10, Curses::COLOR_BLACK, Curses::COLOR_GREEN

Curses.init_pair 1, Curses::COLOR_GREEN, Curses::COLOR_BLACK
Curses.init_pair 2, Curses::COLOR_CYAN, Curses::COLOR_BLACK
Curses.init_pair 3, Curses::COLOR_MAGENTA, Curses::COLOR_BLACK
Curses.init_pair 4, Curses::COLOR_RED, Curses::COLOR_BLACK
Curses.init_pair 5, Curses::COLOR_YELLOW, Curses::COLOR_BLACK


server = TCPSocket.open HOST, 6667
client = Client.new server, pad, footer, main, header