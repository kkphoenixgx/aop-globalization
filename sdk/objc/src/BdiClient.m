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

#import <fcntl.h>
#import <sys/stat.h>
#import <signal.h>

static int get_free_port() {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return 0;
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return 0;
    }
    socklen_t len = sizeof(addr);
    if (getsockname(fd, (struct sockaddr *)&addr, &len) < 0) {
        close(fd);
        return 0;
    }
    close(fd);
    return ntohs(addr.sin_port);
}

static NSString *VERSION = @"1.1.16";

static void download_engine(char *bin_path) {
    NSString *osName = @"darwin";
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    osName = @"ios";
#elif TARGET_OS_MAC
    osName = @"darwin";
#elif defined(__linux__)
    osName = @"linux";
#endif
    NSString *archStr = @"x64";
#if defined(__arm64__) || defined(__aarch64__)
    archStr = @"arm64";
#endif
    NSString *pkgName = [NSString stringWithFormat:@"panteao-engine-%@-%@", osName, archStr];
    NSString *urlStr = [NSString stringWithFormat:@"https://registry.npmjs.org/%@/-/%@-%@.tgz", pkgName, pkgName, VERSION];
    
    printf("\033[36m[Panteao]\033[0m Downloading native engine for %s-%s (v%s)...\n", [osName UTF8String], [archStr UTF8String], [VERSION UTF8String]);
    
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tarFile = [tmpDir stringByAppendingPathComponent:[NSString stringWithFormat:@"engine-%d.tgz", rand()]];
    
    NSTask *curlTask = [[NSTask alloc] init];
    [curlTask setLaunchPath:@"/usr/bin/curl"];
    [curlTask setArguments:@[@"-sL", @"-o", tarFile, urlStr]];
    [curlTask launch];
    [curlTask waitUntilExit];
    
    NSString *extractDir = [tmpDir stringByAppendingPathComponent:[NSString stringWithFormat:@"extract-%d", rand()]];
    [[NSFileManager defaultManager] createDirectoryAtPath:extractDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSTask *tarTask = [[NSTask alloc] init];
    [tarTask setLaunchPath:@"/usr/bin/tar"];
    [tarTask setArguments:@[@"-xzf", tarFile, @"-C", extractDir]];
    [tarTask launch];
    [tarTask waitUntilExit];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:extractDir];
    NSString *file;
    NSString *sourcePath = nil;
    while ((file = [enumerator nextObject])) {
        if ([[file lastPathComponent] isEqualToString:@"panteao-engine"]) {
            sourcePath = [extractDir stringByAppendingPathComponent:file];
            break;
        }
    }
    
    if (sourcePath) {
        NSString *dest = [NSString stringWithUTF8String:bin_path];
        [[NSFileManager defaultManager] createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:dest error:nil];
        chmod([dest UTF8String], 0755);
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:tarFile error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:extractDir error:nil];
}

static void find_binary(char *out_path, size_t max_len) {
    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    if (bundlePath) {
        NSString *path = [bundlePath stringByAppendingPathComponent:@"panteao-engine"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            snprintf(out_path, max_len, "%s", [path UTF8String]);
            return;
        }
    }
    
    NSString *exePath = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
    if (exePath) {
        NSString *dir = [exePath stringByDeletingLastPathComponent];
        NSString *path1 = [dir stringByAppendingPathComponent:@"panteao-engine"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path1]) {
            snprintf(out_path, max_len, "%s", [path1 UTF8String]);
            return;
        }
        NSString *path2 = [[dir stringByAppendingPathComponent:@"bin"] stringByAppendingPathComponent:@"panteao-engine"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path2]) {
            snprintf(out_path, max_len, "%s", [path2 UTF8String]);
            return;
        }
    }
    
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    NSString *path1 = [cwd stringByAppendingPathComponent:@"panteao-engine"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path1]) {
        snprintf(out_path, max_len, "%s", [path1 UTF8String]);
        return;
    }
    NSString *path2 = [[cwd stringByAppendingPathComponent:@"bin"] stringByAppendingPathComponent:@"panteao-engine"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path2]) {
        snprintf(out_path, max_len, "%s", [path2 UTF8String]);
        return;
    }
    
    snprintf(out_path, max_len, "panteao-engine");
}

