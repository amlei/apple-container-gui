#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject
+ (nullable NSString *)tryBlock:(void (NS_NOESCAPE ^)(void))block;
@end

NS_ASSUME_NONNULL_END
