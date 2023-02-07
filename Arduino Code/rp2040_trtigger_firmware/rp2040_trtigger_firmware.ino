const int TL1 = 22;
const int TL2 = 23;
byte commandByte;

void setup() {
  // put your setup code here, to run once:
  pinMode(TL1, OUTPUT);
  pinMode(TL2, OUTPUT);

  Serial.begin(9600);
}

bool state = false;
void loop() {
  // put your main code here, to run repeatedly:
  if (Serial.available()) {
    commandByte = Serial.read(); 
    digitalWrite(TL1, (commandByte & 1));
    digitalWrite(TL2, (commandByte & 2));  
    delay(50);   
    digitalWrite(TL1,LOW);
    digitalWrite(TL2,LOW);  
   }
}
