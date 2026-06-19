#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSLog(@"[DILUVIO] Objective-C client starting");
        
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            NSLog(@"[DILUVIO] FAILURE: socket creation failed");
            [pool drain];
            return 1;
        }
        
        struct sockaddr_in serv_addr;
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(44444);
        inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr);
        
        if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
            NSLog(@"[DILUVIO] FAILURE: connection failed");
            [pool drain];
            return 1;
        }
        
        NSLog(@"[DILUVIO] Connected!");
        sleep(1);
        
        const char *percept = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"evacuation_order(litoral)\"}\n";
        send(sock, percept, strlen(percept), 0);
        NSLog(@"[DILUVIO] Sent perception");
        
        char buffer[2048] = {0};
        int valread = read(sock, buffer, 2047);
        if (valread > 0) {
            NSString *response = [NSString stringWithUTF8String:buffer];
            NSLog(@"[DILUVIO] Received: %@", response);
            
            if ([response containsString:@"\"type\":\"action\""]) {
                NSRange rangeStart = [response rangeOfString:@"\"id\":\""];
                if (rangeStart.location != NSNotFound) {
                    NSString *sub = [response substringFromIndex:rangeStart.location + 6];
                    NSRange rangeEnd = [sub rangeOfString:@"\""];
                    if (rangeEnd.location != NSNotFound) {
                        NSString *actionId = [sub substringToIndex:rangeEnd.location];
                        NSString *reply = [NSString stringWithFormat:@"{\"type\":\"action_result\",\"id\":\"%@\",\"success\":true}\n", actionId];
                        send(sock, [reply UTF8String], [reply length], 0);
                        NSLog(@"[DILUVIO] Action result sent");
                        NSLog(@"[DILUVIO] SUCCESS");
                    }
                }
            }
        }
        
        close(sock);
        [pool drain];
    return 0;
}
