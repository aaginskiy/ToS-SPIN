#include "Timer.h"
#include "SpinTest.h"
#include "Spin.h"

module SpinTestC @safe() {
  uses {
    interface Leds;
    interface Boot;
    interface Timer<TMilli> as MilliTimer;
    interface Timer<TMilli> as Time;
    interface Timer<TMilli> as ResetWant;
    interface LocalTime<TMilli> as LocalTime;
    
    // Serial
    interface SplitControl as SerialControl;
    interface Receive as SerialReceive;
    interface AMSend as SerialAMSend;
    interface Packet as SerialPacket;
    interface Random;
    
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
  uint32_t startTime = 0;
  
    spin_msg_t radio;
    
  message_t sermes;
  
  event void Boot.booted() {
    dbg("SpinTestC", "SpinTestC: node %hu booted successfully at time %i.\n", TOS_NODE_ID, call LocalTime.get());
    call SerialControl.start();
    call Spin.start();
    if (TOS_NODE_ID == 1) {
     wantPacket = 0;
      call Leds.set(5);
    } else {
      call Leds.set(1);
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
    atomic
      startTime = call LocalTime.get();
    dbg("Stat", "Start: time = %i.\n", radio.pid, call LocalTime.get());
    call Spin.send(&radio, sizeof(spin_msg_t));
  }
  
  event void ResetWant.fired() {
    wantPacket = 1;
    call Leds.set(0);
  }
  
  event void Time.fired() {
    dbg("SpinTestC", "SpinTestC: STAT Timer fired.\n");
    call Spin.sendStat();
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
    dbg("SpinTestC", "SpinTestC: Spin procedure finished.\n");
  }
  
  event void Spin.receivedRequested(spin_msg_t* bufPtr) {
    int delay;
    delay = call Random.rand16() & 0x200;
    wantPacket = 0;
    
    call Leds.set(7);
    
    call ResetWant.startOneShot(5120);
    
    call Time.startOneShot(2048+delay);
    dbg("SpinTestC", "SpinTestC: Received the requested packet.\n");
  }
  
  event void Spin.receivedStat(uint32_t stat, uint16_t nid) {
    message_t* msg;
    serial_msg_t* serialrcm;
    msg = &sermes;
    
    dbg("SpinTestC", "Received stat from nid = %i\n", nid);

    
    serialrcm = (serial_msg_t*)call SerialPacket.getPayload(msg, sizeof(serial_msg_t));
    if (serialrcm == NULL) {
      return;
    }
    atomic
      serialrcm->time = stat - startTime;
    serialrcm->nid = nid;
    
    
    if (call SerialAMSend.send(AM_BROADCAST_ADDR, msg, sizeof(serial_msg_t)) == SUCCESS) {
      //dbg("SpinTestC", "Serial sent.\n");	
      atomic
        locked = TRUE;
    }
  }
  
  event bool Spin.isNeeded(uint8_t pid) {
    if (wantPacket == 1) {
      return TRUE;
    } else {
      return FALSE;
    }
  }
}
