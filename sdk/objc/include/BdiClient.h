#import <Foundation/Foundation.h>

typedef void (^PanteaoActionBlock)(NSArray<NSString *> *args, void (^respond)(BOOL success));

@interface BdiClient : NSObject {
    int socketFd;
    BOOL running;
    NSMutableDictionary *handlers;
}

- (BOOL)connectToHost:(NSString *)host port:(int)port;
- (void)sendPerceptionWithAction:(NSString *)action perception:(NSString *)perception;
- (void)registerAction:(NSString *)actionName withHandler:(PanteaoActionBlock)handler;
- (void)close;

@end
