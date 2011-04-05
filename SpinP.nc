// $Id: LedsP.nc,v 1.6 2008/06/24 05:32:32 regehr Exp $

/*
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 */

/**
 * The implementation of the standard 3 LED mote abstraction.
 *
 * @author Joe Polastre
 * @author Philip Levis
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
  
  // Depth 1 Queue
  message_t radioQueue;
  spin_msg_t spinQueue;
  
  message_t* ONE receive(am_id_t id, message_t* ONE msg, void* payload, uint8_t len);
  void advertise();
  void request();
  
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
      //dbg("Spin", "Spin: Clock 'SYNC' packet sent with content = %hu.\n", radiorcm->cnt);	
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
      //dbg("Spin", "Spin: 'ADV' packet sent with content = %hu.\n", radiorcm->cnt);  
      call WatchDog.startOneShot(256);
      //dbg("Spin", "Spin: Watchdog timer started on pid = %i.\n", currentPid);		
      atomic
        radioBusy = TRUE;
    }
  }
  
  void request() {
    uint16_t delay;
    delay = call Random.rand16() & 0x32;
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
      //dbg("Spin", "Spin: 'REQ' packet sent with content = %hu.\n", currentPid);	
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
      //dbg("Spin", "Spin: Sending my packet of pid = %i.\n", radiorcm->pid);	
      atomic
        radioBusy = TRUE;
    }
  }
  
  async command void SpinIF.send(spin_msg_t* payload, uint8_t len) {
    message_t* msg;
    atomic {
      spinTransmitting = TRUE;
      currentPid = payload->pid;
    }
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
    dbg("Spin", "Spin: Initialized by SpinIF.start().\n");	
    call RadioControl.start();
  }
  
  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      dbg("Spin", "Spin: Started successfully.\n");
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
    message_t *ret = msg;
    uint16_t delay;
    bool need;
    
    id = call RadioAMPacket.type(msg);
    //dbg("Spin", "Spin: Received packet of am_id = %hu.\n", id);

    if (id == AM_SPIN_META_MSG && len == sizeof(spin_meta_msg_t)) { 
      spin_meta_msg_t* rcm = (spin_meta_msg_t*)payload;
      if (rcm->type == SPIN_CMD_SYNC && syncedBefore == FALSE) {
        //dbg("Spin", "Spin: Received a META packet of type CLOCK RESYNC ('SYNC').\n");
        atomic {
          clockphase = call LocalTime.get() - rcm->cnt;
          syncedBefore = TRUE;
        }
        dbg("Spin", "Spin: Clock synced to phase = %i.\n", clockphase);
        delay = call Random.rand16() & 0x32;
        call MilliTimer.startOneShot(delay);
        //dbg("Spin", "Spin: Forwarding CLOCK RESYNC ('SYNC') in %i ticks.\n", delay);
      } else if (rcm->type == 3) {
        //dbg("Spin", "Spin: Received a META packet of type ADVERTISE ('ADV') of type %i.\n", rcm->cnt);
        need = signal SpinIF.isNeeded(rcm->cnt);
        if (requestedPid != rcm->cnt && need == TRUE) {
          currentPid = rcm->cnt;
          dbg("Spin", "Spin: Packet of pid = %i is needed by mote nid = %i.\n", currentPid, TOS_NODE_ID);
          requestedPid = currentPid;
          request();
        }
      } else if (rcm->type == 4) {
        
        if (advertisedPid == rcm->cnt) {	
          //dbg("Spin", "Spin: Someone wants my packet of pid = %i.\n", rcm->cnt);
          call WatchDog.stop();
          sendData();
        } else if (requestedPid == rcm->cnt){
          //dbg("Spin", "Spin: Received REQ, no need to send personal REQ.\n");
          call RequestTimer.stop();
        }
        
      }
    } else if (id == AM_SPIN_MSG && len == sizeof(spin_msg_t)) {
      spin_msg_t* rcmt = (spin_msg_t*)payload;
      atomic
        spinQueue = *rcmt;
     if (spinQueue.pid > 0 && spinQueue.pid == requestedPid) {
        requestedPid = 0;
        receivedTime = call LocalTime.get() - clockphase;
        dbg("Spin", "Spin: Received DATA packet of pid = %i at time = %i.\n", spinQueue.pid, receivedTime);
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
    //dbg("Spin", "Spin: Spin timed out while sending message. Maybe resend?\n");
  }
  
}
