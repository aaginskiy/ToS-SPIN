interface SpinIF{
  async command void sendClockSync();
  command void start();
  async command void send(spin_msg_t* payload, uint8_t len);
  
  event bool isNeeded(uint8_t pid);
  event void startDone(error_t error);
  event void sendDone(spin_msg_t* bufPtr, error_t error);
  event void receivedRequested(spin_msg_t* bufPtr);
}
