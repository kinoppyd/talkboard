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
  relay_device_task(); /* enumerate before the first input */
  fake_count=0;
  tuh_hid_mount_cb(1,0,desc,sizeof(desc));
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
  relay_event e; assert(relay_read_event(&e) && e.key==4);
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
  tuh_hid_umount_cb(1,0); snapshot(); relay_device_task();
  assert(fake_reports[fake_count-1].bytes[2]==0);
  fake_mounted=false; relay_device_task();
  fake_mounted=true; relay_device_task();
  assert(current.keys[0]==0);
  puts("relay runtime: ordered release, retry, repeat suppression, boot, LED and observer overflow passed");
}
