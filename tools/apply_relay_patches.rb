#!/usr/bin/env ruby
require 'open3'
require 'tmpdir'
require 'fileutils'
root = File.expand_path('..', __dir__)
abort 'usage: ruby tools/apply_relay_patches.rb CLEAN_PICORUBY_DIR' unless ARGV.size == 1
dir = File.realpath(ARGV[0])
base = '371d176f1bfd834d18ff2a8c86d2667b51b0fd32'
head, ok = Open3.capture2('git','-C',dir,'rev-parse','HEAD')
abort 'wrong PicoRuby base revision' unless ok.success? && head.strip == base
status, ok = Open3.capture2('git','-C',dir,'status','--porcelain','--untracked-files=normal')
abort 'checkout must be clean (no user edits are overwritten)' unless ok.success? && status.empty?
series = File.readlines(File.join(root,'patches/picoruby-hid-relay/series'), chomp: true).reject(&:empty?)
patches = series.map { |p| File.join(root,'patches/picoruby-hid-relay',p) }
Dir.mktmpdir('talkboard-patch-preflight') do |tmp|
  # Independent index checks the complete ordered series before touching files.
  env = {'GIT_INDEX_FILE'=>File.join(tmp,'index')}
  system(env,'git','-C',dir,'read-tree','HEAD') || abort('cannot prepare index')
  patches.each do |patch|
    system(env,'git','-C',dir,'apply','--cached','--check',patch) || abort("preflight failed: #{patch}")
    system(env,'git','-C',dir,'apply','--cached',patch) || abort('preflight failed')
  end
end
patches.each do |patch|
  system('git','-C',dir,'apply','--check',patch) || abort('unexpected working tree change; stop')
  system('git','-C',dir,'apply',patch) || abort("apply failed: #{patch}")
end
puts "Applied #{patches.size} patches; no commits created in the checkout."
