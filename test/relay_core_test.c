#include "relay_core.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static const uint8_t boot[]={
  0x05,1,0x09,6,0xa1,1,0x05,7,0x19,224,0x29,231,0x15,0,0x25,1,
  0x75,1,0x95,8,0x81,2,0x75,8,0x95,1,0x81,1,
  0x05,8,0x19,1,0x29,5,0x75,1,0x95,5,0x91,2,0x75,3,0x95,1,0x91,1,
  0x05,7,0x19,0,0x29,101,0x75,8,0x95,6,0x81,0,0xc0};
int main(void) {
  relay_layout l; relay_state s; uint8_t out[64];
  assert(relay_parse(&l,boot,sizeof(boot)));
  uint8_t report[]={2,0,4,5,6,0,0,0};
  assert(relay_decode(&l,report,8,&s));
  assert(s.keys[0]==0x70 && s.keys[28]==2);
  relay_boot_report(&s,out); assert(!memcmp(report,out,8));
  assert(relay_led_report(&l,0,3,out)==1 && out[0]==3);
  assert(!relay_decode(&l,report,7,&s));
  report[2]=1; assert(!relay_decode(&l,report,8,&s));
  uint8_t nkro[]={0x05,7,0x19,0,0x2a,255,0,0x75,1,0x96,0,1,0x81,2};
  assert(relay_parse(&l,nkro,sizeof(nkro)));
  uint8_t bitmap[32]={0}; bitmap[0]=0xf0; bitmap[1]=7; bitmap[28]=1;
  assert(relay_decode(&l,bitmap,32,&s));
  assert(!memcmp(s.keys,bitmap,32));
  relay_boot_report(&s,out); assert(out[0]==1 && out[2]==1 && out[7]==1);
  uint8_t consumer[]={0x05,12,0x85,3,0x19,0,0x2a,255,3,0x75,16,0x95,2,0x81,0};
  assert(relay_parse(&l,consumer,sizeof(consumer)));
  uint8_t media[]={3,0xe9,0,0xea,0};
  assert(relay_decode(&l,media,5,&s)); assert(s.consumer[0]==0xe9 && s.consumer[1]==0xea);
  media[0]=4; assert(!relay_decode(&l,media,5,&s));
  uint8_t indexed[]={0x05,12,0x09,0xe9,0x09,0xea,0x15,0,0x25,1,0x75,8,0x95,1,0x81,0};
  assert(relay_parse(&l,indexed,sizeof(indexed)));
  assert(relay_decode(&l,(uint8_t[]){0},1,&s)); assert(s.consumer[0]==0xe9);
  uint8_t bad[]={0x75,1,0x96,255,255,0x81,2}; assert(!relay_parse(&l,bad,sizeof(bad)));
  assert(!relay_parse(&l,boot,3));
  assert(!relay_parse(&l,(uint8_t[]){0xb4},1));
  /* Deterministic malformed descriptor fuzzing, run under ASan/UBSan. */
  uint32_t seed=1; uint8_t fuzz[128];
  for(int k=0;k<10000;k++) {
    for(int j=0;j<128;j++) { seed=seed*1664525+1013904223; fuzz[j]=seed>>24; }
    if(relay_parse(&l,fuzz,k%128)) relay_decode(&l,fuzz,64,&s);
  }
  puts("relay core: boot/NKRO/media/LED/bounds and 10000 fuzz cases passed");
}
