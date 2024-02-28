//
//  NSObject+Swizzle.h (DetoxTester)
//  Created by Asaf Korem (Wix.com) on 2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Swizzle)

+ (void)swizzleMethod:(SEL)original with:(SEL)new className:(NSString *)className;

@end

NS_ASSUME_NONNULL_END
