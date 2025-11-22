//
//  CppMarshaller.hpp
//  valdi_core-pc
//
//  Created by Simon Corsin on 4/11/23.
//

#pragma once

#include "valdi_core/cpp/Utils/CppGeneratedClass.hpp"
#include "valdi_core/cpp/Utils/ExceptionTracker.hpp"
#include "valdi_core/cpp/Utils/Result.hpp"
#include "valdi_core/cpp/Utils/ValueFunction.hpp"
#include "valdi_core/cpp/Utils/ValueFunctionWithCallable.hpp"
#include "valdi_core/cpp/Utils/ValueTypedObject.hpp"

#include <tuple>

namespace Valdi {

template<typename R, typename... A>
class CppValueFunction;

class CppObjectStore {
public:
    std::unique_lock<std::recursive_mutex> lock() const;

    void setObjectProxyForId(uint32_t id, const Ref<CppGeneratedInterface>& object);
    Ref<CppGeneratedInterface> getObjectProxyForId(uint32_t id);

    static CppObjectStore* sharedInstance();

private:
    mutable std::recursive_mutex _mutex;
    FlatMap<uint32_t, Weak<CppGeneratedInterface>> _objectProxyById;
};

class CppProxyMarshallerBase {
public:
    CppProxyMarshallerBase(CppObjectStore* objectStore, std::unique_lock<std::recursive_mutex>&& lock);
    ~CppProxyMarshallerBase();

    CppObjectStore* getObjectStore() const;

private:
    CppObjectStore* _objectStore;
    std::unique_lock<std::recursive_mutex> _lock;
};

class CppProxyMarshaller : public CppProxyMarshallerBase {
public:
    CppProxyMarshaller(CppObjectStore* objectStore,
                       std::unique_lock<std::recursive_mutex>&& lock,
                       bool finishedMarshalling);
    ~CppProxyMarshaller();

    bool finishedMarshalling() const;

private:
    bool _finishedMarshalling;
};

class CppProxyUnmarshaller : public CppProxyMarshallerBase {
public:
    CppProxyUnmarshaller(CppObjectStore* objectStore,
                         std::unique_lock<std::recursive_mutex>&& lock,
                         Ref<ValueTypedProxyObject>&& proxyObject,
                         Ref<CppGeneratedInterface>&& object);

    ~CppProxyUnmarshaller();

    const Ref<ValueTypedProxyObject>& getProxyObject() const;
    const Ref<CppGeneratedInterface>& getObject() const;
    const Ref<ValueTypedObject>& getTypedObject() const;

private:
    Ref<ValueTypedProxyObject> _proxyObject;
    Ref<CppGeneratedInterface> _object;
};

class CppMarshaller {
public:
    template<typename T, typename = std::enable_if_t<std::is_constructible<Value, T>::value>>
    static void marshall(ExceptionTracker& exceptionTracker, const T& value, Value& out) {
        out = Value(value);
    }

    template<typename T, typename = std::enable_if_t<std::is_convertible<T*, CppGeneratedClass*>::value>>
    static void marshall(ExceptionTracker& exceptionTracker, const Ref<T>& value, Value& out) {
        if (value == nullptr) {
            out = Value::undefined();
            return;
        }

        T::marshall(exceptionTracker, value, out);
    }

    template<typename T>
    static void marshall(ExceptionTracker& exceptionTracker, const std::optional<T>& value, Value& out) {
        if (value) {
            marshall(exceptionTracker, value.value(), out);
        } else {
            out = Value::undefined();
        }
    }

    template<typename T>
    static void marshall(ExceptionTracker& exceptionTracker, const std::vector<T>& value, Value& out) {
        auto array = ValueArray::make(value.size());

        auto* ptr = array->begin();
        for (const auto& item : value) {
            marshall(exceptionTracker, item, *ptr);
            if (!exceptionTracker) {
                return;
            }
            ptr++;
        }

        out = Value(array);
    }

    template<typename R, typename... A>
    static void marshall(ExceptionTracker& exceptionTracker, const Function<Result<R>(A...)>& value, Value& out) {
        out = Value(makeShared<CppValueFunction<R, A...>>(value));
    }

    template<typename T>
    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, T& out) {
        out = value.checkedTo<T>(exceptionTracker);
    }

