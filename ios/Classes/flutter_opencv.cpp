#include <stdint.h>
#include <opencv2/opencv.hpp>

// Add all C/C++ functions
extern "C" __attribute__((visibility("default"))) __attribute__((used))
float native_add(float num1, float num2) {
 return num1 + num2;
}

