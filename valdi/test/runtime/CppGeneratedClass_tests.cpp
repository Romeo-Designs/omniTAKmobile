#include "valdi_core/cpp/Schema/ValueSchemaRegistry.hpp"
#include "valdi_core/cpp/Utils/CppGeneratedClass.hpp"
#include "valdi_core/cpp/Utils/CppMarshaller.hpp"
#include "valdi_core/cpp/Utils/ValueFunctionWithCallable.hpp"
#include "valdi_core/cpp/Utils/ValueTypedProxyObject.hpp"
#include <gtest/gtest.h>

using namespace Valdi;

namespace ValdiTest {

struct MyCard : public CppGeneratedModel {
    StringBox title;
    std::optional<StringBox> subtitle;
    double width = 0;
    double height = 0;
    std::optional<bool> selected;
    std::optional<Function<Result<bool>(StringBox)>> onTap;

    MyCard() = default;
    ~MyCard() override = default;

    static RegisteredCppGeneratedClass registeredClass;

    static void marshall(ExceptionTracker& exceptionTracker, const Ref<MyCard>& value, Value& out) {
        auto& self = *value;
        CppMarshaller::marshallTypedObject(exceptionTracker,
                                           registeredClass,
                                           out,
                                           self.title,
                                           self.subtitle,
                                           self.width,
                                           self.height,
                                           self.selected,
                                           self.onTap);
    }

    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, Ref<MyCard>& out) {
        out = makeShared<MyCard>();
        auto& self = *out;
        CppMarshaller::unmarshallTypedObject(exceptionTracker,
                                             registeredClass,
                                             value,
                                             self.title,
                                             self.subtitle,
                                             self.width,
                                             self.height,
                                             self.selected,
                                             self.onTap);
    }
};

RegisteredCppGeneratedClass MyCard::registeredClass = CppGeneratedClass::registerSchema(
    "c 'MyCard'{'title': s, 'subtitle': s?, 'width': d, 'height': d, 'selected': b?, 'onTap': f?(s):b}");

struct MyCardSection : public CppGeneratedModel {
    std::vector<Ref<MyCard>> cards;
    std::vector<int64_t> ids;

    MyCardSection() = default;
    ~MyCardSection() override = default;

    static RegisteredCppGeneratedClass registeredClass;

    static void marshall(ExceptionTracker& exceptionTracker, const Ref<MyCardSection>& value, Value& out) {
        auto& self = *value;
        CppMarshaller::marshallTypedObject(exceptionTracker, registeredClass, out, self.cards, self.ids);
    }

    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, Ref<MyCardSection>& out) {
        out = makeShared<MyCardSection>();
        auto& self = *out;
        CppMarshaller::unmarshallTypedObject(exceptionTracker, registeredClass, value, self.cards, self.ids);
    }
};

RegisteredCppGeneratedClass MyCardSection::registeredClass = CppGeneratedClass::registerSchema(
    "c 'MyCardSection'{'cards': a<r:'MyCard'>, 'ids': a<l>}",
    []() -> RegisteredCppGeneratedClass::TypeReferencesVec { return {&MyCard::registeredClass}; });

struct ICalculator : public CppGeneratedInterface {
    virtual Result<double> add(double left, double right) = 0;

    static RegisteredCppGeneratedClass registeredClass;

    static void marshall(ExceptionTracker& exceptionTracker,
                         CppObjectStore* objectStore,
                         const Ref<ICalculator>& value,
                         Value& out);
    static void unmarshall(ExceptionTracker& exceptionTracker,
                           CppObjectStore* objectStore,
                           const Value& value,
                           Ref<ICalculator>& out);
};

RegisteredCppGeneratedClass ICalculator::registeredClass = CppGeneratedClass::registerSchema(
    "c+ 'MyCalculator'{'add': f(d, d): d}", []() -> RegisteredCppGeneratedClass::TypeReferencesVec { return {}; });

struct ICalculatorProxy : public ICalculator {
    Function<Result<double>(double, double)> addFn;

    ICalculatorProxy() = default;
    ~ICalculatorProxy() override = default;

