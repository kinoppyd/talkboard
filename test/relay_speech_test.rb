require 'minitest/autorun'
require_relative '../firmware/relay/speech'

class RelaySpeechTest < Minitest::Test
  def setup
    @q = Talkboard::SpeechQueue.new
    @p = Talkboard::Romaji.new(@q)
  end
  def type(text, interval = 10)
    text.chars.each_with_index { |c,i| @p.feed(c, i * interval) }
  end
  def text
    @q.batch && @q.batch[0]
  end
  def test_mora_immediate
    type('ka')
    assert_equal 'ka.', text
    assert_equal '', @p.pending
  end
  def test_aliases
    type('shichitsufujichasho')
    assert_equal 'sitituhuzityasyo.', text
  end
  def test_konnichiwa
    type('konnichiwa')
    assert_equal 'konnnitiwa.', text # ko + nn + ni + ti + wa
  end
  def test_n_before_consonant
    type('kanpai')
    assert_equal 'kannpai.', text
  end
  def test_n_timeout
    type('n'); assert_nil text
    @p.tick(49); assert_nil text
    @p.tick(50); assert_equal 'nn.', text
    @p.tick(100); assert_equal 'nn.', text
  end
  def test_nn_timeout_only_once
    type('nn'); @p.tick(80)
    assert_equal 'nn.', text
  end
  def test_incomplete_h_dropped
    type('h'); @p.tick(51)
    assert_nil text
    assert_equal '', @p.pending
  end
  def test_sokuon
    type('katta')
    assert_equal 'kaxtuta.', text
  end
  def test_unsupported_recovers_without_command_injection
    type('#V$<a>')
    assert_equal 'a.', text
  end
  def test_backspace_does_not_edit
    @p.key(14,0,0) # k
    @p.key(42,0,10)
    @p.key(4,0,20)
    @p.key(42,0,30)
    assert_equal 'ka.', text
  end
  def test_shortcuts_ignored_and_shift_accepted
    @p.key(4,8,0) # command-a
    @p.key(4,1,1) # ctrl-a
    @p.key(4,4,2) # alt-a
    assert_nil text
    @p.key(4,2,3)
    assert_equal 'a.', text
  end
  def test_timestamp_wrap
    @p.feed('n',0xfffffff0)
    @p.tick(10); assert_nil text
    @p.tick(40); assert_equal 'nn.', text
  end
  def test_gap_reset
    type('k'); @p.reset; @p.feed('a',20)
    assert_equal 'a.', text
  end
  def test_queue_drop_new_preserves_old
    q=Talkboard::SpeechQueue.new(4,2)
    assert q.push('ka'); assert q.push('ki'); refute q.push('ku')
    assert_equal ['kaki.',2], q.batch
    assert_equal 1,q.dropped
    q.consume(1); assert q.push('ke')
    assert_equal ['kike.',2],q.batch
    q.consume(2); assert_nil q.batch; assert_equal 0,q.bytes
  end
  def test_batch_respects_command_limit_and_token_boundary
    100.times { @q.push('kya') }
    packet=@q.batch
    assert_equal 127,packet[0].bytesize
    assert_equal 42,packet[1]
    @q.consume(42)
    assert_equal 174,@q.bytes
  end
  class Bus
    attr_reader :writes, :reads
    attr_accessor :responses, :short
    def initialize
      @writes=[]; @reads=0; @responses=['>']; @short=false
    end
    def write(address,payload)
      raise 'wrong address' unless address==0x2e
      @writes << payload
      @short ? 0 : payload.bytesize
    end
    def read(_address,_length)
      @reads+=1
      @responses.shift || '*'
    end
  end
  def test_waits_for_ic_and_releases_accepted_text
    b=Bus.new; s=Talkboard::Speaker.new(b,@q)
    @q.push('ka'); s.step(0); s.step(1)
    assert_equal ["ka.\r"],b.writes
    assert_equal 0,@q.bytes
    @q.push('ki'); s.step(5); assert_equal 1,b.reads
    s.step(11); assert_equal 1,b.writes.size
    b.responses=['>']; s.step(21); s.step(22)
    assert_equal ["ka.\r","ki.\r"],b.writes
  end
  def test_short_write_stops_without_replay
    b=Bus.new; b.short=true; s=Talkboard::Speaker.new(b,@q)
    @q.push('ka'); s.step(0); s.step(1); s.step(100)
    assert_equal :fault,s.state
    assert_equal 1,b.writes.size
    assert_equal 2,@q.bytes
  end
  def test_ic_error_is_not_usb_failure
    b=Bus.new; s=Talkboard::Speaker.new(b,@q)
    b.responses=['E','1','0','5','>']
    5.times { |i| s.step(i*10) }
    assert_equal :ready,s.state
    assert_equal 1,s.device_errors
  end
  def test_ic_fault_timeout_is_not_queue_age
    b=Bus.new; b.responses=['*']; s=Talkboard::Speaker.new(b,@q)
    @q.push('ka'); s.step(0); s.step(30_001)
    assert_equal :fault,s.state
    assert_equal 2,@q.bytes
  end
end
