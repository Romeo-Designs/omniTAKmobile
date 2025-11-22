#import "valdi/ios/SCValdiJSWorker.h"
#import "valdi/runtime/JavaScript/JavaScriptRuntime.hpp"
#import "valdi/SCNValdiJSRuntime+Private.h"
#import "valdi_core/SCValdiFunctionWithBlock.h"
#import "valdi_core/SCValdiObjCConversionUtils.h"

@implementation SCValdiJSWorker {
    SCNValdiJSRuntime *_jsRuntime;
}

- (instancetype)initWithWorkerRuntime:(SCNValdiJSRuntime*)runtime
{
    self = [super init];

    if (self) {
        _jsRuntime = runtime;
    }

    return self;
}

- (std::shared_ptr<Valdi::JavaScriptRuntime>)cppRuntime
{
    auto cppInterface = djinni_generated_client::valdi::JSRuntime::toCpp(_jsRuntime);
    auto cppRuntimeInstance = std::dynamic_pointer_cast<Valdi::JavaScriptRuntime>(cppInterface);
    SC_ASSERT(cppRuntimeInstance);
    return cppRuntimeInstance;
}

- (NSInteger)pushModuleAthPath:(NSString *)modulePath inMarshaller:(SCValdiMarshallerRef)marshaller
{
    NSInteger objectIndex = [_jsRuntime pushModuleToMarshaller:nil path:modulePath marshallerHandle:(int64_t)marshaller];
    SCValdiMarshallerCheck(marshaller);
    return objectIndex;
}

- (void)preloadModuleAtPath:(NSString *)path maxDepth:(NSUInteger)maxDepth
{
    [_jsRuntime preloadModule:path maxDepth:(int32_t)maxDepth];
}

- (void)addHotReloadObserver:(id<SCValdiFunction>)hotReloadObserver forModulePath:(NSString *)modulePath
{
    [_jsRuntime addModuleUnloadObserver:modulePath observer:hotReloadObserver];
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
    auto wrappedValue = ValdiIOS::ValueFromNSObject([block copy]);
    ([self cppRuntime])->dispatchOnJsThreadAsync(nullptr, [=](auto &/*jsEntry*/) {
            dispatch_block_t block = ValdiIOS::NSObjectFromValue(wrappedValue);
            block();
        });
}

- (void)dispatchInJsThreadSyncWithBlock:(dispatch_block_t)block
{
    ([self cppRuntime])->dispatchSynchronouslyOnJsThread([&](auto &/*jsEntry*/) {
            block();
        });
}

@end
