const int signalPin = 9;       // PWM pin
const int samples = 50;        // samples per cycle
const float pi = 3.14159;
int sineTable[samples];

void setup() {
  pinMode(signalPin, OUTPUT);

  // Precompute sine values (0–255 for PWM)
  for (int i = 0; i < samples; i++) {
    sineTable[i] = (int)(127.5 + 127.5 * sin(2 * pi * i / samples));
  }
}

void loop() {
  int x=255;
  while(x>0) {
    analogWrite(signalPin,x);  // PWM duty cycle
    delay(1);
    x=x-10;                 // step time → sets frequency
  }
  delay(100);
  while(x<255) {
    analogWrite(signalPin,x);  // PWM duty cycle
    delay(1);
    x=x+10;                 // step time → sets frequency
  }
}