    template<typename T, typename = std::enable_if_t<std::is_convertible<T*, CppGeneratedClass*>::value>>
    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, Ref<T>& out) {
        if (value.isNullOrUndefined()) {
            out = nullptr;
        } else {
            T::unmarshall(exceptionTracker, value, out);
        }
    }

    template<typename T>
    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, std::optional<T>& out) {
        if (value.isNullOrUndefined()) {
            out = std::nullopt;
        } else {
            T outValue;
            unmarshall(exceptionTracker, value, outValue);
            if (!exceptionTracker) {
                out = std::nullopt;
            } else {
                out = std::make_optional<T>(std::move(outValue));
            }
        }
    }

    template<typename T>
    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, std::vector<T>& out) {
        auto array = value.checkedTo<Ref<ValueArray>>(exceptionTracker);
        if (!exceptionTracker) {
            return;
        }

        out.clear();
        out.reserve(array->size());

        for (const auto& item : *array) {
            auto& insertedItem = out.emplace_back();
            unmarshall(exceptionTracker, item, insertedItem);
            if (!exceptionTracker) {
                return;
            }
        }
    }

    template<typename R, typename... A>
    static void unmarshall(ExceptionTracker& exceptionTracker, const Value& value, Function<Result<R>(A...)>& out) {
        auto fn = value.checkedTo<Ref<ValueFunction>>(exceptionTracker);
        if (!exceptionTracker) {
            return;
        }

        out = [fn](A... arguments) -> Result<R> {
            SimpleExceptionTracker exceptionTracker;
            size_t ksize = sizeof...(arguments);
            Value convertedArguments[ksize];
            auto* outArguments = &convertedArguments[0];

            (
                [&] {
                    if (!exceptionTracker) {
                        return;
                    }

                    marshall(exceptionTracker, arguments, *outArguments);
                    outArguments++;
                }(),
                ...);

            if (!exceptionTracker) {
                return exceptionTracker.extractError();
            }

            ValueFunctionFlags flags;
            if constexpr (std::is_same<Void, R>::value) {
                flags = ValueFunctionFlagsNone;
            } else {
                flags = static_cast<ValueFunctionFlags>(ValueFunctionFlagsCallSync | ValueFunctionFlagsPropagatesError);
            }

            auto retValue = (*fn)(ValueFunctionCallContext(flags, convertedArguments, ksize, exceptionTracker));

            if (!exceptionTracker) {
                return exceptionTracker.extractError();
            }

            R convertedRetValue;
            unmarshall(exceptionTracker, retValue, convertedRetValue);

            if (!exceptionTracker) {
                return exceptionTracker.extractError();
            }

            return Result<R>(std::move(convertedRetValue));
        };
    }

    static Value* marshallTypedObjectPrologue(ExceptionTracker& exceptionTracker,
                                              RegisteredCppGeneratedClass& registeredClass,
                                              Value& out,
                                              size_t inputPropertiesSize);

    template<typename... T>
    static void marshallTypedObject(ExceptionTracker& exceptionTracker,
                                    RegisteredCppGeneratedClass& registeredClass,
                                    Value& out,
                                    const T&... properties) {
        auto* outputProperties =
            marshallTypedObjectPrologue(exceptionTracker, registeredClass, out, sizeof...(properties));
        if (!exceptionTracker) {
            return;
        }

        (
            [&] {
                if (!exceptionTracker) {
                    return;
                }

                marshall(exceptionTracker, properties, *outputProperties);
                outputProperties++;
            }(),
            ...);
    }

    static Ref<ValueTypedObject> unmarshallTypedObjectPrologue(ExceptionTracker& exceptionTracker,
                                                               RegisteredCppGeneratedClass& registeredClass,
                                                               const Value& value,
                                                               size_t outputPropertiesSize);

    template<typename... T>
    static void unmarshallTypedObject(ExceptionTracker& exceptionTracker,
                                      RegisteredCppGeneratedClass& registeredClass,
                                      const Value& value,
                                      T&... properties) {
        auto typedObject =
            unmarshallTypedObjectPrologue(exceptionTracker, registeredClass, value, sizeof...(properties));
        if (!exceptionTracker) {
            return;
        }

        auto* inputProperties = typedObject->getProperties();

        (
            [&] {
                if (!exceptionTracker) {
                    return;
                }

                unmarshall(exceptionTracker, *inputProperties, properties);
                inputProperties++;
            }(),
            ...);
    }

    static CppProxyMarshaller marshallProxyObjectPrologue(CppObjectStore* objectStore,
                                                          CppGeneratedInterface& value,
                                                          Value& out);

    static void marshallProxyObjectEpilogue(ExceptionTracker& exceptionTracker,
                                            CppProxyMarshaller& marshaller,
                                            CppGeneratedInterface& value,
                                            Value& out);

    template<typename F>
    static void marshallProxyObject(ExceptionTracker& exceptionTracker,
                                    CppObjectStore* objectStore,
                                    RegisteredCppGeneratedClass& registeredClass,
                                    CppGeneratedInterface& value,
                                    Value& out,
                                    F&& marshallTypedObject) {
        auto proxyMarshaller = marshallProxyObjectPrologue(objectStore, value, out);
        if (proxyMarshaller.finishedMarshalling()) {
            return;
        }

        marshallTypedObject();

        marshallProxyObjectEpilogue(exceptionTracker, proxyMarshaller, value, out);
    }

    template<typename F>
    static void marshallProxyObject(ExceptionTracker& exceptionTracker,
                                    RegisteredCppGeneratedClass& registeredClass,
                                    CppGeneratedInterface& value,
                                    Value& out,
                                    F&& marshallTypedObject) {
        marshallProxyObject(exceptionTracker,
                            CppObjectStore::sharedInstance(),
                            registeredClass,
                            value,
                            out,
                            std::move(marshallTypedObject));
    }

    static CppProxyUnmarshaller unmarshallProxyObjectPrologue(ExceptionTracker& exceptionTracker,
                                                              CppObjectStore* objectStore,
                                                              const Value& value);

    static void unmarshallProxyObjectEpilogue(CppProxyUnmarshaller& unmarshaller,
                                              CppGeneratedInterface& generatedInterface);

    template<typename ProxyT,
             typename T,
             typename = std::enable_if_t<std::is_convertible<ProxyT*, CppGeneratedInterface*>::value>>
    static void unmarshallProxyObject(ExceptionTracker& exceptionTracker,
                                      CppObjectStore* objectStore,
                                      RegisteredCppGeneratedClass& registeredClass,
                                      const Value& value,
                                      Ref<T>& out) {
        auto unmarshaller = unmarshallProxyObjectPrologue(exceptionTracker, objectStore, value);
        if (!exceptionTracker) {
            return;
        }

        if (unmarshaller.getObject() != nullptr) {
            out = castOrNull<T>(unmarshaller.getObject());
            return;
        }

        Ref<ProxyT> proxyOut;
        ProxyT::unmarshall(exceptionTracker, Value(unmarshaller.getTypedObject()), proxyOut);
        if (!exceptionTracker) {
            return;
        }

        out = proxyOut;
        unmarshallProxyObjectEpilogue(unmarshaller, *proxyOut);
    }

    template<typename ProxyT, typename T>
    static void unmarshallProxyObject(ExceptionTracker& exceptionTracker,
                                      RegisteredCppGeneratedClass& registeredClass,
                                      const Value& value,
                                      Ref<T>& out) {
        unmarshallProxyObject<ProxyT, T>(
            exceptionTracker, CppObjectStore::sharedInstance(), registeredClass, value, out);
    }

    template<typename T, typename R, typename... A>
    static Function<Result<R>(A...)> methodToFunction(const Ref<T>& object, Result<R> (T::*method)(A...)) {
        return [weakSelf = weakRef(object.get()), method](A... arguments) -> Result<R> {
            auto self = weakSelf.lock();
            if (!self) {
                return Error("Cannot call method: object was deallocated");
            }

            return ((*self).*method)(std::move(arguments)...);
        };
    }
};

