#ifndef SPIN_TEST_H
#define SPIN_TEST_H

typedef nx_struct radio_msg {
  nx_uint16_t counter;
  nx_uint16_t nid;
  nx_uint16_t pid;
  nx_uint16_t type;
  nx_uint16_t cnt[8];
} radio_msg_t;

typedef nx_struct serial_msg {
  nx_uint16_t cmd;
} serial_msg_t;

enum {
  AM_RADIO_MSG = 6,
  AM_SERIAL_MSG = 0x89,
};


#endif
