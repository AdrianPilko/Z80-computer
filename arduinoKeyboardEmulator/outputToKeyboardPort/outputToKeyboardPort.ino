
#define ENABLE_OUTPUT_PIN   10
#define OUT_PIN_0 2
#define OUT_PIN_1 3
#define OUT_PIN_2 4
#define OUT_PIN_3 5
#define OUT_PIN_4 6
#define OUT_PIN_5 7
#define OUT_PIN_6 8
#define OUT_PIN_7 9



void setup() {
  // put your setup code here, to run once:
  pinMode(OUT_PIN_0, OUTPUT);
  pinMode(OUT_PIN_1, OUTPUT);
  pinMode(OUT_PIN_2, OUTPUT);
  pinMode(OUT_PIN_3, OUTPUT);
  pinMode(OUT_PIN_4, OUTPUT);
  pinMode(OUT_PIN_5, OUTPUT);
  pinMode(OUT_PIN_6, OUTPUT);            
  pinMode(OUT_PIN_7, OUTPUT);            
  pinMode(ENABLE_OUTPUT_PIN,INPUT);
  Serial.begin(9600);
}

void loop() {
  #define MAX_BUFFER 32
  uint8_t count = 0;
  uint8_t charBufferIndex = 0;
  char charBuffer[MAX_BUFFER];

  while (1)
  {
    uint8_t val = digitalRead(ENABLE_OUTPUT_PIN);
    if (val == HIGH)
    {
      if (charBufferIndex > 0)
      {
        char charRead = charBuffer[charBufferIndex];
        digitalWrite(OUT_PIN_0, charRead & 0b00000001);
        digitalWrite(OUT_PIN_1, charRead & 0b00000010);
        digitalWrite(OUT_PIN_2, charRead & 0b00000100);
        digitalWrite(OUT_PIN_3, charRead & 0b00001000);
        digitalWrite(OUT_PIN_4, charRead & 0b00010000);
        digitalWrite(OUT_PIN_5, charRead & 0b00100000);
        digitalWrite(OUT_PIN_6, charRead & 0b01000000);
        digitalWrite(OUT_PIN_7, charRead & 0b10000000);
        delay(10);
        digitalWrite(OUT_PIN_0, LOW);
        digitalWrite(OUT_PIN_1, LOW);
        digitalWrite(OUT_PIN_2, LOW);
        digitalWrite(OUT_PIN_3, LOW);
        digitalWrite(OUT_PIN_4, LOW);
        digitalWrite(OUT_PIN_5, LOW);
        digitalWrite(OUT_PIN_6, LOW);
        digitalWrite(OUT_PIN_7, LOW);
        Serial.print(charBuffer[charBufferIndex]);
        Serial.print(" ");
        Serial.println(charBufferIndex);
        charBufferIndex--;   
        if (charBufferIndex == 0)
        {
          charBuffer[0] = 0;
          charBuffer[1] = 0;
          charBuffer[2] = 0;
        }
      }
    }
    if (Serial.available() > 0)
    {
      charBuffer[charBufferIndex] = Serial.read();
      //Serial.print(charBuffer[charBufferIndex]);
      charBufferIndex++;
      if (charBufferIndex>= MAX_BUFFER) charBufferIndex = 0;
    }
  }
}
