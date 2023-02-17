// WWU BNS BCI firmware for HBSpikerBox
// KJ Jantzen
// V0.1 - Feb - 2023
//
// Based on:
// Heart & Brain based on ATMEGA 328 (UNO)
// V1.0
// Made for Heart & Brain SpikerBox (V0.62)
// Backyard Brains
// Stanislav Mircic
// https://backyardbrains.com/
//
//This code has been modified to read a single analog channel and 2 digital channels at Fs=1000
//the channels combined into 3 bytes

#define CURRENT_SHIELD_TYPE "HWT:HBLEOSB;"

#define BUFFER_SIZE 100
#define SIZE_OF_COMMAND_BUFFER 30  //command buffer max size
#define PRESTIM_SAMPLES 50
#define PSTSTIM_SAMPLES 300

// defines for setting and clearing register bits
#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif

#define POWER_LED_PIN 13
#define TRIG_BIT0 9   //digital input pin 9
#define TRIG_BIT1 11  //digital input pin 11

#define ESCAPE_SEQUENCE_LENGTH 6
#define MODE_LED 4

//buffer position variables
int head = 0;  //head index for sampling circular buffer
int tail = 0;  //tail index for sampling circular buffer
int circBufferHead = 0;
int trialBufferHead = 0;

int erpTrialByteLength = (PRESTIM_SAMPLES + PSTSTIM_SAMPLES) * 2;

char commandBuffer[SIZE_OF_COMMAND_BUFFER];  //receiving command buffer
byte rawBuffer[2][BUFFER_SIZE];              //Sampling buffer
byte circBuffer[2][PRESTIM_SAMPLES];
byte trialBuffer[2][PSTSTIM_SAMPLES];
//byte erpTrial[erpTrialByteLength];


bool circBufferIsFull = false;
bool trialBufferIsFull = false;
bool haveTriggerSignal = false;
byte eventMarker = 0;

const byte MODE_CONTINUOUS = 0;
const byte MODE_TRIAL = 1;
byte collectionMode = MODE_CONTINUOUS;

//bytes for characters "trial onset" which identify erp packet
byte trialHeader[11] = { 116, 114, 105, 97, 108, 32, 111, 110, 115, 101, 116 };

/// Interrupt number - very important in combination with bit rate to get accurate data
//KJ  - the interrupt (confifgured below) will trigger an interrupt whenever the value in the timer reaches this number
//KJ - It is clear that the base clock rate (16 * 10^6) is being divided by the sameple rate to get the number of clock ticks between samples
//KJ - I am guessing that the same rate is multiplied by 8 to account for the prescaling applied below?
//KJ - I am not sure why the actual value used by BYB is 198 instead of 199
//KJ - my plan is to adjust this to get a much lower sample rate since 10000 is close to the maximum for AD conversion using analogRead
//KJ - according to https://www.arduino.cc/en/Reference/AnalogRead
//KJ - 500 or 1000 Hz sampling is more than adequate for EEG and ECG
// Output Compare Registers  value = (16*10^6) / (Fs*8) - 1  set to 1999 for 1000 Hz sampling, set to 3999 for 500 Hz sampling, set to 7999 for 250Hz sampling, 199 for 10000 Hz Sampling
int interrupt_Number = 3999;
int sampleRate = 500;

int numberOfChannels = 1;  //current number of channels sampling <-(KJ) this variable is never used
int digPin0 = 0;           //KJ - these will be used to store the digital inputs read on each sample
int digPin1 = 0;
int commandMode = 0;  //flag for command mode. Don't send data when in command mode

//SETUP function
void setup() {
  Serial.begin(115200);  //Serial communication baud rate (alt. 115200)
  while (!Serial)
  Serial.setTimeout(2);

  //KJ-set the mode of the AM modulation and power LED pints to output
  pinMode(POWER_LED_PIN, OUTPUT);
  pinMode(TRIG_BIT0, INPUT);  //setup the two digital input trigger pins
  pinMode(TRIG_BIT1, INPUT);

  //KJ-turn on the power LED
  digitalWrite(POWER_LED_PIN, HIGH);

  //on board VU meter LEDs
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
  pinMode(6, OUTPUT);
  pinMode(7, OUTPUT);
  pinMode(8, OUTPUT);

  signalMode();
  configureTimers();
  
}

