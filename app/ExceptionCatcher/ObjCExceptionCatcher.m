#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (nullable NSString *)tryBlock:(void (NS_NOESCAPE ^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@\n%@",
                exception.name,
                exception.reason ?: @"",
                [exception.callStackSymbols componentsJoinedByString:@"\n"]];
    }
}

@end
