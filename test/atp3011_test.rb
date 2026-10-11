require 'minitest/autorun'
require 'stringio'
require_relative '../examples/atp3011/atp3011'

class SpeechClock
  attr_reader :milliseconds, :delays
  def initialize
    @milliseconds = 0
    @delays = []
  end
  def pause_ms(ms)
    @delays << ms
    @milliseconds += ms
  end
end

class SpeechPin
  attr_reader :levels
  def initialize(bus)
    @bus = bus
    @levels = []
  end
  def write(level)
    @levels << level
    @bus.hardware_reset if level == 0
  end
end

# Model the chip: ready repeats '>', writes install the next command response.
class SpeechBus
  attr_reader :writes, :read_times
  attr_accessor :next_response, :read_error, :write_error, :short_write, :short_read
  def initialize(clock)
    @clock = clock
    @pending = []
    @writes = []
    @read_times = []
    @next_response = '*>'
  end
  def write(address, payload)
    raise 'wrong address' unless address == 0x2e
    raise IOError, 'NACK' if @write_error
    @writes << payload
    @pending = (payload == "#V\r" ? 'VF1a>' : @next_response).bytes
    @short_write ? payload.bytesize - 1 : payload.bytesize
  end
  def hardware_reset
    @pending = []
  end
  def read(address, size)
    raise 'wrong read shape' unless address == 0x2e && size == 1
    raise IOError, 'NACK' if @read_error
    @read_times << @clock.milliseconds
    return '' if @short_read
    [@pending.empty? ? 62 : @pending.shift].pack('C')
  end
end

class ATP3011Test < Minitest::Test
  def setup
    @clock = SpeechClock.new
    @bus = SpeechBus.new(@clock)
    @pin = SpeechPin.new(@bus)
    @device = ATP3011.new(@bus, @pin, clock: @clock, timeout_ms: 100)
    @device.reset!
  end

  def test_reset_pulse_startup_delay_and_version
    assert_equal [0, 1], @pin.levels
    assert_equal [10, 100], @clock.delays.first(2)
    assert_equal ["#V\r"], @bus.writes
  end

  def test_speech_waits_for_busy_and_ff_and_sends_cr_only
    @bus.next_response = "*\xff*>".b
    assert @device.speak('konnichiwa.')
    assert_equal "konnichiwa.\r", @bus.writes.last
    assert @bus.read_times.each_cons(2).all? { |a, b| b - a >= 10 }
  end

  def test_immediate_completion_does_not_require_observing_busy
    @bus.next_response = '>'
    assert @device.speak('a.')
  end

  def test_127_bytes_plus_cr_fit_one_transaction
    assert @device.speak('a' * 127)
    assert_equal 128, @bus.writes.last.bytesize
  end

  def test_invalid_input_never_reaches_chip
    ['', 'a' * 128, "こんにちは", "a\r#W00000", "a\n", "a\0", '#V', '$'].each do |text|
      before = @bus.writes.size
      assert_raises(ArgumentError) { @device.speak(text) }
      assert_equal before, @bus.writes.size
    end
  end

  def test_phonetic_punctuation_and_number_tag_are_preserved
    text = "o'nnsei/<NUM VAL=123>desu."
    @device.speak(text)
    assert_equal text + "\r", @bus.writes.last
  end

  def test_device_error_is_complete_and_next_message_can_succeed
    @bus.next_response = 'E105>'
    error = assert_raises(ATP3011::DeviceError) { @device.speak('zzz') }
    assert_includes error.message, 'E105'
    @bus.next_response = '>'
    assert @device.speak('a.')
  end

  def test_timeout_prevents_replay_until_reset
    @bus.next_response = '*' * 100
    start = @clock.milliseconds
    assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
    assert_equal 100, @clock.milliseconds - start
    before = @bus.writes.size
    assert_raises(ATP3011::CommunicationError) { @device.speak('i.') }
    assert_equal before, @bus.writes.size
    before_reads = @bus.read_times.size
    assert_equal 'VF1a', @device.reset!
    # Old busy bytes must disappear on hardware reset, not be slowly drained.
    assert_equal 6, @bus.read_times.size - before_reads
    @bus.next_response = '>'
    assert @device.speak('u.')
  end

  def test_read_nack_is_actionable
    @bus.read_error = true
    error = assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
    assert_includes error.message, 'NACK'
  end

  def test_write_nack_is_actionable
    @bus.write_error = true
    assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
  end

  def test_short_write_and_read_are_not_success
    @bus.short_write = true
    assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
    @bus.short_write = false
    @device.reset!
    @bus.short_read = true
    assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
  end

  def test_invalid_response_and_unexpected_payload
    ["\0", 'X>', 'Eabc>', 'E*', 'X' * 20].each do |response|
      @device.reset!
      @bus.next_response = response
      assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
    end
  end

  def test_reset_failure_keeps_device_unsynchronized
    @bus.read_error = true
    assert_raises(ATP3011::CommunicationError) { @device.reset! }
    @bus.read_error = false
    before = @bus.writes.size
    assert_raises(ATP3011::CommunicationError) { @device.speak('a.') }
    assert_equal before, @bus.writes.size
  end

  def test_console_repeats_skips_blank_and_exits
    output = StringIO.new
    input = StringIO.new("\r\n  konnichiwa.\r\n\nohayo-.\n:quit\nignored\n")
    ATP3011Console.new(@device, input, output).run
    assert_equal ["konnichiwa.\r", "ohayo-.\r"], @bus.writes.reject { |x| x == "#V\r" }
    assert_equal 2, output.string.scan('[done]').size
    assert_includes output.string, 'Bye.'
    assert_equal [0, 1], @pin.levels.last(2)
  end

  def test_console_rejects_input_and_handles_eof
    output = StringIO.new
    ATP3011Console.new(@device, StringIO.new("#W00000\na.\n"), output).run
    assert_includes output.string, '[error]'
    assert_includes output.string, '[done]'
    assert_includes output.string, 'Bye.'
  end

  def test_console_reset_command
    ATP3011Console.new(@device, StringIO.new(":reset\n:quit\n"), StringIO.new).run
    assert_equal 3, @bus.writes.count("#V\r")
  end

  def test_console_startup_failure_remains_interactive
    @bus.read_error = true
    output = StringIO.new
    ATP3011Console.new(@device, StringIO.new("a.\n:quit\n"), output).run
    assert_includes output.string, ':reset'
    refute_includes output.string, '[done]'
    assert_includes output.string, 'Bye.'
  end

  def test_console_ensure_silences_device_on_interrupt
    input = Object.new
    def input.gets
      raise Interrupt
    end
    before = @pin.levels.size
    assert_raises(Interrupt) { ATP3011Console.new(@device, input, StringIO.new).run }
    assert_equal before + 4, @pin.levels.size
  end
end
