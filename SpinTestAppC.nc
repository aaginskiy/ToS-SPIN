#include "SpinTest.h"

configuration SpinTestAppC {}
implementation {
  components MainC, SpinTestC as App, LedsC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components LocalTimeMilliC as LT;
  components SpinC;
  
  
  // Serial
  components SerialActiveMessageC as AM;
  
  App.Boot -> MainC.Boot;
  
  App.Leds -> LedsC;
  App.MilliTimer -> Timer0;
  App.Time -> Timer1;
  App.LocalTime -> LT;
  App.Spin -> SpinC;
  
  // Serial
  App.SerialControl -> AM;
  App.SerialReceive -> AM.Receive[AM_SERIAL_MSG];
  App.SerialAMSend -> AM.AMSend[AM_SERIAL_MSG];
  App.SerialPacket -> AM;
}


