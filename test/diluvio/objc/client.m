#import <Foundation/Foundation.h>
#import "BdiClient.h"

@interface MyActionHandler : NSObject <PanteaoActionHandler>
@property (nonatomic, assign) BOOL actionHandled;
@end

@implementation MyActionHandler
- (BOOL)handlePanteaoAction:(NSString *)actionName args:(NSArray *)args {
    if ([actionName isEqualToString:@"send_push_notification"]) {
        NSLog(@"[DILUVIO] Action handled: send_push_notification");
        self.actionHandled = YES;
        return YES;
    }
    return YES;
}
@end

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"[DILUVIO] Objective-C client starting");
    
    BdiClient *client = [[BdiClient alloc] init];
    if (![client connectToHost:@"127.0.0.1" port:44444]) {
        NSLog(@"[DILUVIO] FAILURE: connection failed");
        [pool drain];
        return 1;
    }
    
    NSLog(@"[DILUVIO] Connected!");
    
    MyActionHandler *handler = [[MyActionHandler alloc] init];
    [client registerAction:@"send_push_notification" withHandler:handler];
    
    [client sendMsgWithPerformative:@"tell" sender:@"external" receiver:@"orquestrador" content:@"evacuation_order(zone6)"];
    NSLog(@"[DILUVIO] Sent perception");
    
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while (!handler.actionHandled && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    [client close];
    
    if (handler.actionHandled) {
        NSLog(@"[DILUVIO] SUCCESS");
        [pool drain];
        return 0;
    } else {
        NSLog(@"[DILUVIO] FAILURE: timeout");
        [pool drain];
        return 1;
    }
}
