#!/usr/bin/env ruby
require 'rbconfig'
require 'tmpdir'
root = File.expand_path('..', __dir__)
abort 'usage: ruby tools/test_relay.rb PATCHED_PICORUBY_DIR' unless ARGV.size == 1
src = File.join(File.realpath(ARGV[0]), 'mrbgems/picoruby-hid-relay')
Dir.chdir(root) do
  %w[test/relay_speech_test.rb test/relay_hardware_test.rb].each do |test|
    system(RbConfig.ruby, test) || abort("failed: #{test}")
  end
  Dir.mktmpdir('talkboard-tests') do |tmp|
    exe = File.join(tmp,'relay_core_test')
    system(ENV.fetch('CC','cc'), '-std=c11', '-Wall', '-Wextra', '-Werror',
           '-fsanitize=address,undefined', '-I',File.join(src,'include'),
           'test/relay_core_test.c', File.join(src,'ports/common/relay_core.c'), '-o',exe) || abort('C compile failed')
    system(exe) || abort('C tests failed')
    runtime = File.join(tmp,'relay_runtime_test')
    system(ENV.fetch('CC','cc'), '-std=c11', '-Wall', '-Wextra', '-Werror',
           '-fsanitize=address,undefined', '-I','test/relay_stubs',
           '-I',File.join(src,'ports/rp2040'), 'test/relay_runtime_test.c',
           File.join(src,'ports/common/relay_core.c'), '-o',runtime) || abort('runtime compile failed')
    system(runtime) || abort('runtime tests failed')
  end
end
