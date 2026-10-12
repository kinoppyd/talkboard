# frozen_string_literal: true
# Dedicated Talkboard speech path; no dependency on the IC experiment console.
module Talkboard
  class SpeechQueue
    attr_reader :bytes, :dropped
    def initialize(capacity = 2048, slots = 256)
      @capacity, @slots = capacity, slots
      @items = Array.new(slots)
      @head = @tail = @count = @bytes = @dropped = 0
    end
    def push(token)
      if @count == @slots || @bytes + token.bytesize > @capacity
        @dropped += 1
        return false
      end
      @items[@tail] = token
      @tail = (@tail + 1) % @slots
      @count += 1
      @bytes += token.bytesize
      true
    end
    # Return one bounded command without consuming until transport accepts it.
    def batch
      text = ""
      n = 0
      while n < @count
        token = @items[(@head + n) % @slots]
        break if text.bytesize + token.bytesize > 126
        text += token
        n += 1
      end
      n == 0 ? nil : [text + ".", n]
    end
    def consume(n)
      while n > 0
        token = @items[@head]
        @bytes -= token.bytesize
        @items[@head] = nil
        @head = (@head + 1) % @slots
        @count -= 1
        n -= 1
      end
    end
  end

  class Romaji
    attr_reader :pending
    def initialize(queue, wait_ms = 50)
      @queue, @wait_ms = queue, wait_ms
      @pending = ""
      @sokuon = ""
      @at = nil
      @after_nn = false
      @words = {}
      # Indexed construction also works on small PicoRuby VMs.
      rows = ["a i u e o", "ka ki ku ke ko", "sa si su se so",
              "ta ti tu te to", "na ni nu ne no", "ha hi hu he ho",
              "ma mi mu me mo", "ya yu ye yo", "ra ri ru re ro",
              "wa wi we wo", "ga gi gu ge go", "za zi zu ze zo",
              "da di du de do", "ba bi bu be bo", "pa pi pu pe po",
              "va vi vu ve vo", "fa fi fe fo", "tsa tsi tse tso",
              "swi thi twu thu zwi dhi dwu dhu"]
      i = 0
      while i < rows.size
        words = rows[i].split(" ")
        j = 0
        while j < words.size
          @words[words[j]] = words[j]
          j += 1
        end
        i += 1
      end
      prefixes = "ky sy ty ny hy my ry gy zy dy by py jy".split(" ")
      vowels = "aueo"
      i = 0
      while i < prefixes.size
        j = 0
        while j < vowels.size
          word = prefixes[i] + vowels[j, 1]
          @words[word] = word
          j += 1
        end
        i += 1
      end
      aliases = ["shi", "si", "chi", "ti", "tsu", "tu", "fu", "hu",
                 "ji", "zi", "sha", "sya", "shu", "syu", "she", "sye", "sho", "syo",
                 "cha", "tya", "chu", "tyu", "che", "tye", "cho", "tyo",
                 "ja", "jya", "ju", "jyu", "je", "jye", "jo", "jyo"]
      i = 0
      while i < aliases.size
        @words[aliases[i]] = aliases[i + 1]
        i += 2
      end
      @prefixes = {}
      keys = @words.keys
      i = 0
      while i < keys.size
        j = 1
        while j < keys[i].size
          @prefixes[keys[i][0, j]] = true
          j += 1
        end
        i += 1
      end
    end
    def reset
      @pending = ""
      @sokuon = ""
      @at = nil
      @after_nn = false
    end
    def tick(now)
      return if @at.nil?
      expire if ((now - @at) & 0xffffffff) >= @wait_ms
    end
    def expire
      @queue.push("nn") if @pending == "n" && !@after_nn
      reset
    end
    def feed(char, now)
      tick(now)
      unless char >= "a" && char <= "z"
        expire
        return
      end
      @at = now
      if @pending == "n" && char == "n"
        @queue.push("nn") unless @after_nn
        @after_nn = true
        return
      end
      if @pending == "n" && char != "y" && !"aiueo".include?(char)
        @queue.push("nn") unless @after_nn
        @pending = ""
        @after_nn = false
      end
      if @pending == char && !"aiueon".include?(char)
        @sokuon = "xtu"
        return
      end
      @pending += char
      value = @words[@pending]
      if value
        @queue.push(@sokuon + value)
        reset
      elsif !@prefixes[@pending] && @pending != "n"
        # Drop the invalid prefix, but allow the current letter to start anew.
        @pending = ""
        @sokuon = ""
        if @words[char]
          @queue.push(@words[char])
          reset
        elsif @prefixes[char] || char == "n"
          @pending = char
        end
      end
    end
    def key(usage, modifiers, now)
      # Ctrl/Alt/GUI chords never feed text; Shift only changes case, ignored here.
      return if (modifiers & 0xdd) != 0
      if usage >= 4 && usage <= 29
        feed("abcdefghijklmnopqrstuvwxyz"[usage - 4, 1], now)
      elsif usage == 40 || usage == 44 || usage == 54 || usage == 55
        feed(" ", now)
      end
      # Backspace, Delete, arrows, function keys: deliberately no edit/boundary.
    end
  end

  class Speaker
    attr_reader :fault, :state, :device_errors
    def initialize(bus, queue)
      @bus, @queue = bus, queue
      @state = :boot
      @last = nil
      @response = ""
      @fault = nil
      @device_errors = 0
      @started = nil
    end
    def step(now)
      return if @fault
      @started = now if @started.nil?
      if @state == :ready
        packet = @queue.batch
        return unless packet
        payload = packet[0] + "\r"
        raise IOError, "short IC write" unless @bus.write(0x2e, payload) == payload.bytesize
        @queue.consume(packet[1])
        @state = :busy
        @started = now
        @last = now
        return
      end
      raise IOError, "IC response timeout" if ((now - @started) & 0xffffffff) > 30_000
      return if @last && ((now - @last) & 0xffffffff) < 10
      @last = now
      data = @bus.read(0x2e, 1)
      raise IOError, "short IC read" unless data && data.bytesize == 1
      b = data.getbyte(0)
      if b == 42 || b == 255
        raise IOError, "invalid IC response" unless @response.empty?
      elsif b == 62
        if !@response.empty?
          if @response.size == 4 && @response[0, 1] == "E"
            @device_errors += 1
          else
            raise IOError, "unexpected IC response"
          end
        end
        @response = ""
        @state = :ready
      elsif b >= 32 && b <= 126 && @response.size < 4
        @response += data
      else
        raise IOError, "invalid IC byte"
      end
    rescue => e
      # No automatic replay: a partially accepted command could duplicate speech.
      @fault = e.class.to_s
      @state = :fault
      @response = ""
    end
  end
end
