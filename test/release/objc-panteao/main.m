#import <Panteao/Panteao.h>
#import <Foundation/Foundation.h>
int main() {
    @autoreleasepool {
        Panteao *engine = [[Panteao alloc] initWithProject:@"./project.jcm"];
        [engine connect];
    }
    return 0;
}
