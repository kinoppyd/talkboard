# ATP3011 I2C driver. No hardware is accessed until reset! or speak is called.
class ATP3011
  class Error < StandardError; end
  class DeviceError < Error; end
  class CommunicationError < Error; end

  ADDRESS = 0x2e
  MAX_BYTES = 127

  # Clock injection keeps protocol tests independent of real time and hardware.
  class Clock
    def milliseconds
      Machine.uptime_us / 1000
    end

    def pause_ms(ms)
      sleep(ms / 1000.0)
    end
  end

  def initialize(bus, reset_pin, clock: Clock.new, timeout_ms: 60_000)
    @bus = bus
    @reset_pin = reset_pin
    @clock = clock
    @timeout_ms = timeout_ms
    @synchronized = false
  end

  # Hardware reset also clears a partially transmitted command after a fault.
  def silence!
    @synchronized = false
    @reset_pin.write(0)
    @clock.pause_ms(10)
    @reset_pin.write(1)
    @clock.pause_ms(100)
  end

  def reset!
    silence!
    expect_empty(read_response(2_000))
    version = exchange("#V", 2_000)
    unless version.bytesize == 4 && version[0, 1] == "V"
      raise CommunicationError, "Unexpected version response: #{version.inspect}"
    end
    @synchronized = true
    version
  end

  def speak(text)
    validate(text)
    unless @synchronized
      raise CommunicationError, "Device needs :reset before sending another message"
    end
    begin
      expect_empty(exchange(text, @timeout_ms))
    rescue CommunicationError
      @synchronized = false
      raise
    end
    true
  end

  private

  def validate(text)
    unless text.is_a?(String) && text.bytesize > 0 && text.bytesize <= MAX_BYTES
      raise ArgumentError, "Use 1..127 ASCII bytes (not including Enter)"
    end
    text.each_byte do |byte|
      if byte < 32 || byte > 126 || byte == 35 || byte == 36
        raise ArgumentError, "Use ASCII phonetic text; control characters, # and $ are not allowed"
      end
    end
  end

  def exchange(command, timeout_ms)
    # One transaction including CR. No NUL terminator, LF, or register address.
    payload = command + "\r"
    written = @bus.write(ADDRESS, payload)
    unless written == payload.bytesize
      raise CommunicationError, "Incomplete I2C write; use :reset"
    end
    read_response(timeout_ms)
  rescue IOError => e
    raise CommunicationError, "I2C failure: #{e.message}"
  end

  def read_response(timeout_ms)
    deadline = @clock.milliseconds + timeout_ms
    response = ""
    loop do
      # The datasheet requires >= 10 ms between status reads, including after CR.
      @clock.pause_ms(10)
      if @clock.milliseconds >= deadline
        raise CommunicationError, "ATP3011 response timed out; check wiring and use :reset"
      end
      data = @bus.read(ADDRESS, 1)
      unless data && data.bytesize == 1
        raise CommunicationError, "Incomplete I2C response; use :reset"
      end
      byte = data.getbyte(0)
      if byte == 42 || byte == 255
        unless response.empty?
          raise CommunicationError, "Busy marker inside a response; use :reset"
        end
        next
      end
      if byte == 62
        if response.bytesize == 4 && response[0, 1] == "E"
          digits = response[1, 3]
          valid = true
          digits.each_byte { |b| valid = false if b < 48 || b > 57 }
          raise DeviceError, "ATP3011 #{response}: check the phonetic notation" if valid
        end
        return response
      end
      if byte < 32 || byte > 126 || response.bytesize >= 16
        raise CommunicationError, "Invalid or oversized ATP3011 response; use :reset"
      end
      response << data
    end
  rescue IOError => e
    raise CommunicationError, "I2C failure: #{e.message}"
  end

  def expect_empty(response)
    unless response.empty?
      raise CommunicationError, "Unexpected speech response: #{response.inspect}"
    end
  end
end

class ATP3011Console
  def initialize(device, input, output)
    @device = device
    @input = input
    @output = output
  end

  def run
    @output.puts "ATP3011 speech: ASCII phonetic text, max 127 bytes."
    @output.puts ":quit = exit, :reset = reset device; example: konnichiwa."
    connect
    loop do
      @output.print "say> "
      line = @input.gets
      break if line.nil?
      text = line.chomp.strip
      next if text.empty?
      break if text == ":quit"
      if text == ":reset"
        connect
        next
      end
      begin
        @device.speak(text)
        @output.puts "[done]"
      rescue ArgumentError, ATP3011::Error => e
        @output.puts "[error] #{e.message}"
      end
    end
    @output.puts "Bye."
  ensure
    # Also runs on an ordinary Ruby exception or an interrupt unwinding Ruby.
    @device.silence!
  end

  private

  def connect
    version = @device.reset!
    @output.puts "[ready] #{version}"
  rescue ATP3011::Error => e
    @output.puts "[error] #{e.message}; correct the wiring with power off, then :reset"
  end
end
