#import <Foundation/Foundation.h>

@protocol PanteaoActionHandler <NSObject>
- (BOOL)handlePanteaoAction:(NSString *)actionName args:(NSArray *)args;
@end

@interface BdiClient : NSObject {
    int socketFd;
    int enginePid;
    BOOL running;
    NSMutableDictionary *handlers;
}

- (BOOL)connectToHost:(NSString *)host port:(int)port;
- (BOOL)connectToHost:(NSString *)host port:(int)port project:(NSString *)project;
- (void)sendMsgWithPerformative:(NSString *)performative sender:(NSString *)sender receiver:(NSString *)receiver content:(NSString *)content;
- (void)sendPerceptionWithAction:(NSString *)action perception:(NSString *)perception;
- (void)registerAction:(NSString *)actionName withHandler:(id<PanteaoActionHandler>)handler;
- (void)close;

@end
