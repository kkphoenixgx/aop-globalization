#import <Foundation/Foundation.h>

@protocol PanteaoActionHandler <NSObject>
- (BOOL)handlePanteaoAction:(NSString *)actionName agent:(NSString *)agentName args:(NSArray *)args;
@end

@protocol PanteaoWildcardHandler <NSObject>
- (BOOL)handleAnyAction:(NSString *)actionName agent:(NSString *)agentName args:(NSArray *)args;
@end

@interface BdiClient : NSObject {
    int socketFd;
    int enginePid;
    BOOL running;
    NSMutableDictionary *handlers;
    id<PanteaoWildcardHandler> wildcardHandler;
}

- (BOOL)connectToHost:(NSString *)host port:(int)port;
- (BOOL)connectToHost:(NSString *)host port:(int)port project:(NSString *)project;
- (void)sendMsgWithPerformative:(NSString *)performative sender:(NSString *)sender receiver:(NSString *)receiver content:(NSString *)content;
- (void)sendPerceptionWithAction:(NSString *)action perception:(NSString *)perception;
- (void)registerAction:(NSString *)actionName withHandler:(id<PanteaoActionHandler>)handler;
- (void)onAnyAction:(id<PanteaoWildcardHandler>)handler;
- (void)close;

@end
