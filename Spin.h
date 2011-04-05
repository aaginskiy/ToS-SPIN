#ifndef SPIN_H
#define SPIN_H

typedef nx_struct spin_msg {
  nx_uint16_t counter;
  nx_uint16_t nid;
  nx_uint16_t pid;
  nx_uint16_t type;
  nx_uint16_t cnt;  // Change this to carry the right amount of data
} spin_msg_t;

typedef nx_struct spin_meta_msg {
  nx_uint16_t type;
  nx_uint16_t cnt;
} spin_meta_msg_t;

enum {
  AM_SPIN_META_MSG = 0x61,
  AM_SPIN_MSG = 0x62,
  SPIN_CMD_SYNC = 2,
};
#endif
