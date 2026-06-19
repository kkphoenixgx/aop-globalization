#import "BdiClient.h"
#import <sys/socket.h>
#import <arpa/inet.h>
#import <unistd.h>

@interface BdiClient ()
- (void)listenLoop;
- (void)sendActionResultWithId:(NSString *)actionId success:(BOOL)success;
- (NSDictionary *)parseAction:(NSString *)actionStr;
- (NSString *)cleanArg:(NSString *)arg;
@end

@implementation BdiClient

- (instancetype)init {
    self = [super init];
    if (self) {
        socketFd = -1;
        running = NO;
        handlers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)connectToHost:(NSString *)host port:(int)port {
    socketFd = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFd < 0) return NO;

    struct sockaddr_in serv_addr;
    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    inet_pton(AF_INET, [host UTF8String], &serv_addr.sin_addr);

    if (connect(socketFd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        return NO;
    }

    running = YES;
    [NSThread detachNewThreadSelector:@selector(listenLoop) toTarget:self withObject:nil];
    return YES;
}

- (void)sendPerceptionWithAction:(NSString *)action perception:(NSString *)perception {
    NSString *payload = [NSString stringWithFormat:@"{\"type\":\"perception\",\"action\":\"%@\",\"perception\":\"%@\"}\n", action, perception];
    const char *msg = [payload UTF8String];
    write(socketFd, msg, strlen(msg));
}

- (void)registerAction:(NSString *)actionName withHandler:(PanteaoActionBlock)handler {
    handlers[actionName] = [handler copy];
}

- (void)sendActionResultWithId:(NSString *)actionId success:(BOOL)success {
    NSString *payload = [NSString stringWithFormat:@"{\"type\":\"action_result\",\"id\":\"%@\",\"success\":%@}\n", actionId, success ? @"true" : @"false"];
    const char *msg = [payload UTF8String];
    write(socketFd, msg, strlen(msg));
}

- (void)close {
    running = NO;
    if (socketFd >= 0) {
        shutdown(socketFd, SHUT_RDWR);
        close(socketFd);
        socketFd = -1;
    }
}

- (void)listenLoop {
    @autoreleasepool {
        char buf[4096];
        int total = 0;
        while (running) {
            int n = recv(socketFd, buf + total, sizeof(buf) - total - 1, 0);
            if (n <= 0) break;
            total += n;
            buf[total] = '\0';

            char *line_start = buf;
            char *newline;
            while ((newline = strchr(line_start, '\n')) != NULL) {
                *newline = '\0';
                NSString *line = [NSString stringWithUTF8String:line_start];

                if ([line rangeOfString:@"\"type\":\"action\""].location != NSNotFound) {
                    NSString *actionId = @"";
                    NSString *rawAction = @"";

                    NSRange idRange = [line rangeOfString:@"\"id\":\""];
                    if (idRange.location != NSNotFound) {
                        NSUInteger start = idRange.location + 6;
                        NSRange endRange = [line rangeOfString:@"\"" options:0 range:NSMakeRange(start, line.length - start)];
                        if (endRange.location != NSNotFound) {
                            actionId = [line substringWithRange:NSMakeRange(start, endRange.location - start)];
                        }
                    }

                    NSRange actRange = [line rangeOfString:@"\"action\":\""];
                    if (actRange.location != NSNotFound) {
                        NSUInteger start = actRange.location + 10;
                        NSRange endRange = [line rangeOfString:@"\"" options:0 range:NSMakeRange(start, line.length - start)];
                        if (endRange.location != NSNotFound) {
                            rawAction = [line substringWithRange:NSMakeRange(start, endRange.location - start)];
                        }
                    }

                    if (actionId.length > 0 && rawAction.length > 0) {
                        NSDictionary *parsed = [self parseAction:rawAction];
                        NSString *name = parsed[@"name"];
                        NSArray *args = parsed[@"args"];

                        PanteaoActionBlock handler = handlers[name];
                        if (handler) {
                            handler(args, ^(BOOL success) {
                                [self sendActionResultWithId:actionId success:success];
                            });
                        } else {
                            [self sendActionResultWithId:actionId success:YES];
                        }
                    }
                }
                line_start = newline + 1;
            }

            int remaining = total - (int)(line_start - buf);
            if (remaining > 0 && line_start != buf) {
                memmove(buf, line_start, remaining);
                total = remaining;
            } else {
                total = 0;
            }
        }
    }
}

- (NSDictionary *)parseAction:(NSString *)actionStr {
    NSRange parenRange = [actionStr rangeOfString:@"("];
    if (parenRange.location == NSNotFound) {
        return @{@"name": [actionStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"args": @[]};
    }
    NSString *name = [[actionStr substringToIndex:parenRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange rparenRange = [actionStr rangeOfString:@")" options:NSBackwardsSearch];
    if (rparenRange.location == NSNotFound || rparenRange.location <= parenRange.location + 1) {
        return @{@"name": name, @"args": @[]};
    }
    NSString *argsStr = [actionStr substringWithRange:NSMakeRange(parenRange.location + 1, rparenRange.location - parenRange.location - 1)];

    NSMutableArray *args = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    BOOL insideQuotes = NO;

    for (NSUInteger i = 0; i < argsStr.length; i++) {
        unichar c = [argsStr characterAtIndex:i];
        if (c == '"') {
            insideQuotes = !insideQuotes;
        } else if (c == ',' && !insideQuotes) {
            [args addObject:[self cleanArg:current]];
            [current setString:@""];
        } else {
            [current appendFormat:@"%C", c];
        }
    }
    if (current.length > 0) {
        [args addObject:[self cleanArg:current]];
    }

    return @{@"name": name, @"args": args};
}

- (NSString *)cleanArg:(NSString *)arg {
    return [[arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
}

@end
