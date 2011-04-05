#include "Timer.h"
#include "SpinTest.h"
#include "Spin.h"

module SpinTestC @safe() {
  uses {
    interface Leds;
    interface Boot;
    interface Timer<TMilli> as MilliTimer;
    interface Timer<TMilli> as Time;
    interface LocalTime<TMilli> as LocalTime;
    
    // Serial
    interface SplitControl as SerialControl;
    interface Receive as SerialReceive;
    interface AMSend as SerialAMSend;
    interface Packet as SerialPacket;
    
    // Spin
    interface SpinIF as Spin;
  }
}

implementation {

  message_t packet;

  bool locked;
  uint16_t counter = 0;
  uint16_t syncounter = 0;
  bool wantPacket = 1;
  
    spin_msg_t radio;
  
  event void Boot.booted() {
    dbg("SpinTestC", "SpinTestC: node %hu booted successfully at time %i.\n", TOS_NODE_ID, call LocalTime.get());
    call SerialControl.start();
    call Spin.start();
    if (TOS_NODE_ID == 1) {
     wantPacket = 0;
    }
  }
  
  event void Spin.startDone(error_t err) {
    
  }
  event void MilliTimer.fired() {
    //spin_msg_t* radiorcm;
    radio.pid = 1;
    radio.nid = 3;
    //radiorcm->pid = 1;
    dbg("SpinTestC", "SpinTestC: Sending data packet from event with pid = %i at time = %i.\n", radio.pid, call LocalTime.get());
    call Spin.send(&radio, sizeof(spin_msg_t));
  }
  
  event void Time.fired() {
    dbg("SpinTestC", "SpinTestC: LocalTime is  %hu.\n", call LocalTime.get());
  }
  
  // Serial
  event void SerialControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg("SpinTestC", "SpinTestC: UART booted successfully.\n");
    }
    else {
      call SerialControl.start();
    }
  }
  event void SerialControl.stopDone(error_t err) {}
  
  event message_t* SerialReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    dbg("SpinTestC", "SpinTestC: Received serial packet of length %hhu.\n", len);
    if (len == sizeof(serial_msg_t)) {
      serial_msg_t* rcm = (serial_msg_t*)payload;
      if (rcm->cmd == 2) {
        syncounter = 0;
        dbg("SpinTestC", "SpinTestC: Received SYNC command %hhu.\n", rcm->cmd);
        if (TOS_NODE_ID == 1) {
          call Spin.sendClockSync();
          }
        call MilliTimer.startOneShot(2048);
      }
    }
    return bufPtr;
  }
  
  event void SerialAMSend.sendDone(message_t* bufPtr, error_t error) {}
  event void Spin.sendDone(spin_msg_t* bufPtr, error_t error) {
    if (bufPtr == &radio)
	  {
        dbg("SpinTestC", "SpinTestC: Spin procedure finished.\n");
	  }
  }
  
  event void Spin.receivedRequested(spin_msg_t* bufPtr) {
    wantPacket = 0;
    
    //dbg("SpinTestC", "SpinTestC: wantPacket = %i .\n", wantPacket);
  }
  
  event bool Spin.isNeeded(uint8_t pid) {
    if (wantPacket == 1) {
      return TRUE;
    } else {
      return FALSE;
    }
  }
}
