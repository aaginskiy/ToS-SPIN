interface SpinIF{
  async command void sendClockSync();
  
  async command void sendStat();
  command void start();
  async command void send(spin_msg_t* payload, uint8_t len);
  
  event bool isNeeded(uint8_t pid);
  event void startDone(error_t error);
  event void sendDone(spin_msg_t* bufPtr, error_t error);
  event void receivedRequested(spin_msg_t* bufPtr);
  event void receivedStat(uint32_t stat, uint16_t nid);
}
