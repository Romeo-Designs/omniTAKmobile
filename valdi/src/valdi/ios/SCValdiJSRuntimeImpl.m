//
//  SCValdiCachingJSRuntime.m
//  valdi-ios
//
//  Created by Simon Corsin on 4/11/19.
//

#import "SCValdiJSRuntimeImpl.h"
#import "valdi_core/SCValdiError.h"
#import "valdi_core/SCValdiFunctionWithBlock.h"

@implementation SCValdiJSRuntimeImpl {
    __weak id<SCValdiJSRuntimeProvider> _jsRuntimeProvider;
    SCNValdiJSRuntime *_jsRuntime;
}

- (instancetype)initWithJSRuntimeProvider:(id<SCValdiJSRuntimeProvider>)jsRuntimeProvider
{
    self = [super init];

    if (self) {
        _jsRuntimeProvider = jsRuntimeProvider;
    }

    return self;
}

- (SCNValdiJSRuntime *)jsRuntime
{
    @synchronized (self) {
        if (!_jsRuntime) {
            _jsRuntime = [_jsRuntimeProvider getJsRuntime];
        }

        return _jsRuntime;
    }
}

- (NSInteger)pushModuleAthPath:(NSString *)modulePath inMarshaller:(SCValdiMarshallerRef)marshaller
{
    NSInteger objectIndex = [[self jsRuntime] pushModuleToMarshaller:nil path:modulePath marshallerHandle:(int64_t)marshaller];
    SCValdiMarshallerCheck(marshaller);
    return objectIndex;
}

- (void)preloadModuleAtPath:(NSString *)path maxDepth:(NSUInteger)maxDepth
{
    SCNValdiJSRuntime *jsRuntime = [self jsRuntime];
    [jsRuntime preloadModule:path maxDepth:(int32_t)maxDepth];
}

- (void)addHotReloadObserver:(id<SCValdiFunction>)hotReloadObserver forModulePath:(NSString *)modulePath
{
    [[self jsRuntime] addModuleUnloadObserver:modulePath observer:hotReloadObserver];
}

- (void)addHotReloadObserverWithBlock:(dispatch_block_t)block forModulePath:(NSString *)modulePath
{
    [self addHotReloadObserver:[SCValdiFunctionWithBlock functionWithBlock:^BOOL(SCValdiMarshaller *marshaller) {
        block();
        return NO;
    }] forModulePath:modulePath];
}

- (void)dispatchInJsThread:(dispatch_block_t)block
{
    [_jsRuntimeProvider dispatchOnJSQueueWithBlock:block sync:NO];
}

- (void)dispatchInJsThreadSyncWithBlock:(dispatch_block_t)block
{
    [_jsRuntimeProvider dispatchOnJSQueueWithBlock:block sync:YES];
}

@end
