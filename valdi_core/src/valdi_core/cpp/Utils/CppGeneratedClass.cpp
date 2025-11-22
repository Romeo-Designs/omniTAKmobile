//
//  CppGeneratedClass.cpp
//  valdi_core-pc
//
//  Created by Simon Corsin on 4/11/23.
//

#include "valdi_core/cpp/Utils/CppGeneratedClass.hpp"
#include "valdi_core/cpp/Schema/ValueSchemaRegistry.hpp"
#include "valdi_core/cpp/Schema/ValueSchemaTypeResolver.hpp"
#include "valdi_core/cpp/Utils/PlatformObjectAttachments.hpp"

namespace Valdi {

RegisteredCppGeneratedClass::RegisteredCppGeneratedClass(ValueSchemaRegistry* registry,
                                                         std::string_view schemaString,
                                                         GetTypeReferencesCallback getTypeReferencesCallback)
    : _registry(registry),
      _schemaString(schemaString),
      _getTypeReferencesCallback(std::move(getTypeReferencesCallback)) {}

RegisteredCppGeneratedClass::~RegisteredCppGeneratedClass() = default;

void RegisteredCppGeneratedClass::ensureSchemaRegistered(ExceptionTracker& exceptionTracker) {
    if (!_schemaRegistered) {
        auto lock = _registry->lock();
        if (_schemaRegistered) {
            return;
        }

        auto parseResult = ValueSchema::parse(_schemaString);
        if (!parseResult) {
            exceptionTracker.onError(parseResult.moveError());
            return;
        }

        _schemaIdentifier = _registry->registerSchema(parseResult.value());
        _className = parseResult.value().getClass()->getClassName();
        _schemaRegistered = true;
    }
}

Ref<ClassSchema> RegisteredCppGeneratedClass::getResolvedClassSchema(ExceptionTracker& exceptionTracker) {
    ensureSchemaRegistered(exceptionTracker);
    if (!exceptionTracker) {
        return nullptr;
    }

    if (!_schemaResolved) {
        auto lock = _registry->lock();
        if (_schemaResolved) {
            return _resolvedClassSchema;
        }

        auto dependencies = _getTypeReferencesCallback();

        for (const auto& dependency : dependencies) {
            dependency->ensureSchemaRegistered(exceptionTracker);
            if (!exceptionTracker) {
                return nullptr;
            }
        }

        ValueSchemaTypeResolver typeResolver(_registry);

        auto schema = _registry->getSchemaForIdentifier(_schemaIdentifier);
        bool didChange = false;
        auto result = typeResolver.resolveTypeReferences(schema, ValueSchemaRegistryResolveType::Schema, &didChange);
        if (!result) {
            exceptionTracker.onError(result.moveError());
            return nullptr;
        }

        if (didChange) {
            _registry->updateSchema(_schemaIdentifier, result.value());
        }

        _resolvedClassSchema = result.value().getClassRef();
        _schemaResolved = true;
    }

    return _resolvedClassSchema;
}

const StringBox& RegisteredCppGeneratedClass::getClassName() {
    SimpleExceptionTracker exceptionTracker;
    ensureSchemaRegistered(exceptionTracker);
    if (!exceptionTracker) {
        exceptionTracker.clearError();
        return StringBox::emptyString();
    }

    return _className;
}

const StringBox& CppGeneratedClass::getClassName() const {
    auto* registeredClass = getRegisteredClass();
    if (registeredClass == nullptr) {
        return StringBox::emptyString();
    }

    return registeredClass->getClassName();
}

RegisteredCppGeneratedClass* CppGeneratedClass::getRegisteredClass() const {
    return nullptr;
}

RegisteredCppGeneratedClass CppGeneratedClass::registerSchema(
    std::string_view schemaString, RegisteredCppGeneratedClass::GetTypeReferencesCallback getTypeReferencesCallback) {
    return RegisteredCppGeneratedClass(
        ValueSchemaRegistry::sharedInstance().get(), schemaString, std::move(getTypeReferencesCallback));
}

RegisteredCppGeneratedClass CppGeneratedClass::registerSchema(std::string_view schemaString) {
    return registerSchema(schemaString, []() -> RegisteredCppGeneratedClass::TypeReferencesVec { return {}; });
}

CppGeneratedInterface::CppGeneratedInterface() = default;
CppGeneratedInterface::~CppGeneratedInterface() = default;

Ref<PlatformObjectAttachments> CppGeneratedInterface::getObjectAttachments() {
    if (_objectAttachments == nullptr) {
        _objectAttachments = makeShared<PlatformObjectAttachments>();
    }

    return _objectAttachments;
}

} // namespace Valdi
