# Install both files in /home on R2P2 (PicoRuby VM, Raspberry Pi Pico 2 W).
require 'i2c'
require 'gpio'
require 'io/console'
load '/home/atp3011.rb'

bus = I2C.new(unit: :RP2040_I2C1, frequency: 100_000,
              sda_pin: 6, scl_pin: 7, timeout: 100)
reset_pin = GPIO.new(2, GPIO::OUT)
device = ATP3011.new(bus, reset_pin)

# R2P2 cooked input supplies echo, Backspace and Ctrl-D handling.
STDIN.cooked do
  ATP3011Console.new(device, $stdin, $stdout).run
end
