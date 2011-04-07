COMPONENT=SpinTestAppC
CC2420_CHANNEL=15
BUILD_EXTRA_DEPS = RadioMsg.py RadioMsg.class SerialMsg.py SerialMsg.class TestSerial.class
CLEAN_EXTRA = RadioMsg.py RadioMsg.class RadioMsg.java SerialMsg.py SerialMsg.class SerialMsg.java SerialMsg.pyc TestSerial.class
PYTHONPATH=/opt/tinyos-2.1.1/support/sdk/python
CLASSPATH=.:/opt/tinyos-2.1.1/support/sdk/java/tinyos.jar

TestSerial.class: $(wildcard *.java) SerialMsg.java
	javac -target 1.4 -source 1.4 *.java

RadioMsg.py: SpinTest.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=RadioMsg SpinTest.h radio_msg -o $@

SerialMsg.py: SpinTest.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=SerialMsg SpinTest.h serial_msg -o $@

RadioMsg.class: RadioMsg.java
	javac RadioMsg.java

RadioMsg.java: SpinTest.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=RadioMsg SpinTest.h radio_msg -o $@

SerialMsg.class: SerialMsg.java
	javac SerialMsg.java

SerialMsg.java: SpinTest.h
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=SerialMsg SpinTest.h serial_msg -o $@


include $(MAKERULES)

