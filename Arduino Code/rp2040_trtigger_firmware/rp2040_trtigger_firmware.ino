#include <Adafruit_NeoPixel.h>

#define NUMPIXELS 1

const int LED_POWER = 11;
const int LED_PIN = 12;
const int TRIG_PIN_1 = 0;
const int TRIG_PIN_2 = 1;
byte commandByte;
byte trigVal;
unsigned long color[3];

Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

void setup() {

  //set up the neo pixel
  pixels.begin();
  pinMode(LED_POWER,OUTPUT);
  digitalWrite(LED_POWER, HIGH);

  color[0] = pixels.Color(0,0,255);
  color[1] = pixels.Color(255,0,0);
  color[2] = pixels.Color(0,255,0);

 
  // put your setup code here, to run once:
  pinMode(TRIG_PIN_1, OUTPUT);
  pinMode(TRIG_PIN_2, OUTPUT);

  Serial.begin(9600);
}

bool state = false;
void loop() {
  // put your main code here, to run repeatedly:
  if (Serial.available()) {
    commandByte = Serial.read(); 
    trigVal = commandByte & 3;
    
    digitalWrite(TRIG_PIN_1, (commandByte & 1));
    digitalWrite(TRIG_PIN_2, (commandByte & 2));  

    pixels.setPixelColor(0, color[trigVal-1]);
    pixels.show();
  
    delay(50);   
    digitalWrite(TRIG_PIN_1,LOW);
    digitalWrite(TRIG_PIN_2,LOW);  
    
    delay(200);
    pixels.clear();
    pixels.show();
    

   }
}
