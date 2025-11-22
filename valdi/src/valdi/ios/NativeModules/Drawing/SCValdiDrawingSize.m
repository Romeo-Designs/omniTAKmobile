#import "valdi/ios/NativeModules/Drawing/SCValdiDrawingSize.h"

@implementation SCValdiDrawingSize

@dynamic width;
@dynamic height;

- (instancetype _Nonnull)initWithWidth:(double)width height:(double)height
{
    return [super initWithFieldValues:nil, width, height];
}

+ (SCValdiMarshallableObjectDescriptor)valdiMarshallableObjectDescriptor
{
    static const SCValdiMarshallableObjectFieldDescriptor kFields[] = {
        {.name = "width", .selName = nil, .type = "d"},
        {.name = "height", .selName = nil, .type = "d"},
        {.name = nil},
    };
    return SCValdiMarshallableObjectDescriptorMake(kFields, nil, nil, SCValdiMarshallableObjectTypeClass);
}

@end
