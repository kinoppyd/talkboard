#!/usr/bin/env ruby
# Build artifacts only; does not patch or reset source checkouts.
require 'fileutils'
require 'open3'
root = File.expand_path('..', __dir__)
abort 'usage: ruby tools/build_relay.rb PICORUBY_DIR PICO_PIO_USB_DIR' unless ARGV.size == 2
picoruby, pio = ARGV.map { |p| File.realpath(p) }
expected = '5a37a66dc5d3fbe0ef3cdbeda923a757440f984f'
actual, status = Open3.capture2('git', '-C', pio, 'rev-parse', 'HEAD')
abort 'wrong PIO USB revision' unless status.success? && actual.strip == expected
abort 'PicoRuby patches missing' unless File.file?(File.join(picoruby, 'build_config/talkboard-pico2w.rb'))
out = File.join(root, 'build', 'relay')
FileUtils.mkdir_p(out)
main = File.join(out, 'main.rb')
File.write(main, File.read(File.join(root, 'firmware/relay/speech.rb')) + "\n" + File.read(File.join(root, 'firmware/relay/main.rb')))
def run(*args)
  puts args.join(' ')
  system(*args) || abort("failed: #{args.first}")
end
Dir.chdir(picoruby) do
  run({'MRUBY_CONFIG' => 'build_config/talkboard-pico2w.rb', 'PICORB_BOARD' => 'pico2_w'}, 'rake')
end
sdk = File.join(picoruby, 'mrbgems/picoruby-r2p2/lib/pico-sdk')
gem_dir = File.join(picoruby, 'mrbgems/picoruby-r2p2')
run({'PICO_SDK_PATH' => sdk}, 'cmake', '-S', File.join(gem_dir, 'cmake'), '-B', out,
    "-DPICORUBY_ROOT=#{picoruby}", "-DR2P2_GEM_DIR=#{gem_dir}",
    '-DPICO_PLATFORM=rp2350', '-DPICO_BOARD=pico2_w', '-DUSE_WIFI=OFF',
    '-DMRUBY_CONFIG=talkboard-pico2w', '-DPICORB_VM_MRUBY=1',
    '-DR2P2_NAME=Talkboard', '-DR2P2_VERSION=0.1.0', '-DR2P2_BOARD_NAME=PICO2W',
    '-DTALKBOARD_RELAY=ON', "-DPICO_PIO_USB_PATH=#{pio}", "-DTALKBOARD_MAIN=#{main}",
    '-DPICORUBY_PSG_MCP4922_DMA=OFF', '-DPICORUBY_PSG_PWM_DMA=OFF',
    '-DCMAKE_BUILD_TYPE=Release', '-DPICOTOOL_FORCE_FETCH_FROM_GIT=OFF')
run('cmake', '--build', out, '--parallel', '4')