    Result<double> add(double left, double right) final {
        return addFn(left, right);
    }

    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, Ref<ICalculatorProxy>& out) {
        out = makeShared<ICalculatorProxy>();
        auto& self = *out;
        CppMarshaller::unmarshallTypedObject(exceptionTracker, ICalculator::registeredClass, value, self.addFn);
    }
};

void ICalculator::marshall(ExceptionTracker& exceptionTracker,
                           CppObjectStore* objectStore,
                           const Ref<ICalculator>& value,
                           Value& out) {
    CppMarshaller::marshallProxyObject(exceptionTracker, objectStore, registeredClass, *value, out, [&]() {
        CppMarshaller::marshallTypedObject(
            exceptionTracker, registeredClass, out, CppMarshaller::methodToFunction(value, &ICalculator::add));
    });
}

void ICalculator::unmarshall(ExceptionTracker& exceptionTracker,
                             CppObjectStore* objectStore,
                             const Value& value,
                             Ref<ICalculator>& out) {
    CppMarshaller::unmarshallProxyObject<ICalculatorProxy>(exceptionTracker, objectStore, registeredClass, value, out);
}

struct MyTestCalculator : public ICalculator {
    MyTestCalculator() = default;
    ~MyTestCalculator() override = default;

    Result<double> add(double left, double right) final {
        return left + right;
    }
};

class TestProxyObject : public ValueTypedProxyObject {
public:
    TestProxyObject(const Ref<ValueTypedObject>& typedObject) : ValueTypedProxyObject(typedObject) {}
    ~TestProxyObject() override = default;

    std::string_view getType() const final {
        return "Test Proxy";
    }
};