void loop() {

  checkForCommands();
  while (head != tail && commandMode != 1)  //While there are data in sampling buffer waiting
  {
    if (collectionMode == MODE_CONTINUOUS) {

      //initiate seperate conditions for continuous and single trial mode
      Serial.write(rawBuffer[0][tail]);
      Serial.write(rawBuffer[1][tail]);

      //Move tail for one byte

    } else if (collectionMode == MODE_TRIAL) {
      //get this code from the other working version
      if (trialBufferIsFull) {
        //send the trial package
        compileAndSendTrial();
        resetTrialBuffers();
      } else {
        if (haveTriggerSignal && circBufferIsFull) {
          trialBuffer[0][trialBufferHead] = rawBuffer[0][tail];
          trialBuffer[1][trialBufferHead] = rawBuffer[1][tail];
          trialBufferHead++;
          if (trialBufferHead == PSTSTIM_SAMPLES){
            trialBufferIsFull = true;
          }
        } else {
          circBuffer[0][circBufferHead] = rawBuffer[0][tail];
          circBuffer[1][circBufferHead] = rawBuffer[1][tail];
          
          //check for an event marker
          if (circBufferIsFull) {
            haveTriggerSignal = checkForEventMarker(circBuffer[0][circBufferHead]);
          }
          circBufferHead++;
          if (circBufferHead == PRESTIM_SAMPLES) {
            circBufferIsFull = true;
            circBufferHead = 0;
          }

          //add to the circular buffer
        }
      }
    }
    //advance the reading location for the raw data buffer
    tail++;
    if (tail >= BUFFER_SIZE) {
      tail = 0;
    }
  }
}

//check to see if the current sample has an event marker
bool checkForEventMarker(byte sample){
  bool returnVal = false;
  eventMarker = (sample & 96) >> 5;
  if (eventMarker > 0){
    returnVal = true;
  }
  return returnVal;
}

//this is the callback function called when the interrupt fires
ISR(TIMER1_COMPA_vect) {

  //Put samples in sampling buffer "rawBuffer". Since Arduino UNO has 10bit ADC we will split every sample to 2 bytes
  //First byte will contain 3 most significant bits and second byte will contain 7 least significat bits.
  //First bit in all byte will not be used for data but for marking begining of the frame of data (array of samples from N channels)
  //Only first byte in frame will have most significant bit set to 1

  //Sample first channel and put it into buffer
  int tempSample = analogRead(A0);

  digPin0 = digitalRead(TRIG_BIT0);
  digPin1 = digitalRead(TRIG_BIT1);
  int digEvent = (digPin1 << 1) + digPin0;

  //write the samples to the LEDs
  digitalWrite(2, digPin0);
  digitalWrite(3, digPin1);

  //shift the upper byte to the right, set the MSB to high and add in the event marker
  rawBuffer[0][head] = (tempSample >> 7) | 0x80 | (digEvent << 5);
  rawBuffer[1][head] = tempSample & 0x7F;  //KJ - using the decimal 127 here as a mask to include only the lower 7 bits
  head += 1;
  if (head == BUFFER_SIZE) {
    head = 0;
  }
}

void resetTrialBuffers(){

  circBufferHead = 0;
  trialBufferHead = 0;
  trialBufferIsFull = false;
  circBufferIsFull = false;
  haveTriggerSignal = false;
  
}
//read serial input from host computer and change parameters accordingly
void checkForCommands() {

  if (Serial.available() > 0) {
    commandMode = 1;  //flag that we are receiving commands through serial
    //TIMSK1 &= ~(1 << OCIE1A);//disable timer for sampling
    String inString = Serial.readStringUntil('\n');
  
    //convert string to null terminate array of chars
    inString.toCharArray(commandBuffer, SIZE_OF_COMMAND_BUFFER);
    commandBuffer[inString.length()] = 0;

    // breaks string str into a series of tokens using delimiter ";"
    // Namely split strings into commands
    char* command = strtok(commandBuffer, ";");

    while (command != 0) {
      // Split the command in 2 parts: name and value
      char* separator = strchr(command, ':');
      if (separator != 0) {
        // Actually split the string in 2: replace ':' with 0
        *separator = 0;
        --separator;

        int paramValue = -1;
        switch (*separator) {
          case 'c':
            separator = separator + 2;
            numberOfChannels = 1;  //atoi(separator);//read number of channels
            break;
          case 's':
            //for changing the sample rate, which we will not actually ever do
            break;
          case 'm':
            //set the operation mode
            separator = separator + 2;
            paramValue = atoi(separator);
            if ((paramValue == MODE_CONTINUOUS) || (paramValue == MODE_TRIAL)) {
              collectionMode = paramValue;
              signalMode();
            }
            break;
          case 't':
            separator = separator + 2;
            paramValue = atoi(separator);
//            if (if paramValue > )
            //set the tial length
            break;
          case 'p':
            //set the pre stim length
            break;
        }
      }

      // Find the next command in input string
      command = strtok(0, ";");
    }
    commandMode = 0;
  }
}

