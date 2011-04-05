#include "Spin.h"
configuration SpinC {
  provides interface SpinIF;
}

implementation {
  components SpinP;
  
  components ActiveMessageC as Radio;
  components LocalTimeMilliC as LT;
  
  components RandomC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  
  components new TimerMilliC() as Timer2;
  
  SpinIF = SpinP;
  
  SpinP.RadioControl -> Radio;
  SpinP.RadioSend -> Radio;
  SpinP.RadioReceive -> Radio.Receive;
  SpinP.RadioSnoop -> Radio.Snoop;
  SpinP.RadioPacket -> Radio;
  SpinP.RadioAMPacket -> Radio;
  
  
  SpinP.Random -> RandomC;
  
  
  SpinP.MilliTimer -> Timer0;
  SpinP.WatchDog -> Timer1;
  SpinP.RequestTimer -> Timer2;
  
  
  
  SpinP.LocalTime -> LT;
}
