# Concatenated after speech.rb by tools/build_relay.rb; no filesystem writes.
require 'machine'
require 'gpio'
require 'i2c'
require 'hid-relay'

queue = Talkboard::SpeechQueue.new
parser = Talkboard::Romaji.new(queue)
reset = GPIO.new(2, GPIO::OUT)
reset.write(0)
sleep 0.01
reset.write(1)
sleep 0.1
bus = I2C.new(unit: 'RP2040_I2C1', sda_pin: 6, scl_pin: 7, frequency: 100_000, timeout: 20)
speaker = Talkboard::Speaker.new(bus, queue)
generation = HIDRelay.generation

while true
  count = 0
  empty = false
  while count < 32
    event = HIDRelay.read
    if event.nil?
      empty = true
      break
    end
    if event[3] != generation
      parser.reset
      generation = event[3]
    end
    parser.key(event[1], event[2], event[0])
    count += 1
  end
  now = (Machine.uptime_us / 1000) & 0xffffffff
  if empty
    if generation != HIDRelay.generation
      parser.reset
      generation = HIDRelay.generation
    end
    parser.tick(now)
  end
  speaker.step(now)
  sleep 0.001
end
