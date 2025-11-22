#import <valdi_core/SCValdiJSConversionUtils.h>

#import "SCValdiDrawingModule.h"

@interface SCValdiDrawingModule: SCValdiProxyMarshallableObject

@end

@implementation SCValdiDrawingModule

+ (SCValdiMarshallableObjectDescriptor)valdiMarshallableObjectDescriptor
{
    static const SCValdiMarshallableObjectFieldDescriptor kFields[] = {
            {.name = "getFont", .selName = "getFontWithSpecs:", .type = "f|m|(r:'[0]'): r:'[1]'"},
            {.name = "isFontRegistered", .selName = "isFontRegisteredWithFontName:", .type = "f|m|(s): b"},
            {.name = "registerFont", .selName = "registerFontWithFontName:weight:style:filename:", .type = "f|m|(s, r:'[2]', r:'[3]', s)"},
            {.name = nil},
    };
    static const char *const kIdentifiers[] = {
            "SCValdiDrawingFontSpecs",
            "SCValdiDrawingFont",
            "SCValdiDrawingFontWeight",
            "SCValdiDrawingFontStyle",
            nil
    };
    return SCValdiMarshallableObjectDescriptorMake(kFields, kIdentifiers, nil, SCValdiMarshallableObjectTypeProtocol);
}

@end

NSInteger SCValdiDrawingModuleMarshall(SCValdiMarshallerRef  _Nonnull marshaller, id<SCValdiDrawingModule> _Nonnull instance) {
    return SCValdiMarshallableObjectMarshallInterface(marshaller, instance, [SCValdiDrawingModule class]);
}