template<typename R, typename... A>
class CppValueFunction : public ValueFunction {
public:
    explicit CppValueFunction(const Function<Result<R>(A...)>& callable) : _callable(callable) {}
    ~CppValueFunction() override = default;

    Value operator()(const ValueFunctionCallContext& callContext) noexcept override {
        auto& exceptionTracker = callContext.getExceptionTracker();
        size_t parameterIndex = 0;
        auto parameters =
            std::make_tuple<A...>(unmarshallArgument<A>(exceptionTracker, callContext, parameterIndex)...);
        if (!exceptionTracker) {
            return Value::undefined();
        }

        auto result = std::apply(_callable, parameters);
        if (!result) {
            exceptionTracker.onError(result.moveError());
            return Value::undefined();
        }

        Value out;

        CppMarshaller::marshall<R>(exceptionTracker, result.value(), out);

        return out;
    }

    std::string_view getFunctionType() const override {
        return "cpp function";
    }

private:
    Function<Result<R>(A...)> _callable;

    template<typename T>
    T unmarshallArgument(ExceptionTracker& exceptionTracker,
                         const ValueFunctionCallContext& callContext,
                         size_t& parameterIndex) {
        auto out = T();
        if (exceptionTracker) {
            CppMarshaller::unmarshall(callContext.getExceptionTracker(), callContext.getParameter(parameterIndex), out);
        }
        parameterIndex++;

        return out;
    }
};

} // namespace Valdi