//signal a change in the current collection state using LEDs
void signalMode() {

  digitalWrite(MODE_LED, LOW);
  digitalWrite(MODE_LED + 1, LOW);

  for (int i = 0; i < 3; i++) {
    digitalWrite(MODE_LED + collectionMode, LOW);
    delay(100);
    digitalWrite(MODE_LED + collectionMode, HIGH);
    delay(100);
  }
}
/* TIMER SETUP- the timer interrupt allows precise timed measurements of the read switch
for more info about configuration of arduino timers see http://arduino.cc/playground/Code/Timer1 
I spent alot of time figure out what each of these calls does and know I will forget so I added
an obnoxious number of comments*/
void configureTimers() {

  cli();  //stop interrupts

  //Make ADC sample faster. Change ADC clock
  //Change prescaler division factor to 16 ,- (KJ) I am not sure why this is done - it does not factor into the calculation of sample rate
  //which are still based on the base 16MHz clock speed - probably because the timer is running in CTC mode?
  //KJ - the first 3 bits of the ADCSRA register control the prescale value
  //KJ - 100 (bits 2,1,0 respectively) is a prescale or division factor of 16
  sbi(ADCSRA, ADPS2);  //1
  cbi(ADCSRA, ADPS1);  //0
  cbi(ADCSRA, ADPS0);  //0

  //set timer1 interrupt at 10kHz
  //KJ - this just initializes things
  TCCR1A = 0;  // set entire TCCR1A register to 0
  TCCR1B = 0;  // same for  TCCR1B
  TCNT1 = 0;   //initialize counter value to 0;

  //KJ - assign our clock tick number to the output compare register
  //KJ - this register holds the value that will be compared against the clock count (TCNT1)
  //KJ - many things can happen when they match depending on the mode and flags that are set
  OCR1A = interrupt_Number;  // Output Compare Registers

  // turn on CTC mode
  //KJ - CTC is Clear Timer on Compare Match
  // in CTC mode the timer counter (TCNT1 in our case) is reset when it reaches the number of samples in the OCR1A register
  //this is used to set the sample frequency to an exact desired value
  //and generate an interrupt when the number of samples is reached
  TCCR1B |= (1 << WGM12);

  // Set CS11 bit for 8 prescaler
  //KJ - a prescaler value of 8 is being set which will sample at fclk/8 or fs=2x10^8
  TCCR1B |= (1 << CS11);

  // enable timer compare interrupt
  //KJ this line sets the OCIE pin for output compare register A which enables
  //KJ - the interrupt when a match occurs
  //KJ - this indicates that an interrupt will fire when the value at OCR1A equals the nunber of ticks since the last interrupt
  TIMSK1 |= (1 << OCIE1A);

  //KJ - this enables interrupts generally by setting the interrupt flag in the status register
  sei();  //allow interrupts

  //END TIMER SETUP
  //KJ - this is the same as the line above and I have no idea what it is doing
  TIMSK1 |= (1 << OCIE1A);
}

void compileAndSendTrial() {
  //read the ring buffer
  int readLoc = circBufferHead;  // oldest point in the ring buffer
  int ii = 0;

  //transmit the entire packet one byte at a time
  for (ii = 0; ii < int(sizeof(trialHeader)); ii++) {
    Serial.write(trialHeader[ii]);
  }

  Serial.write(eventMarker);
  //send 16 bit values on byte at a time
  Serial.write(((sampleRate) >> 8) & 0xFF);                 // Send the upper byte first
  Serial.write((sampleRate * 2) & 0xFF);                    // Send the lower byte
  Serial.write(((PRESTIM_SAMPLES * 2) >> 8) & 0xFF);  // Send the upper byte first
  Serial.write((PRESTIM_SAMPLES * 2) & 0xFF);         // Send the lower byte
  Serial.write(((PSTSTIM_SAMPLES * 2) >> 8) & 0xFF);   // Send the upper byte first
  Serial.write((PSTSTIM_SAMPLES * 2) & 0xFF);          // Send the lower byte

  //send the raw value payload
  while (ii < PRESTIM_SAMPLES) {
    Serial.write(circBuffer[0][readLoc]);
    Serial.write(circBuffer[1][readLoc]);
    
    //erpTrial[ii * 2] = circBuffer[0][readLoc];
    //erpTrial[ii * 2 + 1] = circBuffer[1][readLoc];
    readLoc++;
    ii++;
    if (readLoc == PRESTIM_SAMPLES) {
      readLoc = 0;
    }
  }
  //add the post stimulus data
  readLoc = 0;
  while (ii < erpTrialByteLength / 2) {
    Serial.write(trialBuffer[0][readLoc]);
    Serial.write(trialBuffer[1][readLoc]);
    //erpTrial[ii * 2] = trialBuffer[0][readLoc];
    //erpTrial[ii * 2 + 1] = trialBuffer[1][readLoc];
    ii++;
    readLoc++;
  }
  //add a carriage return and line feed for making it easy without
  //knowing the trial length
  Serial.println(""); 
}

