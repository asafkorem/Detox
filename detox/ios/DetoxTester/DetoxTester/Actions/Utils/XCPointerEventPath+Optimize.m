//
//  XCPointerEventPath+Optimize.m (DetoxTesterApp)
//  Created by Asaf Korem (Wix.com) on 2023.
//

#import "XCPointerEventPath+Optimize.h"

#import "NSObject+Swizzle.h"

#import "DetoxTester-Swift.h"

@import ObjectiveC;

@interface NSObject (XCPointerEventPathOptimize_Private)

/// Speed factor.
- (double)speedFactor;

@end

@implementation NSObject (XCPointerEventPathOptimize)

+ (void)load {
  @autoreleasepool {
    [self
     swizzleMethod:@selector(speedFactor)
     with:@selector(customSpeedFactor)
     className:@"XCPointerEventPath"];
  }
}

- (double)customSpeedFactor {
  double original = [self customSpeedFactor];

  NSString *logMessage = [NSString
      stringWithFormat:@"Custom speed factor, original speed factor: %f", original];
  [LogUtils log_optimizations:logMessage type:OS_LOG_TYPE_DEBUG];

  return 100;
}

@end
