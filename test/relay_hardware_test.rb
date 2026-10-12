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
    assert_equal 'PC_VBUS', @by_ref['MCU1']['40']
    assert_equal({ 'A'=>'+5V_EXT', 'K'=>'VSYS' }, @by_ref['D1'])
    assert_equal 'HOST_VBUS', @by_ref['J1']['1']
  end
  def test_battery_and_selector_isolate_power_sources
    assert_equal({ 'PLUS'=>'BAT_POS', 'MINUS'=>'GND' }, @by_ref['BT1'])
    assert_equal({ '1'=>'BAT_POS', '2'=>'BAT_FUSED' }, @by_ref['F1'])
    assert_equal({ 'A_COM'=>'+5V_EXT', 'A_EXT'=>'ADAPTER5V', 'A_BAT'=>'BOOST5V',
                   'B_COM'=>'BAT_FUSED', 'B_EXT'=>'NC', 'B_BAT'=>'BAT_SW' }, @by_ref['S1'])
    assert_equal 'ADAPTER5V', @by_ref['J2']['POS']
    assert_equal({ 'VIN'=>'BAT_SW', 'GND'=>'GND', 'VOUT'=>'BOOST5V', 'ENABLE'=>'NC' }, @by_ref['U4'])
    assert_equal({ 'PLUS'=>'BAT_SW', 'MINUS'=>'GND' }, @by_ref['C15'])
    assert_equal %w[MCU1 R12], @parts.select { |p| p['pins'].value?('PC_VBUS') }.map { |p| p['ref'] }.sort
  end
  def test_vbus_is_divided_before_gpio
    assert_equal 'PC_PRESENT', @by_ref['MCU1']['19']
    assert_equal({ '1'=>'PC_VBUS', '2'=>'PC_PRESENT' }, @by_ref['R12'])
    assert_equal({ '1'=>'PC_PRESENT', '2'=>'GND' }, @by_ref['R13'])
    %w[R12 R13].each { |r| assert_match(/10k ohm 1%/, @parts.find { |p| p['ref']==r }['part']) }
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
