#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#define GPIO_OUT 1
#define GPIO_IN 0
#define HID_PROTOCOL_BOOT 0
#define HID_PROTOCOL_REPORT 1
#define HID_REPORT_TYPE_INPUT 1
#define HID_REPORT_TYPE_OUTPUT 2
#define TUH_CFGID_RPI_PIO_USB_CONFIGURATION 1
typedef int hid_report_type_t;
typedef struct { uint8_t pin_dp, tx_ch; } pio_usb_configuration_t;
#define PIO_USB_DEFAULT_CONFIG {0,0}
static uint32_t fake_ms;
static bool fake_mounted=true, fake_ready=true;
static unsigned fake_count;
static struct { uint8_t instance,id,bytes[64]; unsigned len; } fake_reports[2048];
static inline uint32_t get_absolute_time(void) { return fake_ms; }
static inline uint32_t to_ms_since_boot(uint32_t t) { return t; }
static inline int dma_claim_unused_channel(bool required) { (void)required; return 0; }
static inline void tuh_configure(int p,int id,void *c) { (void)p;(void)id;(void)c; }
static inline void tuh_hid_set_default_protocol(int p) { (void)p; }
static inline void tuh_init(int p) { (void)p; }
static inline void tuh_task(void) {}
static inline void gpio_init(int p) { (void)p; }
static inline void gpio_set_dir(int p,int d) { (void)p;(void)d; }
static inline void gpio_put(int p,int v) { (void)p;(void)v; }
static inline void gpio_pull_up(int p) { (void)p; }
static inline bool gpio_get(int p) { (void)p; return true; }
static inline bool tuh_hid_receive_ready(int a,int i) { (void)a;(void)i; return true; }
static inline bool tuh_hid_receive_report(int a,int i) { (void)a;(void)i; return true; }
static inline bool tuh_hid_set_report(int a,int i,int id,int t,void *p,int n) {
  (void)a;(void)i;(void)id;(void)t;(void)p;(void)n;return true;
}
static inline void tight_loop_contents(void) {}
static inline void multicore_launch_core1_with_stack(void (*f)(void),uint32_t *s,size_t n) { (void)f;(void)s;(void)n; }
static inline bool tud_mounted(void) { return fake_mounted; }
static inline bool tud_suspended(void) { return false; }
static inline void tud_remote_wakeup(void) {}
static inline bool tud_hid_n_ready(int i) { (void)i;return fake_ready; }
static inline bool tud_hid_n_report(uint8_t i,uint8_t id,const void *p,unsigned n) {
  if(!fake_ready) return false;
  fake_reports[fake_count].instance=i;fake_reports[fake_count].id=id;
  fake_reports[fake_count].len=n;
  for(unsigned j=0;j<n;j++) fake_reports[fake_count].bytes[j]=((const uint8_t*)p)[j];
  fake_count++;
  return true;
}
static inline uint32_t save_and_disable_interrupts(void) { return 0; }
static inline void restore_interrupts(uint32_t f) { (void)f; }
