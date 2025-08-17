#include <WiFi.h>


#define BIT0 13
#define BIT1 5//because pin 12 is not usable
#define BIT2 14
#define BIT3 27
#define BIT4 25
#define BIT5 33
#define BIT6 32
#define BIT7 26//because 35 is used when wifi is switched on
#define BIT_PIN 15 //1 for high byte and 0 for low byte
#define BROD 22 //recieve confirmation from stm32
#define EPIN 23
 

uint32_t counter = 0;
bool expected = true;
uint32_t t_counter=0;

#define BUFFER_SIZE 16384
uint16_t buffer[BUFFER_SIZE];
size_t PACKET_SIZE = BUFFER_SIZE * 2;

bool buffer_filled = true;

bool fastRead1(uint8_t pin) {
    return (REG_READ(GPIO_IN_REG) & (1 << pin));
}

// For GPIO 32-39
bool fastRead2(uint8_t pin) {
    return (REG_READ(GPIO_IN1_REG) & (1 << (pin - 32)));
}

void fastWrite(uint8_t pin, bool state) {
    if (state) {
        REG_WRITE(GPIO_OUT_W1TS_REG, 1 << pin);
    } else {
        REG_WRITE(GPIO_OUT_W1TC_REG, 1 << pin);
    }
}



uint8_t read8BitValue() {
  fastWrite(EPIN,true);
  while(fastRead1(BROD)==0){
  }
  fastWrite(EPIN, false);
  return (fastRead1(BIT0) << 0) |
         (fastRead1(BIT1) << 1) |
         (fastRead1(BIT2) << 2) |
         (fastRead1(BIT3) << 3) |
         (fastRead1(BIT4) << 4) |
         (fastRead2(BIT5) << 5) |
         (fastRead2(BIT6) << 6) |
         (fastRead1(BIT7) << 7);
}
uint16_t read16bit(){
  uint16_t high, low;
  while(fastRead1(BIT_PIN) != expected){
    
  }
  
  high = read8BitValue();
  expected = !expected;

  while(fastRead1(BIT_PIN) != expected){

  }
  low = read8BitValue();
  expected = !expected;
  return (high << 8) + low;
}

const char* ssid = "ESP32_AP";
const char* password = "123456789";

WiFiServer server(80);

void setup() {

  pinMode(BIT0, INPUT);
  pinMode(BIT1, INPUT);
  pinMode(BIT2, INPUT);
  pinMode(BIT3, INPUT);
  pinMode(BIT4, INPUT);
  pinMode(BIT5, INPUT);
  pinMode(BIT6, INPUT);
  pinMode(BIT7, INPUT);

  pinMode(EPIN, OUTPUT);
  pinMode(BROD,INPUT);
  pinMode(BIT_PIN, INPUT);
  pinMode(34, OUTPUT);
  Serial.begin(115200);

  WiFi.softAP(ssid, password);
  
  IPAddress IP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(IP);
  
  server.begin();

  for(int i = 0; i < BUFFER_SIZE;i++){
    buffer[i]=i;
  }
}

int start = 0;
int b_index = 0;

void sendArrayOverWiFi(WiFiClient& client, uint16_t* arr, size_t arrSize) {
  
  client.write((uint8_t*)arr, arrSize * sizeof(uint16_t));

  Serial.println("Data sent successfully!");
}

void loop() {
   static WiFiClient client;
  
  // // Check for new client or existing client
  if (!client || !client.connected()) {
    client = server.available();
    if (client) {
      Serial.println("New Client connected");
      // Skip HTTP headers if present
      while(client.available() && client.read() != '\n') {}
    }
  }
  
  // If we have a connected client
  if (client && client.connected() && buffer_filled) {
    size_t bytesSent = client.write((const uint8_t*)buffer, PACKET_SIZE);
    if (bytesSent == PACKET_SIZE) {
        Serial.printf("Successfully sent %d integers (%d bytes)\n", BUFFER_SIZE, bytesSent);
        buffer_filled = false;
      } else {
        Serial.printf("Error: Only sent %d/%d bytes\n", bytesSent, PACKET_SIZE);
      }
  }

  // Serial.println(buffer_filled);

  if(!buffer_filled){
  buffer[b_index]=read16bit();
  //Serial.println(buffer[b_index]);
    b_index = (b_index+1)%BUFFER_SIZE;
    if(b_index == 0){
      buffer_filled =true;
      b_index = 0;
    }
  }
}
