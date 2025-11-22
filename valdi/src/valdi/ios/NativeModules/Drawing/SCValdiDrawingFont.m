#import "valdi_core/SCValdiFunctionWithBlock.h"
#import "valdi_core/SCValdiMarshallableObjectDescriptor.h"

#import "valdi/ios/NativeModules/Drawing/SCValdiDrawingFont.h"

@interface SCValdiDrawingFont: SCValdiProxyMarshallableObject

@end

static SCValdiFieldValue SCValdiFunctionInvokeOOOOOO_o(const void *function, SCValdiFieldValue* fields) {
    const void *result = ((const void * (*) (const void *, const void *, const void *, const void *, const void *, const void * ))function)(SCValdiFieldValueGetPtr(fields[0]),
                                                                                                                                            SCValdiFieldValueGetPtr(fields[1]),
                                                                                                                                            SCValdiFieldValueGetPtr(fields[2]),
                                                                                                                                            SCValdiFieldValueGetPtr(fields[3]),
                                                                                                                                            SCValdiFieldValueGetPtr(fields[4]),
                                                                                                                                            SCValdiFieldValueGetPtr(fields[5]));
    return SCValdiFieldValueMakePtr(result);
}

static id SCValdiBlockCreateOOOOOO_o(SCValdiBlockTrampoline trampoline) {
    return ^const void *(const void *p0, const void *p1, const void *p2, const void *p3, const void *p4) {
        return SCValdiFieldValueGetPtr(trampoline(nil,
                                                     SCValdiFieldValueMakePtr(p0),
                                                     SCValdiFieldValueMakePtr(p1),
                                                     SCValdiFieldValueMakePtr(p2),
                                                     SCValdiFieldValueMakePtr(p3),
                                                     SCValdiFieldValueMakePtr(p4)));
    };
}

@implementation SCValdiDrawingFont


+ (SCValdiMarshallableObjectDescriptor)valdiMarshallableObjectDescriptor
{
    static const SCValdiMarshallableObjectBlockSupport kBlocks[] = {
        { .typeEncoding = "oooooo:o", .invoker = &SCValdiFunctionInvokeOOOOOO_o, .factory = &SCValdiBlockCreateOOOOOO_o },
        { .typeEncoding = nil },
    };
    static const char *const kIdentifiers[] = {
        "SCValdiDrawingSize",
        nil
    };
    static const SCValdiMarshallableObjectFieldDescriptor kFields[] = {
        {.name = "measureText", .selName = "measureTextWithText:maxWidth:maxHeight:maxLines:", .type = "f*(s, d@?, d@?, d@?): r:'[0]'"},
        {.name = nil},
    };
    return SCValdiMarshallableObjectDescriptorMake(kFields, kIdentifiers, kBlocks, SCValdiMarshallableObjectTypeProtocol);
}

@end

NSInteger SCValdiDrawingFontMarshall(SCValdiMarshallerRef _Nonnull marshaller,
                                                          id<SCValdiDrawingFont> _Nonnull instance) {
    return SCValdiMarshallableObjectMarshallInterface(marshaller, instance, [SCValdiDrawingFont class]);
}
