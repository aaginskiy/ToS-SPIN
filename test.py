#! /usr/bin/python
from TOSSIM import *
from SerialMsg import *
import sys
import time

t = Tossim([])
m = t.mac()
r = t.radio()


sf = SerialForwarder(9001)
throttle = Throttle(t, 10)

f = open("topo.txt", "r")

lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("SpinTestC", sys.stdout)
t.addChannel("Spin", sys.stdout)

noise = open("meyer-heavy-simple.txt", "r")
lines = noise.readlines()
for line in lines:
  str1 = line.strip()
  if (str1 != ""):
    val = int(str1)
    for i in range(1, 8):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 8):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

t.getNode(1).bootAtTime(100001);
t.getNode(2).bootAtTime(800008);
t.getNode(3).bootAtTime(180000900);
t.getNode(4).bootAtTime(800008);
t.getNode(5).bootAtTime(280000900);
t.getNode(6).bootAtTime(800008);
t.getNode(7).bootAtTime(280000900);

sf.process();
throttle.initialize();

for i in range(0, 60):
  throttle.checkThrottle();
  t.runNextEvent();
  sf.process();

msg = SerialMsg()
msg.set_cmd(2);

serialpkt = t.newSerialPacket();
serialpkt.setData(msg.data)
serialpkt.setType(msg.get_amType())
serialpkt.setDestination(1)
serialpkt.deliver(1, t.time() + 10)

for i in range(0, 500):
  throttle.checkThrottle();
  t.runNextEvent();
  sf.process();

throttle.printStatistics()
