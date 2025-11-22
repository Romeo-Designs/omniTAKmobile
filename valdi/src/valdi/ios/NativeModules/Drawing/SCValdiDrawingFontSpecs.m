#import "valdi/ios/NativeModules/Drawing/SCValdiDrawingFontSpecs.h"

@implementation SCValdiDrawingFontSpecs

@dynamic font;
@dynamic lineHeight;

- (instancetype _Nonnull)initWithFont:(NSString * _Nonnull)font
{
    return [super initWithFieldValues:nil, font, nil];
}

+ (SCValdiMarshallableObjectDescriptor)valdiMarshallableObjectDescriptor
{
    static const SCValdiMarshallableObjectFieldDescriptor kFields[] = {
        {.name = "font", .selName = nil, .type = "s"},
        {.name = "lineHeight", .selName = nil, .type = "d@?"},
        {.name = nil},
    };
    return SCValdiMarshallableObjectDescriptorMake(kFields, nil, nil, SCValdiMarshallableObjectTypeClass);
}

@end
