/**
 * The implementation of the SPIN protocol.
 *
 * @author Artem Aginskiy
 *
 * @date   March 21, 2005
 */

module SpinP @safe() {
  provides {
    interface SpinIF;
  }
  uses {
    interface SplitControl as RadioControl;
    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];
    interface Timer<TMilli> as MilliTimer;
    interface Timer<TMilli> as WatchDog;
    interface Timer<TMilli> as RequestTimer;
    interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;
    
    interface Random;
    
    interface LocalTime<TMilli> as LocalTime;
  }
}
implementation {
  bool       radioBusy, radioFull;
  uint8_t count = 0;
  int16_t clockphase = 0;
  
  uint16_t currentPid = 0;
  uint16_t requestedPid = 0;
  uint16_t advertisedPid = 0;
  bool        syncedBefore = FALSE;
  bool        spinTransmitting = FALSE;
  uint16_t receivedTime = 0;
  uint32_t statCache[8]={0};
  uint8_t cacheInd=0;
  
  // Depth 1 Queue
  message_t radioQueue;
  spin_msg_t spinQueue;
  
  message_t* ONE receive(am_id_t id, message_t* ONE msg, void* payload, uint8_t len);
  void advertise();
  void request();
  uint16_t globalTime();
  
  uint16_t globalTime() {
      return call LocalTime.get() - clockphase;
  }
  
  // Initialize Clock Sync across the network using flooding
  // The calling node becomes global time
  async command void SpinIF.sendClockSync() {
    message_t* msg;
    spin_meta_msg_t* radiorcm;
    msg = &radioQueue;
    
    radiorcm = (spin_meta_msg_t*)call RadioPacket.getPayload(msg, sizeof(spin_meta_msg_t));
    if (radiorcm == NULL) {
      return;
    }
    atomic
    {
      radiorcm->cnt = call LocalTime.get() - clockphase; 
    }
    radiorcm->type = 2;
    
    if (call RadioSend.send[AM_SPIN_META_MSG](AM_BROADCAST_ADDR, msg, sizeof(spin_meta_msg_t)) == SUCCESS) {
      dbg("Spin", "<%i>: 'SYNC' packet sent with content = %hu.\n", globalTime(), radiorcm->cnt);	
      atomic
        radioBusy = TRUE;
    }
  }
  
  async command void SpinIF.sendStat() {
    message_t* msg;
    spin_meta_msg_t* radiorcm;
    msg = &radioQueue;
    
    syncedBefore = FALSE;
    
    dbg("Spin2", "sendStat()\n");
    
    radiorcm = (spin_meta_msg_t*)call RadioPacket.getPayload(msg, sizeof(spin_meta_msg_t));
    if (radiorcm == NULL) {
      return;
    }
    atomic
    {
      radiorcm->cnt = receivedTime; 
    }
    radiorcm->type = 5;
    radiorcm->nid = TOS_NODE_ID;
    
    if (call RadioSend.send[AM_SPIN_META_MSG](AM_BROADCAST_ADDR, msg, sizeof(spin_meta_msg_t)) == SUCCESS) {
      dbg("Spin2", "<%i>: 'SYNC' packet sent with type = %hu.\n", globalTime(), radiorcm->type);	
      atomic
        radioBusy = TRUE;
    }
  }
  
  void advertise() {
    message_t* msg;
    spin_meta_msg_t* radiorcm;
    msg = &radioQueue;
    
    radiorcm = (spin_meta_msg_t*)call RadioPacket.getPayload(msg, sizeof(spin_meta_msg_t));
    if (radiorcm == NULL) {
      return;
    }
    atomic
    {
      radiorcm->cnt = spinQueue.pid; 
      advertisedPid = spinQueue.pid;
    }
    radiorcm->type = 3;
    
    if (call RadioSend.send[AM_SPIN_META_MSG](AM_BROADCAST_ADDR, msg, sizeof(spin_meta_msg_t)) == SUCCESS) {
      dbg("Spin", "SPIN <%i>: 'ADV' packet sent with content = %hu.\n", globalTime(), radiorcm->cnt);  
      call WatchDog.startOneShot(256);
      dbg("Spin", "SPIN <%i>: Watchdog timer started on pid = %i.\n", globalTime(), currentPid);		
      atomic
        radioBusy = TRUE;
    }
  }
  
  void request() {
    uint16_t delay;
    delay = call Random.rand16() & 0x32;
    dbg("Spin", "SPIN <%i>: Plan to request packet of pid = 1, %i ticks later.\n", globalTime(), currentPid, delay);
    call RequestTimer.startOneShot(delay);
  }  
  
  event void RequestTimer.fired () {
    message_t* msg;
    spin_meta_msg_t* radiorcm;
    msg = &radioQueue;
    
    radiorcm = (spin_meta_msg_t*)call RadioPacket.getPayload(msg, sizeof(spin_meta_msg_t));
    if (radiorcm == NULL) {
      return;
    }
    atomic
    {
      radiorcm->cnt = currentPid; 
    }
    radiorcm->type = 4;
    
    if (call RadioSend.send[AM_SPIN_META_MSG](AM_BROADCAST_ADDR, msg, sizeof(spin_meta_msg_t)) == SUCCESS) {
      dbg("Spin", "SPIN <%i>: 'REQ' packet sent with pid = %hu.\n", globalTime(), currentPid);	
      atomic
        radioBusy = TRUE;
    }
  }
  
  void sendData() {
    spin_msg_t* radiorcm;
    
    radiorcm = (spin_msg_t*)call RadioPacket.getPayload(&radioQueue, sizeof(spin_msg_t));
    if (radiorcm == NULL) {
      return;
    }
    atomic
    {
      *radiorcm = spinQueue;
    }
    
    if (call RadioSend.send[AM_SPIN_MSG](AM_BROADCAST_ADDR, &radioQueue, sizeof(spin_msg_t)) == SUCCESS) {
      dbg("Spin", "SPIN <%i>: Sending my packet of pid = %i.\n", globalTime(), radiorcm->pid);	
      atomic
        radioBusy = TRUE;
    }
  }
  
  async command void SpinIF.send(spin_msg_t* payload, uint8_t len) {
    atomic {
      spinTransmitting = TRUE;
      currentPid = payload->pid;
    }
    atomic
      spinQueue = *payload;
    advertise();
  }
  
  command void SpinIF.start() {
    atomic {
      radioBusy = FALSE;
      radioFull = TRUE;
      if (TOS_NODE_ID == 1)
        syncedBefore = TRUE;
    }
    dbg("Spin", "SPIN: Initialized by SpinIF.start().\n");	
    call RadioControl.start();
  }
  
  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      dbg("Spin", "SPIN: Started successfully.\n");
      radioFull = FALSE;
    }
    signal SpinIF.startDone(error);
  }

  event void RadioControl.stopDone(error_t error) {}
  
  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg, void *payload, uint8_t len) {
    return receive(id, msg, payload, len);
  }
  
  event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return receive(id, msg, payload, len);
  }
  
  message_t* receive(am_id_t id, message_t *msg, void *payload, uint8_t len) {
    uint16_t delay;
    bool need;
    
    id = call RadioAMPacket.type(msg);
    //dbg("Spin", "SPIN <%i>: Received packet of am_id = %hu.\n", globalTime(), id);

    if (id == AM_SPIN_META_MSG && len == sizeof(spin_meta_msg_t)) { 
      spin_meta_msg_t* rcm = (spin_meta_msg_t*)payload;
      
      if (rcm->type == SPIN_CMD_SYNC && syncedBefore == FALSE) {
        dbg("Spin", "SPIN: Received a META packet of type CLOCK RESYNC ('SYNC').\n");
        atomic {
          clockphase = call LocalTime.get() - rcm->cnt;
          syncedBefore = TRUE;
        }
        dbg("Spin", "SPIN <%i>: Clock synced to phase = %i.\n", globalTime(), clockphase);
        delay = call Random.rand16() & 0x32;
        call MilliTimer.startOneShot(delay);
        dbg("Spin", "SPIN <%i>: Forwarding CLOCK RESYNC ('SYNC') in %i ticks.\n", globalTime(), delay);
      } else if (rcm->type == 3) {
        dbg("Spin", "SPIN <%i>: Received a META packet of type ADVERTISE ('ADV') of type %i.\n", globalTime(), rcm->cnt);
        need = signal SpinIF.isNeeded(rcm->cnt);
        if (requestedPid != rcm->cnt && need == TRUE) {
          atomic
            currentPid = rcm->cnt;
          dbg("Spin", "SPIN <%i>: Packet of pid = %i is needed by mote nid = %i.\n", globalTime(), currentPid, TOS_NODE_ID);
          requestedPid = currentPid;
          request();
        }
      } else if (rcm->type == 4) {
        if (advertisedPid == rcm->cnt) {	
          dbg("Spin", "SPIN <%i>: Someone wants my packet of pid = %i.\n", globalTime(), rcm->cnt);
          call WatchDog.stop();
          sendData();
        } else if (requestedPid == rcm->cnt){
          dbg("Spin", "SPIN <%i>: Received REQ, no need to send personal REQ.\n", globalTime());
          call RequestTimer.stop();
        }
      } else if (rcm->type == 5) {
        uint32_t hash;
        uint8_t forward = 0;
        uint8_t i = 0;
        hash = (rcm->nid << 16) + rcm->cnt;
        if (TOS_NODE_ID != 1) {
          for (i = 0; i < 8; i++) {
            if (statCache[i] == hash) {
              forward++;
            }
          }
          
          if (forward == 0){
            statCache[cacheInd] = hash;
            cacheInd++;
            if (cacheInd > 7) {
              cacheInd = 0;
            }
            dbg("Spin2", "GOT IT <%i>, %i, %i\n", hash, forward, rcm->nid);       
            if (call RadioSend.send[AM_SPIN_META_MSG](AM_BROADCAST_ADDR, msg, sizeof(spin_meta_msg_t)) == SUCCESS) {
              dbg("Spin2", "<%i>: 'SYNC' packet sent.\n", globalTime());	
              atomic
                radioBusy = TRUE;
            }   
          } else {
            dbg("Spin2", "%i %i %i %i %i %i %i %i\n", statCache[0], statCache[1], statCache[2], statCache[3], statCache[4], statCache[5], statCache[6], statCache[7], statCache[8]);
        
          }
        } else {
          //dbg("SpinTestC", "hi");
          signal SpinIF.receivedStat(rcm->cnt, rcm->nid);
        }
      }
    } else if (id == AM_SPIN_MSG && len == sizeof(spin_msg_t)) {
      spin_msg_t* rcmt = (spin_msg_t*)payload;
      uint16_t pid;
      atomic {
        spinQueue = *rcmt;
        pid = spinQueue.pid;
      }
      if (pid > 0 && pid == requestedPid) {
        requestedPid = 0;
        receivedTime = call LocalTime.get() - clockphase;
        dbg("Spin", "SPIN <%i>: Received DATA packet of pid = %i.\n", receivedTime, spinQueue.pid);
        signal SpinIF.receivedRequested(&spinQueue);
        advertise();
      }
    }
    return msg;
  }
  
  event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (msg == &radioQueue)
	  {
      radioFull = FALSE;
      if (id == AM_SPIN_MSG) {
        
        signal SpinIF.sendDone(&spinQueue, error);
      }
	  }
  }
  
  event void MilliTimer.fired() {
    call SpinIF.sendClockSync();
  }
  
  event void WatchDog.fired() {
    dbg("Spin", "SPIN <%i>: Spin timed out while sending message. Maybe resend?\n", globalTime());
  }
  
}
