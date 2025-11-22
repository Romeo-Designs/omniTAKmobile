//
//  SCValdiJSRuntime.h
//  valdi-ios
//
//  Created by Simon Corsin on 4/11/19.
//

#import "valdi_core/SCValdiFunction.h"
#import "valdi_core/SCValdiMarshaller.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
An opaque instance of the underlying JS runtime that can be used with @GenerateNativeFunc
generated code to call functions defined in your Valdi modules.
*/
@protocol SCValdiJSRuntime <NSObject>

/**
 Used by the @GenerateNativeFunc generated code to get and call your TypeScript functions.
 */
- (NSInteger)pushModuleAthPath:(NSString*)modulePath inMarshaller:(SCValdiMarshallerRef)marshaller;

/**
    Preload the given module given as an absolute path (e.g. 'valdi_core/src/Renderer').
    When maxDepth is more than 1, the preload will apply recursively to modules that the given
    modulePath imports, up until the given depth.
    */
- (void)preloadModuleAtPath:(NSString*)path maxDepth:(NSUInteger)maxDepth;

- (void)addHotReloadObserver:(id<SCValdiFunction>)hotReloadObserver forModulePath:(NSString*)modulePath;

/**
 * Observe hot reload for the module at the given path.
 * Calls the given callback when the module is hot reloaded.
 */
- (void)addHotReloadObserverWithBlock:(dispatch_block_t)block forModulePath:(NSString*)modulePath;

- (void)dispatchInJsThread:(dispatch_block_t)block;

- (void)dispatchInJsThreadSyncWithBlock:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
