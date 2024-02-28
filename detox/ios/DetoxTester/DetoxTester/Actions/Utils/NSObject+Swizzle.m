//
//  NSObject+Swizzle.m (DetoxTester)
//  Created by Asaf Korem (Wix.com) on 2024.
//

#import <Foundation/NSObjCRuntime.h>
#import <objc/runtime.h>

#import "XCPointerEventPath+Optimize.h"

#import "DetoxTester-Swift.h"

@import ObjectiveC;

@implementation NSObject (Swizzle)

+ (void)swizzleMethod:(SEL)original with:(SEL)new className:(NSString *)className {
  Class class = NSClassFromString(className);

  if(class == nil) {
    return;
  }

  if (!class_respondsToSelector(class, original)) {
    return;
  }

  NSString *logMessage = [NSString
      stringWithFormat:@"Swizzling %@ with %@, class: %@",
      NSStringFromSelector(original), NSStringFromSelector(new), className];
  [LogUtils log_optimizations:logMessage type:OS_LOG_TYPE_DEBUG];

  Method originalMethod = class_getInstanceMethod(class, original);
  Method swizzledMethod = class_getInstanceMethod(class, new);

  method_exchangeImplementations(originalMethod, swizzledMethod);
}

@end
