#!/usr/bin/python
    #
# Copyright (c) 2007 Toilers Research Group - Colorado School of Mines
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of Toilers Research Group - Colorado School of 
#   Mines  nor the names of its contributors may be used to endorse 
#   or promote products derived from this software without specific
#   prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
# UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#*
# Author: Chad Metcalf
# Date: July 9, 2007
#
# A simple TOSSIM driver for the TestSerial application that utilizes 
# TOSSIM Live extensions.
#
import sys
import time

from TOSSIM import *
from SerialMsg import *

t = Tossim([])
m = t.mac()
r = t.radio()
sf = SerialForwarder(9001)
throttle = Throttle(t, 10)

t.addChannel("Serial", sys.stdout);
t.addChannel("SpinTestC", sys.stdout);

t.addChannel("Boot", sys.stdout);

f = open("topo.txt", "r")
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

noise = open("meyer-heavy.txt", "r")
lines = noise.readlines()
for line in lines:
  str1 = line.strip()
  if (str1 != ""):
    val = int(str1)
    for i in range(1, 4):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 4):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

for i in range(1, 4):
  m = t.getNode(i);
  m.bootAtTime((31 + t.ticksPerSecond() / 10) * i + 1);

sf.process();

for i in range(0, 60):
  t.runNextEvent();
  sf.process();

msg = SerialMsg()
msg.set_cmd(2);

serialpkt = t.newSerialPacket();
serialpkt.setData(msg.data)
serialpkt.setType(msg.get_amType())
serialpkt.setDestination(1)
serialpkt.deliver(1, t.time() + 3)

pkt = t.newPacket();
pkt.setData(msg.data)
pkt.setType(msg.get_amType())
pkt.setDestination(0)
#pkt.deliver(0, t.time() + 10)

for i in range(0, 6000):
  t.runNextEvent();
  sf.process();
