#include "Wire.h"
#define MCP23017_ADDRESS 0x27 // Default I2C address of MCP23017
#define MCP23017_OLATA   0x14 // Register address for GPIOA output latch


volatile bool risingEdge = false;
volatile bool fallingEdge = false;

#define WAIT_TX_PIN 2
#define START_OF_TEXT_ASCII 2
#define BUFFER_SIZE 32

void setup()
{
  Serial.begin(9600);
  pinMode(WAIT_TX_PIN, INPUT_PULLUP); 
  attachInterrupt(digitalPinToInterrupt(WAIT_TX_PIN), handleInterrupt, CHANGE);

  Wire.begin(); // wake up I2C bus
  // set I/O pins to outputs
  Wire.beginTransmission(MCP23017_ADDRESS);
  Wire.write(0x00); // IODIRA register
  Wire.write(0x00); // set all of port A to outputs
  Wire.endTransmission();
  pinMode(WAIT_TX_PIN, INPUT);
}

void sendChar(char theChar)
{    
  Wire.beginTransmission(MCP23017_ADDRESS);
  Wire.write(MCP23017_OLATA);      // address bank A
  while (risingEdge == false)
  {
   
  } 
  // READY TX PIN IS NOW HIGH
  Wire.write((byte)theChar);  
  Wire.endTransmission();   

  Wire.beginTransmission(MCP23017_ADDRESS);
  Wire.write(MCP23017_OLATA);      // address bank A   
  
   // wait for the Z80 to set pin to low again   
  while (fallingEdge == false)
  {
  }   
  /// when the z80 gets a zero, the code onthere doesn't output anything to the lcd
  Wire.write((byte)0);   
  Wire.endTransmission(); 
}

void loop()
{
  char buffer[BUFFER_SIZE];  
  uint8_t bufferWritePtr = 0;
  uint8_t bufferReadPtr = 0;
  uint8_t bufferLevel = 0;

  memset (buffer, 0, sizeof(char) * BUFFER_SIZE);

  if (risingEdge == false)
  {
      sendChar(START_OF_TEXT_ASCII);
      sendChar('>');
  }

  while (1)
  {
    if (Serial.available() > 0)
    {
      buffer[bufferWritePtr] = Serial.read();
      bufferWritePtr++;
      bufferLevel++;
      if (bufferWritePtr >= BUFFER_SIZE)
      {
        bufferWritePtr = 0;
      }
    }

    if (bufferLevel > 0)
    {
      if (buffer[bufferReadPtr] != '\n')
      {
        sendChar(buffer[bufferReadPtr]);       
      }
      if (buffer[bufferReadPtr] =='`')
      {
        sendChar(START_OF_TEXT_ASCII);     
        sendChar('>');  
      }      
      Serial.print(buffer[bufferReadPtr]);   
      //Serial.print("level=");
      //Serial.println(bufferLevel);
      //Serial.print("read=");
      //Serial.println(bufferReadPtr);
      //Serial.print("write=");
      //Serial.println(bufferWritePtr);


      bufferLevel--;      
      bufferReadPtr++;
      if (bufferReadPtr >= BUFFER_SIZE)
      {
        bufferReadPtr = 0;
      }
    }
  }
}


void handleInterrupt()
{
  //pin7Changed = true;
  static bool lastState = HIGH; // Track the last state of pin 7
  bool currentState = digitalRead(WAIT_TX_PIN);

  if (currentState == HIGH && lastState == LOW) {
    risingEdge = true;
    fallingEdge = false;
  } else if (currentState == LOW && lastState == HIGH) {
    fallingEdge = true;
    risingEdge = false;
  }

  lastState = currentState; // Update last state
}