//read EEG at 512 Hz from TGAM1 board and output in real time
//over NANO serial port.

//LED constants
const byte DISCONNECTED_LED = D2;
const byte POORSIGNAL_LED = D3;
const byte GOODSIGNAL_LED = D4; 
const byte ERPMODE_PIN = D8;

// constants used to parse the Neurosky EEG packet
const byte SYNC = 170;
const byte EXCODE = 0x55;
const byte SIGNALQUALITY = 0x02;
const byte ATTENTION = 0x04;
const byte MEDITATION = 0x05;
const byte RAW = 0x80;
const byte POWER = 0x81;
const byte ASICPOWER = 0x83;
const uint8_t COMMANDBYTE = 0x02;

//packet decoding variables
int checksum = 0;
byte packetChecksum;
byte plength = 0;
byte payload[169];
byte value[32];

//data output or reading variables
int rawInt;
byte lowerByte;
byte upperByte;

//flags
bool gotRawValue = false;

//debug variables
int count = 0;

//packet data
byte qualityValue;
byte rawValue[2];


void setup() {
  
  pinMode(DISCONNECTED_LED, OUTPUT);
  pinMode(POORSIGNAL_LED, OUTPUT);
  pinMode(GOODSIGNAL_LED, OUTPUT);
  pinMode(ERPMODE_PIN, INPUT);

  // Start the hardware serial both for communication to the TGMA1 and the computer.
  Serial.begin(57600);
  Serial.println("trying to initialize serial");
  while (!Serial);
  Serial.println("got basics going");
  configureTGAM1();
}

void loop() {
  if (readPacket()){
    //parse the data packet
    parsePayload(payload, plength);
    
    if (gotRawValue){
      //Serial.println("got a raw value...");
       
      //comine the bites into a single 16 bit value and add 2048 to
      //get it into the positive range
      rawInt = (rawValue[0] << 8 | rawValue[1])+ 2048;
      //Serial.println(String(rawInt));
      //get the lower 7 bits and store that as a single byte
      lowerByte = rawInt & 0x7F;
      //get the next 6 bits and store that as a single byte
      upperByte = ((rawInt >> 7) & 0x1F);
      upperByte = (upperByte | 0X80);
      
      Serial.write(upperByte);
      Serial.write(lowerByte); 
     
    }

    // do other things here like changing status lights 
    //or rebuilding a new package and sending it to the PC
  }
}

// read a single byte from the UART connected to the TGAM1
byte readByte() {
  while (1) {
    if (Serial1.available()) {
      return Serial1.read();
    }
  }
}

//decode values in a single TGMA1 payload
void parsePayload(byte payLoad[], byte plength) {

  byte bytesParsed = 0;
  byte code;
  byte length;
  byte extendedCodeLevel;
  int i; 

  /* Loop until all bytes are parsed from the payload[] array... */
  while (bytesParsed < plength) {
    /* Parse the extendedCodeLevel, code, and length  of the data in the row*/
    extendedCodeLevel = 0;
    while (payload[bytesParsed] == EXCODE) {
      extendedCodeLevel++;
      bytesParsed++;
    }
    code = payload[bytesParsed++];
    // codes greater than 0x7F have a length byte after code
    //otherwise length is assumed to be 1
    if (code & 0x80) {
      length = payload[bytesParsed++];
    } else {
      length = 1;
    }

    for (i = 0; i < length; i++) {
      value[i] = payload[bytesParsed++];
    }
    //I know I should not ignore the extended code, but it is not currenbtly being used to for ease I can ignore it
    //I will add it once this code is fully debugged
    //TODO - these values will be output again to the host computer, so it is not necessary to combine bytes here.
    //but I still have to decide how to package them for transmitting back to the PC.
    //For now I might just convert the combined values to strings and print for debugging
    switch (code) {
      case SIGNALQUALITY:
        qualityValue = value[0];
        if (qualityValue==200) {
          digitalWrite(DISCONNECTED_LED, HIGH);
          digitalWrite(POORSIGNAL_LED, LOW);
          digitalWrite(GOODSIGNAL_LED, LOW);
        } else if (qualityValue > 0) {
          digitalWrite(DISCONNECTED_LED, LOW);
          digitalWrite(POORSIGNAL_LED, HIGH);
          digitalWrite(GOODSIGNAL_LED, LOW);  
        } else {
          digitalWrite(DISCONNECTED_LED, LOW);
          digitalWrite(POORSIGNAL_LED, LOW);
          digitalWrite(GOODSIGNAL_LED, HIGH);   
        }
        break;
      case ATTENTION:
        //attentionValue = value[0];
        break;
      case MEDITATION:
        //meditationValue = value[0];
        break;
      case RAW:
        rawValue[0] = value[0];
        rawValue[1] = value[1];
        //(value[0]<<8 | value[1]);
        gotRawValue = true;
        break;
      case POWER:
        break;
      case ASICPOWER:
        break;
    }
  }
 
}

// read data packets from the TGAM1
int readPacket() {
  int i;

  // this loop will continue forever unless a valid packet is found
  while (1) {
    if (readByte() != SYNC) {
      continue;
    }
    if (readByte() != SYNC) {
      continue;
    }
    do {
      plength = readByte();
    } while (plength == SYNC);

    checksum = 0;
    for (i = 0; i < plength; i++) {
      payload[i] = readByte();
      checksum += payload[i];
    }
    packetChecksum = readByte();
    checksum &= 0xFF;
    checksum = ~checksum & 0xFF;
    if (checksum != packetChecksum) {
      //TODO - include some additional error handling here
      continue;
    }
    //if things got this far then we have a good packet
    return true;
  }
}

//configures the TGAM1 to transmit raw EEG signals and
//communicate at 57600 BAUD
void configureTGAM1() {
  
  Serial1.end(); //in case it is open
  Serial1.begin(9600);
  while (!Serial1);

  //read at least one valid packet to ensure correct BAUD rate
  while (!readPacket()); 

  Serial1.write(COMMANDBYTE); 
  Serial1.flush();
 
  Serial1.begin(57600);
  while (!Serial1);
  
   //finally, wait for a single valid packet to be read
   while (!readPacket());
}