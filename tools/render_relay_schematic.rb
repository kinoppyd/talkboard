#!/usr/bin/env ruby
# Deterministic vector net-label schematic; netlist.json is the source of truth.
require 'json'
require 'cgi'
root = File.expand_path('..', __dir__)
data = JSON.parse(File.read(File.join(root, 'hardware/hid-relay/netlist.json')))
e = ->(s) { CGI.escapeHTML(s.to_s) }
parts = data.fetch('parts')
columns = 3
width = 1500
heights = Array.new(columns, 190)
boxes = []
parts.each_with_index do |part, i|
  c = i < 3 ? i : heights.each_with_index.min[1]
  x = 20 + c * 495
  y = heights[c]
  h = 68 + part['pins'].size * 23
  boxes << %(<rect x="#{x}" y="#{y}" width="470" height="#{h}" rx="6" fill="white" stroke="#345"/>)
  boxes << %(<text x="#{x+12}" y="#{y+24}" font-size="17" font-weight="bold">#{e.call(part['ref'])}</text>)
  boxes << %(<text x="#{x+12}" y="#{y+46}" font-size="13">#{e.call(part['part'])}</text>)
  part['pins'].each_with_index do |(pin, net), j|
    py = y + 70 + j * 23
    color = net == 'GND' ? '#333' : net.start_with?('+') ? '#a22' : '#146'
    boxes << %(<line x1="#{x+10}" y1="#{py-5}" x2="#{x+100}" y2="#{py-5}" stroke="#{color}"/>)
    boxes << %(<circle cx="#{x+100}" cy="#{py-5}" r="3" fill="#{color}"/>)
    boxes << %(<text x="#{x+15}" y="#{py-9}" font-size="11">pin #{e.call(pin)}</text>)
    boxes << %(<text x="#{x+115}" y="#{py}" font-size="15" fill="#{color}">#{e.call(net)}</text>)
  end
  heights[c] += h + 20
end
svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{heights.max+20}" viewBox="0 0 #{width} #{heights.max+20}"><rect width="100%" height="100%" fill="#eef2f5"/><g font-family="monospace"><text x="20" y="35" font-size="24">#{e.call(data['title'])}</text>)
data['notes'].each_with_index { |note,i| svg += %(<text x="20" y="#{65+i*25}" font-size="14">#{e.call(note)}</text>) }
svg += boxes.join("\n") + '</g></svg>'
File.write(File.join(root, 'hardware/hid-relay/schematic.svg'), svg + "\n")
