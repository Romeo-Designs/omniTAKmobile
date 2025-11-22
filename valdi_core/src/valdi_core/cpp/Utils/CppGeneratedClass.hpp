//
//  CppGeneratedClass.hpp
//  valdi_core-pc
//
//  Created by Simon Corsin on 4/11/23.
//

#pragma once

#include "valdi_core/cpp/Schema/ValueSchemaRegistrySchemaIdentifier.hpp"
#include "valdi_core/cpp/Utils/ExceptionTracker.hpp"
#include "valdi_core/cpp/Utils/Function.hpp"
#include "valdi_core/cpp/Utils/ValdiObject.hpp"
#include "valdi_core/cpp/Utils/Value.hpp"
#include <mutex>
#include <vector>

namespace Valdi {

class ClassSchema;
class ValueSchemaRegistry;
class PlatformObjectAttachments;

class RegisteredCppGeneratedClass {
public:
    using TypeReferencesVec = std::vector<RegisteredCppGeneratedClass*>;
    using GetTypeReferencesCallback = Function<TypeReferencesVec()>;

    RegisteredCppGeneratedClass(ValueSchemaRegistry* registry,
                                std::string_view schemaString,
                                GetTypeReferencesCallback getTypeReferencesCallback);
    ~RegisteredCppGeneratedClass();

    void ensureSchemaRegistered(ExceptionTracker& exceptionTracker);

    Ref<ClassSchema> getResolvedClassSchema(ExceptionTracker& exceptionTracker);
    const StringBox& getClassName();

private:
    ValueSchemaRegistry* _registry;
    std::string_view _schemaString;
    std::atomic_bool _schemaRegistered = false;
    std::atomic_bool _schemaResolved = false;
    ValueSchemaRegistrySchemaIdentifier _schemaIdentifier = 0;
    StringBox _className;
    Ref<ClassSchema> _resolvedClassSchema;
    GetTypeReferencesCallback _getTypeReferencesCallback;
};

class CppGeneratedClass : public ValdiObject {
public:
    const StringBox& getClassName() const override;
    virtual RegisteredCppGeneratedClass* getRegisteredClass() const;

protected:
    static RegisteredCppGeneratedClass registerSchema(
        std::string_view schemaString,
        RegisteredCppGeneratedClass::GetTypeReferencesCallback getTypeReferencesCallback);
    static RegisteredCppGeneratedClass registerSchema(std::string_view schemaString);
};

class CppGeneratedModel : public CppGeneratedClass {
public:
};

class CppGeneratedInterface : public CppGeneratedClass {
public:
    CppGeneratedInterface();
    ~CppGeneratedInterface() override;

    Ref<PlatformObjectAttachments> getObjectAttachments();

private:
    Ref<PlatformObjectAttachments> _objectAttachments;
};

} // namespace Valdi