@implementation BdiClient

- (instancetype)init {
    self = [super init];
    if (self) {
        socketFd = -1;
        enginePid = -1;
        running = NO;
        handlers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)connectToHost:(NSString *)host port:(int)port {
    return [self connectToHost:host port:port project:nil];
}

- (BOOL)connectToHost:(NSString *)host port:(int)port project:(NSString *)project {
    if (project != nil) {
        if (port == 0) {
            port = get_free_port();
            if (port == 0) return NO;
        }
        char bin_path[1024];
        find_binary(bin_path, sizeof(bin_path));
        if (strcmp(bin_path, "panteao-engine") == 0) {
            NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
            NSString *p = [cwd stringByAppendingPathComponent:@"panteao-engine"];
            snprintf(bin_path, sizeof(bin_path), "%s", [p UTF8String]);
            if (![[NSFileManager defaultManager] fileExistsAtPath:p]) {
                download_engine(bin_path);
            }
        }

        int pipe_out[2], pipe_err[2];
        pipe(pipe_out);
        pipe(pipe_err);
        
        int pid = fork();
        if (pid == 0) {
            char port_str[16];
            snprintf(port_str, sizeof(port_str), "%d", port);
            
            close(pipe_out[0]);
            close(pipe_err[0]);
            dup2(pipe_out[1], STDOUT_FILENO);
            dup2(pipe_err[1], STDERR_FILENO);
            close(pipe_out[1]);
            close(pipe_err[1]);
            
            execl(bin_path, bin_path, [project UTF8String], "--port", port_str, (char *)NULL);
            exit(1);
        } else if (pid > 0) {
            enginePid = pid;
            close(pipe_out[1]);
            close(pipe_err[1]);
            
            void (^readLogs)(int) = ^(int fd) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    FILE *fp = fdopen(fd, "r");
                    char line[4096];
                    while (fgets(line, sizeof(line), fp)) {
                        NSString *str = [[NSString alloc] initWithCString:line encoding:NSUTF8StringEncoding];
                        str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if (str.length > 0) {
                            if ([str hasPrefix:@"["] && [str containsString:@"]"]) {
                                NSRange end = [str rangeOfString:@"]"];
                                NSString *name = [str substringWithRange:NSMakeRange(1, end.location - 1)];
                                NSArray *parts = [name componentsSeparatedByString:@"."];
                                NSString *shortName = [parts lastObject];
                                printf("[36m[%s][0m %s
", [shortName UTF8String], [[str substringFromIndex:end.location + 1] UTF8String]);
                            } else {
                                printf("[36m[MAS][0m %s
", [str UTF8String]);
                            }
                        }
                    }
                    fclose(fp);
                });
            };
            
            readLogs(pipe_out[0]);
            readLogs(pipe_err[0]);
            
            usleep(800000);
        } else {
            return NO;
        }
    } else if (port == 0) {
        port = 44444;
    }

    socketFd = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFd < 0) {
        if (enginePid > 0) kill(enginePid, SIGKILL);
        return NO;
    }

    struct sockaddr_in serv_addr;
    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    NSString *actualHost = (host == nil || host.length == 0) ? @"127.0.0.1" : host;
    inet_pton(AF_INET, [actualHost UTF8String], &serv_addr.sin_addr);

    if (connect(socketFd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        close(socketFd);
        socketFd = -1;
        if (enginePid > 0) kill(enginePid, SIGKILL);
        return NO;
    }

    char handshake_buf[4096];
    int handshake_total = 0;
    BOOL handshake_success = NO;
    while (YES) {
        int n = recv(socketFd, handshake_buf + handshake_total, sizeof(handshake_buf) - handshake_total - 1, 0);
        if (n <= 0) break;
        handshake_total += n;
        handshake_buf[handshake_total] = '\0';
        if (strstr(handshake_buf, "\"type\":\"mas_ready\"") != NULL) {
            handshake_success = YES;
            break;
        }
    }

    if (!handshake_success) {
        close(socketFd);
        socketFd = -1;
        if (enginePid > 0) kill(enginePid, SIGKILL);
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

- (void)sendMsgWithPerformative:(NSString *)performative sender:(NSString *)sender receiver:(NSString *)receiver content:(NSString *)content {
    NSString *payload = [NSString stringWithFormat:@"{\"type\":\"message\",\"performative\":\"%@\",\"sender\":\"%@\",\"receiver\":\"%@\",\"content\":\"%@\"}\n", performative, sender, receiver, content];
    const char *msg = [payload UTF8String];
    write(socketFd, msg, strlen(msg));
}

- (void)registerAction:(NSString *)actionName withHandler:(id<PanteaoActionHandler>)handler {
    [handlers setObject:handler forKey:actionName];
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
    if (enginePid > 0) {
        kill(enginePid, SIGKILL);
        enginePid = -1;
    }
}

- (void)listenLoop {
    char buf[8192];
    int total = 0;
    while (running) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        int n = recv(socketFd, buf + total, sizeof(buf) - total - 1, 0);
        if (n <= 0) {
            [pool release];
            break;
        }
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
                    NSString *name = [parsed objectForKey:@"name"];
                    NSArray *args = [parsed objectForKey:@"args"];

                    id<PanteaoActionHandler> handler = [handlers objectForKey:name];
                    if (handler) {
                        BOOL success = [handler handlePanteaoAction:name args:args];
                        [self sendActionResultWithId:actionId success:success];
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
        [pool release];
    }
}

- (NSDictionary *)parseAction:(NSString *)actionStr {
    NSRange parenRange = [actionStr rangeOfString:@"("];
    if (parenRange.location == NSNotFound) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[actionStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"name", [NSArray array], @"args", nil];
    }
    NSString *name = [[actionStr substringToIndex:parenRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange rparenRange = [actionStr rangeOfString:@")" options:NSBackwardsSearch];
    if (rparenRange.location == NSNotFound || rparenRange.location <= parenRange.location + 1) {
        return [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", [NSArray array], @"args", nil];
    }
    NSString *argsStr = [actionStr substringWithRange:NSMakeRange(parenRange.location + 1, rparenRange.location - parenRange.location - 1)];

    NSMutableArray *args = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    BOOL insideQuotes = NO;
    int depthBrackets = 0;
    int depthParens = 0;

    for (NSUInteger i = 0; i < argsStr.length; i++) {
        unichar c = [argsStr characterAtIndex:i];
        if (c == '"') {
            insideQuotes = !insideQuotes;
            [current appendFormat:@"%C", c];
        } else if (!insideQuotes && c == '[') {
            depthBrackets++;
            [current appendFormat:@"%C", c];
        } else if (!insideQuotes && c == ']') {
            depthBrackets--;
            [current appendFormat:@"%C", c];
        } else if (!insideQuotes && c == '(') {
            depthParens++;
            [current appendFormat:@"%C", c];
        } else if (!insideQuotes && c == ')') {
            depthParens--;
            [current appendFormat:@"%C", c];
        } else if (c == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0) {
            [args addObject:[self cleanArg:current]];
            [current setString:@""];
        } else {
            [current appendFormat:@"%C", c];
        }
    }
    if (current.length > 0) {
        [args addObject:[self cleanArg:current]];
    }

    return [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", args, @"args", nil];
}

- (NSString *)cleanArg:(NSString *)arg {
    NSString *s = [arg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length >= 2 && [s hasPrefix:@"\""] && [s hasSuffix:@"\""]) {
        return [s substringWithRange:NSMakeRange(1, s.length - 2)];
    }
    return s;
}

@end
