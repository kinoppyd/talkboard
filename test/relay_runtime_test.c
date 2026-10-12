#include <assert.h>
#include <stdio.h>
#define TALKBOARD_RELAY 1
#include "hid_relay.c"
static const uint8_t desc[]={
  0x05,7,0x19,224,0x29,231,0x15,0,0x25,1,0x75,1,0x95,8,0x81,2,
  0x75,8,0x95,1,0x81,1,0x19,0,0x29,101,0x75,8,0x95,6,0x81,0};
static void key(uint8_t u) {
  uint8_t report[8]={0,0,u,0,0,0,0,0};
  fake_ms++;
  tuh_hid_report_received_cb(1,0,report,8);
}
int main(void) {
  /* Battery cold boot: no PC, and no configured USB endpoints. */
  fake_vbus=false; fake_mounted=false; fake_ready=false;
  relay_device_task(); assert(fake_unplugs==0);
  relay_start(); relay_device_task();
  assert(!fake_pullup && fake_unplugs==1);
  tuh_hid_mount_cb(1,0,desc,sizeof(desc));
  relay_event e;
  for(int n=0;n<300;n++) {
    key(4); key(0); relay_device_task();
    assert(relay_read_event(&e) && e.key==4);
    assert(!relay_read_event(&e) && load(&fw)==load(&fr));
  }
  assert(fake_count==0 && relay_errors()==0);
  /* VBUS without enumeration still speaks. Latest held state is synced,
   * but 300 offline taps must never be replayed or observed twice. */
  fake_vbus=true; relay_device_task(); assert(fake_pullup);
  key(5); relay_device_task(); assert(relay_read_event(&e) && e.key==5);
  fake_mounted=true; fake_ready=true; relay_device_task();
  assert(fake_count==3 && fake_reports[0].bytes[0]==32);
  assert(!relay_read_event(&e));
  key(0); relay_device_task();
  relay_device_task(); /* enumerate before the first input */
  fake_count=0;
  assert(ports[0].active);
  fake_ready=false;
  key(4); relay_device_task();
  assert(fake_count==0);
  key(0); relay_device_task();
  assert(fake_count==0);
  fake_ready=true;
  relay_device_task(); relay_device_task();
  assert(fake_count==2); /* no redundant media/system reports */
  assert(fake_reports[0].bytes[0]==16);
  assert(fake_reports[1].bytes[0]==0);
  assert(relay_read_event(&e) && e.key==4);
  assert(!relay_read_event(&e));
  key(5); relay_device_task(); key(5); relay_device_task();
  assert(relay_read_event(&e) && e.key==5); assert(!relay_read_event(&e));
  tud_hid_set_protocol_cb(0,HID_PROTOCOL_BOOT); relay_device_task();
  assert(fake_reports[fake_count-1].len==8);
  assert(fake_reports[fake_count-1].bytes[2]==5);
  uint8_t led=3, buf[64];
  tud_hid_set_report_cb(0,0,HID_REPORT_TYPE_OUTPUT,&led,1);
  assert(tud_hid_get_report_cb(0,0,HID_REPORT_TYPE_OUTPUT,buf,64)==1 && buf[0]==3);
  /* Slow Ruby observer must not stop forwarding; new observation events drop. */
  for(int n=0;n<300;n++) { key(n%2?0:4); relay_device_task(); }
  assert(relay_generation()>0 && fake_count>250);
  /* Unplug emits release; no replay of input collected while PC is absent. */
  key(9); relay_device_task();
  assert(current.keys[1]==2);
  tuh_hid_umount_cb(1,0); snapshot(); relay_device_task();
  assert(fake_reports[fake_count-1].bytes[2]==0);
  assert(!ports[0].active);
  tuh_hid_mount_cb(1,0,desc,sizeof(desc));
  fake_mounted=false; relay_device_task();
  fake_mounted=true; relay_device_task();
  assert(current.keys[0]==0);
  while(relay_read_event(&e)) {}
  /* RP2 DCD can leave mounted=true and suspended=true on physical unplug.
   * External VBUS sensing must override that and keep observation draining. */
  fake_vbus=false; fake_suspended=true; fake_ready=false;
  key(6); key(0); relay_device_task();
  unsigned reports_before=fake_count;
  assert(!fake_mounted && !fake_pullup && fake_unplugs==2);
  assert(relay_read_event(&e) && e.key==6 && !relay_read_event(&e));
  assert(load(&led_request)==0 && load(&fr)==load(&fw));
  /* Offline observer overflow must not fill the forwarding ring. */
  for(int n=0;n<300;n++) { key(n%2?0:4); relay_device_task(); }
  assert(load(&fr)==load(&fw) && fake_count==reports_before);
  while(relay_read_event(&e)) {}
  /* Backlog present at enumeration is observed, not replayed to PC. */
  key(7); key(0);
  fake_vbus=true; fake_mounted=true; fake_ready=true; relay_device_task();
  assert(fake_count==reports_before+3);
  assert(fake_reports[reports_before].bytes[0]==0);
  assert(relay_read_event(&e) && e.key==7 && !relay_read_event(&e));
  /* A real powered-PC suspend remains distinct from unplug. */
  fake_suspended=true; key(8); relay_device_task();
  assert(fake_wakeups==1 && fake_count==reports_before+3);
  fake_suspended=false; relay_device_task();
  assert(relay_read_event(&e) && e.key==8);
  puts("relay runtime: forwarding, standalone boot, VBUS unplug/reconnect, no replay, overflow and suspend passed");
}
