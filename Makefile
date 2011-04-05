COMPONENT=SpinTestAppC
BUILD_EXTRA_DEPS = RadioMsg.py RadioMsg.class SerialMsg.py SerialMsg.class
CLEAN_EXTRA = RadioMsg.py RadioMsg.class RadioMsg.java SerialMsg.py SerialMsg.class SerialMsg.java SerialMsg.pyc

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

