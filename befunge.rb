#!/usr/bin/env ruby

# for <=1.8.6 compatibility
# added by K.Iwamoto
unless String.method_defined? :ord
   class String
      def ord
	 self[0]
      end
   end
end

# for <=1.8.6 compatibility
# added by K.Iwamoto
unless Integer.method_defined? :ord
   class Integer
      def ord
	 self
      end
   end
end

class VM
   class Stack < Array
      def pop
	 v = super
	 v ? v: 0
      end

      # added by K.Iwamoto
      def last
	 empty? ? 0 : super
      end
   end

   class Point 
      attr_accessor :x, :y
      def initialize(x,y)
         @x = x
         @y = y
      end
      def to_s
         "(#{x} , #{y})"
      end
   end

   attr_reader :dir
   UP = 0
   DOWN =  1
   LEFT =  2
   RIGHT = 3
   DIR = {'>'=>RIGHT, '<'=>LEFT, '^'=>UP, 'v'=>DOWN}

   attr_reader :state
   MODE_NORMAL = 0
   MODE_STRING = 1

   attr_reader :curpos
   attr_reader :stack
   attr_reader :prog

   OP = {
      '+' => Proc.new { |x,y| x + y },
      '-' => Proc.new { |x,y| x - y },
      '*' => Proc.new { |x,y| x * y },
      '/' => Proc.new { |x,y| x / y },
      '%' => Proc.new { |x,y| x % y }
   }

   def read_raw(p)
      @prog[p.y][p.x]
   end

   def write_raw(p, v)
      @prog[p.y][p.x] = v
   end

   def read
      read_raw(@curpos)
   end

   def initialize(prog=nil)
      @stack = Stack.new
      @curpos = Point.new(0,0)
      @dir = RIGHT
      @state = MODE_NORMAL
      @debug = false
      if prog then load_program(prog) end
   end

   def load_program(prog)
      @prog   = prog.split("\n")
      @width  = 80
      @height = 25
      (25-@prog.length).times {|i| @prog += [""] }
      @prog   = @prog.map {|l| l.ljust(@width)}
   end

   def nextpos
      case @dir
      when RIGHT
         @curpos.x = (@curpos.x+1) % @width
      when LEFT
         @curpos.x = (@curpos.x-1) % @width
      when UP
         @curpos.y = (@curpos.y-1) % @height
      when DOWN
         @curpos.y = (@curpos.y+1) % @height
      end
   end

   # utils for isrns
   def doublequote
      @state = (MODE_STRING+MODE_NORMAL) - @state
   end

   def changedir(pred, oneway, anotherway)
      @dir = (pred == 0)? oneway : anotherway
   end

   def swaplast2
      t = @stack.pop
      @stack.push(t, @stack.pop)
   end

   def alu(op)
      y = @stack.pop
      x = @stack.pop
      @stack.push OP[op].call(x,y)
   end

   def cmp
      y = @stack.pop
      x = @stack.pop
      @stack.push  x > y ? 1 : 0
   end
   
   def negate
      @stack.push  @stack.pop == 1? 0 : 1
   end

   def get
      y = @stack.pop
      x = @stack.pop
      @stack.push  read_raw(Point.new(x,y)).ord
   end

   def put
      y = @stack.pop
      x = @stack.pop
      v = @stack.pop
      write_raw(Point.new(x,y), v.chr) 
   end

   def show_program
      if @debug
	 STDERR.puts @prog.join("-\n")
      end
   end


   # main dispatcher
   def step(n=1)
      c = read

      if @debug
         STDERR.print "pos: #{@curpos} mnemonic: #{c.chr} "
         STDERR.puts  "dir: #{@dir} stack: #{@stack.join(',')}"
      end

      if @state == MODE_STRING && c != ?"
         @stack.push(c.ord)
      else 
         case c

            #control
         when ?v,?<,?>,?^     then @dir = DIR[c.chr]
         when ?_              then changedir(@stack.pop, RIGHT, LEFT)
         when ?|              then changedir(@stack.pop,  DOWN, UP  )
         when ??	      then @dir = rand(4)
         when ?#	      then nextpos    # through!
         when ?@              then return false

            #literal
         when ?0 .. ?9        then @stack.push c.chr.to_i
         when ?"              then doublequote

            #I/O
         when ?&              then @stack.push STDIN.readline.to_i
         when ?~              then @stack.push STDIN.getc.ord
         when ?.              then print @stack.pop
         when ?,              then print @stack.pop.chr

            #arith & logic 
         when ?+,?-,?*,?/,?%  then alu(c.chr)
         when ?`              then cmp
         when ?!	      then negate

            #stack manip
         when ?:              then @stack.push @stack.last
         when ?\\	      then swaplast2
         when ?$	      then @stack.pop   #just discard

            #mem manip
         when ?g	      then get
         when ?p              then put

	    #debug
	 when ?=	      then show_program

         end
      end
      nextpos
   end

   def debugenable
      @debug = true
   end
end


vm = VM.new

if ARGV[0] == "-d"
   ARGV.shift
   vm.debugenable
end

begin
    vm.load_program(File.open(ARGV[0]).read)
rescue 
    puts "#{$0}: file not found"
    exit
end

while vm.step
end