TEST(CppGeneratedClass, canMarshallObject) {
    auto object = makeShared<MyCard>();

    object->title = STRING_LITERAL("Hello World");
    object->width = 42;
    object->height = 100;
    object->selected = {true};

    SimpleExceptionTracker exceptionTracker;
    Value out;
    MyCard::marshall(exceptionTracker, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    auto typedObject = out.getTypedObjectRef();
    ASSERT_TRUE(typedObject != nullptr);

    ASSERT_EQ(Value()
                  .setMapValue("title", Value(STRING_LITERAL("Hello World")))
                  .setMapValue("subtitle", Value::undefined())
                  .setMapValue("width", Value(42.0))
                  .setMapValue("height", Value(100.0))
                  .setMapValue("selected", Value(true))
                  .setMapValue("onTap", Value::undefined()),
              Value(typedObject->toValueMap()));
}

TEST(CppGeneratedClass, canUnmarshallObjectFromMap) {
    Ref<MyCard> out;
    SimpleExceptionTracker exceptionTracker;
    MyCard::unmarshall(exceptionTracker,
                       Value()
                           .setMapValue("title", Value(STRING_LITERAL("Hello World")))
                           .setMapValue("subtitle", Value(STRING_LITERAL("Nice")))
                           .setMapValue("width", Value(42.0))
                           .setMapValue("height", Value(100.0))
                           .setMapValue("selected", Value(true))
                           .setMapValue("onTap", Value::undefined()),
                       out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out != nullptr);

    ASSERT_EQ(STRING_LITERAL("Hello World"), out->title);
    ASSERT_EQ(std::make_optional(STRING_LITERAL("Nice")), out->subtitle);
    ASSERT_EQ(42.0, out->width);
    ASSERT_EQ(100.0, out->height);
    ASSERT_EQ(std::make_optional(true), out->selected);
    ASSERT_EQ(std::nullopt, out->onTap);
}

TEST(CppGeneratedClass, canUnmarshallObjectFromTypedObject) {
    SimpleExceptionTracker exceptionTracker;
    auto classSchema = MyCard::registeredClass.getResolvedClassSchema(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    auto typedObject = ValueTypedObject::make(classSchema);
    typedObject->setProperty(0, Value(STRING_LITERAL("Hello World")));
    typedObject->setProperty(2, Value(42.0));
    typedObject->setProperty(3, Value(100.0));
    typedObject->setProperty(4, Value(false));

    Ref<MyCard> out;
    MyCard::unmarshall(exceptionTracker, Value(typedObject), out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out != nullptr);

    ASSERT_EQ(STRING_LITERAL("Hello World"), out->title);
    ASSERT_EQ(std::nullopt, out->subtitle);
    ASSERT_EQ(42.0, out->width);
    ASSERT_EQ(100.0, out->height);
    ASSERT_EQ(std::make_optional(false), out->selected);
    ASSERT_EQ(std::nullopt, out->onTap);
}

TEST(CppGeneratedClass, canMarshallFunction) {
    auto object = makeShared<MyCard>();

    size_t callCount = 0;
    object->onTap = {[&](StringBox name) -> Result<bool> {
        callCount++;
        if (name == "activate") {
            return true;
        } else {
            return false;
        }
    }};

    SimpleExceptionTracker exceptionTracker;
    Value out;
    MyCard::marshall(exceptionTracker, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    auto typedObject = out.getTypedObjectRef();
    ASSERT_TRUE(typedObject != nullptr);

    auto onTap =
        typedObject->getPropertyForName(STRING_LITERAL("onTap")).checkedTo<Ref<ValueFunction>>(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_EQ(static_cast<size_t>(0), callCount);

    auto result = (*onTap)({Value(STRING_LITERAL("great"))});

    ASSERT_EQ(static_cast<size_t>(1), callCount);
    ASSERT_TRUE(result) << result.description();
    ASSERT_EQ(Value(false), result.value());

    result = (*onTap)({Value(STRING_LITERAL("activate"))});

    ASSERT_EQ(static_cast<size_t>(2), callCount);
    ASSERT_TRUE(result) << result.description();
    ASSERT_EQ(Value(true), result.value());
}

TEST(CppGeneratedClass, canUnmarshallFunction) {
    size_t callCount = 0;
    auto onTap = makeShared<ValueFunctionWithCallable>([&](const ValueFunctionCallContext& callContext) -> Value {
        auto str = callContext.getParameterAsString(0);
        callCount++;
        if (str == "activate") {
            return Value(true);
        } else {
            return Value(false);
        }
    });

    Ref<MyCard> out;
    SimpleExceptionTracker exceptionTracker;
    MyCard::unmarshall(exceptionTracker,
                       Value()
                           .setMapValue("title", Value(STRING_LITERAL("Hello World")))
                           .setMapValue("width", Value(42.0))
                           .setMapValue("height", Value(100.0))
                           .setMapValue("onTap", Value(onTap)),
                       out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out->onTap);

    ASSERT_EQ(static_cast<size_t>(0), callCount);

    auto result = out->onTap.value()(STRING_LITERAL("great"));

    ASSERT_EQ(static_cast<size_t>(1), callCount);
    ASSERT_TRUE(result) << result.description();
    ASSERT_EQ(false, result.value());

    result = out->onTap.value()(STRING_LITERAL("activate"));

    ASSERT_EQ(static_cast<size_t>(2), callCount);
    ASSERT_TRUE(result) << result.description();
    ASSERT_EQ(true, result.value());
}

TEST(CppGeneratedClass, canMarshallVector) {
    auto section = makeShared<MyCardSection>();

    auto item1 = makeShared<MyCard>();
    item1->title = STRING_LITERAL("Item 1");
    item1->width = 1;
    item1->height = 1;

    auto item2 = makeShared<MyCard>();
    item2->title = STRING_LITERAL("Item 2");
    item2->width = 2;
    item2->height = 2;

    section->cards.emplace_back(item1);
    section->cards.emplace_back(item2);

    section->ids.emplace_back(42);
    section->ids.emplace_back(43);

    SimpleExceptionTracker exceptionTracker;
    Value out;
    MyCardSection::marshall(exceptionTracker, section, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    auto typedObject = out.getTypedObjectRef();
    ASSERT_TRUE(typedObject != nullptr);

    auto cards = typedObject->getProperty(0).checkedTo<Ref<ValueArray>>(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_EQ(static_cast<size_t>(2), cards->size());

    auto convertedItem1 = (*cards)[0].checkedTo<Ref<ValueTypedObject>>(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    auto convertedItem2 = (*cards)[1].checkedTo<Ref<ValueTypedObject>>(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_EQ(Value()
                  .setMapValue("title", Value(STRING_LITERAL("Item 1")))
                  .setMapValue("width", Value(1.0))
                  .setMapValue("height", Value(1.0)),
              Value(convertedItem1->toValueMap(true)));

    ASSERT_EQ(Value()
                  .setMapValue("title", Value(STRING_LITERAL("Item 2")))
                  .setMapValue("width", Value(2.0))
                  .setMapValue("height", Value(2.0)),
              Value(convertedItem2->toValueMap(true)));

    ASSERT_EQ(Value(ValueArray::make({Value(42), Value(43)})), typedObject->getProperty(1));
}

TEST(CppGeneratedClass, canUnmarshallVector) {
    auto value =
        Value()
            .setMapValue("cards",
                         Value(ValueArray::make({Value()
                                                     .setMapValue("title", Value(STRING_LITERAL("Title 1")))
                                                     .setMapValue("width", Value(1.0))
                                                     .setMapValue("height", Value(1.0)),
                                                 Value()
                                                     .setMapValue("title", Value(STRING_LITERAL("Title 2")))
                                                     .setMapValue("subtitle", Value(STRING_LITERAL("A subtitle")))
                                                     .setMapValue("width", Value(2.0))
                                                     .setMapValue("height", Value(2.0))})))
            .setMapValue("ids", Value(ValueArray::make({Value(7.0)})));

    SimpleExceptionTracker exceptionTracker;
    Ref<MyCardSection> out;
    MyCardSection::unmarshall(exceptionTracker, value, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_EQ(static_cast<size_t>(2), out->cards.size());

    auto card1 = out->cards[0];
    ASSERT_EQ(STRING_LITERAL("Title 1"), card1->title);
    ASSERT_EQ(std::nullopt, card1->subtitle);
    ASSERT_EQ(1.0, card1->width);
    ASSERT_EQ(1.0, card1->height);
    ASSERT_EQ(std::nullopt, card1->selected);
    ASSERT_EQ(std::nullopt, card1->onTap);

    auto card2 = out->cards[1];
    ASSERT_EQ(STRING_LITERAL("Title 2"), card2->title);
    ASSERT_EQ(std::make_optional(STRING_LITERAL("A subtitle")), card2->subtitle);
    ASSERT_EQ(2.0, card2->width);
    ASSERT_EQ(2.0, card2->height);
    ASSERT_EQ(std::nullopt, card2->selected);
    ASSERT_EQ(std::nullopt, card2->onTap);

    ASSERT_EQ(std::vector<int64_t>({7}), out->ids);
}

TEST(CppGeneratedClass, canMarshallInterface) {
    CppObjectStore objectStore;

    auto object = makeShared<MyTestCalculator>();

    ASSERT_EQ(1, object.use_count());

    SimpleExceptionTracker exceptionTracker;
    Value out;
    ICalculator::marshall(exceptionTracker, &objectStore, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out.isProxyObject());

    ASSERT_EQ(2, object.use_count());

    auto addValue = out.getProxyObject()->getTypedObject()->getPropertyForName(STRING_LITERAL("add"));

    auto addFunction = addValue.checkedTo<Ref<ValueFunction>>(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    auto result = (*addFunction)({Value(7.0), Value(2.0)});

    ASSERT_TRUE(result) << result.description();

    ASSERT_EQ(Value(9.0), result.value());

    ASSERT_EQ(2, object.use_count());

    auto lock = objectStore.lock();
    auto instance = objectStore.getObjectProxyForId(out.getProxyObject()->getId());

    ASSERT_EQ(object.get(), instance.get());

    ASSERT_EQ(3, object.use_count());

    instance = nullptr;
    out = Value();

    ASSERT_EQ(1, object.use_count());
}

TEST(CppGeneratedClass, marshallingInterfaceTwiceShouldReturnSameProxy) {
    CppObjectStore objectStore;

    auto object = makeShared<MyTestCalculator>();

    SimpleExceptionTracker exceptionTracker;
    Value out;
    ICalculator::marshall(exceptionTracker, &objectStore, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out.isProxyObject());
    auto proxy1 = out.getTypedProxyObjectRef();

    out = Value();
    ICalculator::marshall(exceptionTracker, &objectStore, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out.isProxyObject());
    auto proxy2 = out.getTypedProxyObjectRef();

    ASSERT_EQ(proxy1, proxy2);

    out = Value();
    proxy2 = nullptr;

    // Proxy should be retained weekly
    ASSERT_EQ(1, proxy1.use_count());
    proxy1 = nullptr;

    ICalculator::marshall(exceptionTracker, &objectStore, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out.isProxyObject());
    proxy1 = out.getTypedProxyObjectRef();
    out = Value();

    ASSERT_EQ(1, proxy1.use_count());
}

TEST(CppGeneratedClass, unmarshallingPreviouslyMarshalledInterfaceShouldReturnSameInstance) {
    CppObjectStore objectStore;

    auto object = makeShared<MyTestCalculator>();

    SimpleExceptionTracker exceptionTracker;
    Value out;
    ICalculator::marshall(exceptionTracker, &objectStore, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();
    ASSERT_TRUE(out.isProxyObject());

    Ref<ICalculator> outCalculator;
    ICalculator::unmarshall(exceptionTracker, &objectStore, out, outCalculator);

    ASSERT_EQ(object, outCalculator);
}

TEST(CppGeneratedClass, callingFunctionOnDeallocatedMarshalledInterfaceShouldFail) {
    CppObjectStore objectStore;

    auto object = makeShared<MyTestCalculator>();

    SimpleExceptionTracker exceptionTracker;
    Value out;
    ICalculator::marshall(exceptionTracker, &objectStore, object, out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(out.isProxyObject());

    auto addValue = out.getProxyObject()->getTypedObject()->getPropertyForName(STRING_LITERAL("add"));

    auto addFunction = addValue.checkedTo<Ref<ValueFunction>>(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    out = Value();
    ASSERT_EQ(1, object.use_count());
    object = nullptr;

    auto result = (*addFunction)({Value(7.0), Value(2.0)});

    ASSERT_FALSE(result) << result.description();
    ASSERT_TRUE(result.error().toStringBox().contains("object was deallocated"));
}

TEST(CppGeneratedClass, canUnmarshallInterface) {
    CppObjectStore objectStore;

    SimpleExceptionTracker exceptionTracker;
    auto schema = ICalculator::registeredClass.getResolvedClassSchema(exceptionTracker);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    size_t callCount = 0;
    auto addFunction = makeShared<ValueFunctionWithCallable>([&](const ValueFunctionCallContext& callContext) -> Value {
        callCount++;
        auto left = callContext.getParameterAsDouble(0);
        auto right = callContext.getParameterAsDouble(1);

        return Value(left + right);
    });

    auto typedObject = ValueTypedObject::make(schema);
    typedObject->setPropertyForName(STRING_LITERAL("add"), Value(addFunction));

    auto testProxyObject = makeShared<TestProxyObject>(typedObject);

    Ref<ICalculator> out;
    ICalculator::unmarshall(exceptionTracker, &objectStore, Value(testProxyObject), out);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    // We should have gotten a proxy
    ASSERT_TRUE(castOrNull<ICalculatorProxy>(out) != nullptr);

    auto result = out->add(13, 57);
    ASSERT_TRUE(result) << result.description();

    ASSERT_EQ(70.0, result.value());
    ASSERT_EQ(static_cast<size_t>(1), callCount);

    // If we marshall the proxy, we should get the testProxyObject back

    Value outValue;
    ICalculator::marshall(exceptionTracker, &objectStore, out, outValue);
    ASSERT_TRUE(exceptionTracker) << exceptionTracker.extractError();

    ASSERT_TRUE(outValue.isProxyObject());
    ASSERT_EQ(testProxyObject, outValue.getTypedProxyObjectRef());
}

} // namespace ValdiTest
