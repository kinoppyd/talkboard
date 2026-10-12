require 'minitest/autorun'
require 'json'
class RelayHardwareTest < Minitest::Test
  def setup
    @parts = JSON.parse(File.read(File.expand_path('../hardware/hid-relay/netlist.json', __dir__)))['parts']
    @by_ref = @parts.to_h { |p| [p['ref'], p['pins']] }
  end
  def test_unique_references
    assert_equal @parts.size, @by_ref.size
  end
  def test_power_isolation
    assert_equal 'PC_VBUS_NC', @by_ref['MCU1']['40']
    assert_equal({ 'A'=>'+5V_EXT', 'K'=>'VSYS' }, @by_ref['D1'])
    assert_equal 'HOST_VBUS', @by_ref['J1']['1']
  end
  def test_gpio_contract
    assert_equal %w[RESET_N SDA SCL DP_GPIO DM_GPIO HOST_EN HOST_OC_N],
      %w[4 9 10 14 15 16 17].map { |p| @by_ref['MCU1'][p] }
  end
  def test_ic_supply_and_mode
    assert_equal 28, @by_ref['U1'].size
    %w[5 6 7 14 15 20].each { |p| assert_equal '+3V3', @by_ref['U1'][p] }
    %w[4 8 22].each { |p| assert_equal 'GND', @by_ref['U1'][p] }
    %w[9 10 21].each { |p| assert_equal 'NC', @by_ref['U1'][p] }
  end
  def test_speaker_has_dc_blocking
    assert_equal 'AMP_OUT', @by_ref['C9']['PLUS']
    assert_equal 'SPEAKER', @by_ref['C9']['MINUS']
    assert_equal 'SPEAKER', @by_ref['SP1']['PLUS']
  end
end
