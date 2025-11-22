#pragma once

#include "valdi_core/ModuleFactoriesProvider.hpp"
#include "valdi_core/ModuleFactory.hpp"
#include "valdi_core/cpp/JavaScript/ModuleFactoryRegistry.hpp"
#include "valdi_core/cpp/Utils/Function.hpp"
#include "valdi_core/cpp/Utils/Mutex.hpp"
#include <variant>

namespace Valdi {

using ModuleFactoryFn = Function<std::shared_ptr<snap::valdi_core::ModuleFactory>()>;

/**
 * The ModuleFactoryRegister holds the list of ModuleFactory that should
 * be registered into the runtime at startup.
 */
class ModuleFactoryRegistry : public snap::valdi_core::ModuleFactoriesProvider {
public:
    ModuleFactoryRegistry();
    ~ModuleFactoryRegistry() override;

    void registerModuleFactory(const std::shared_ptr<snap::valdi_core::ModuleFactory>& moduleFactory);
    void registerModuleFactoriesProvider(
        const std::shared_ptr<snap::valdi_core::ModuleFactoriesProvider>& moduleFactoriesProvider);
    void registerModuleFactoryFn(ModuleFactoryFn moduleFactoryFn);

    static const std::shared_ptr<ModuleFactoryRegistry>& sharedInstance();

    std::vector</*not-null*/ std::shared_ptr<snap::valdi_core::ModuleFactory>> createModuleFactories(
        const Valdi::Value& runtimeager) final;

private:
    using Entry = std::variant<std::shared_ptr<snap::valdi_core::ModuleFactory>,
                               std::shared_ptr<snap::valdi_core::ModuleFactoriesProvider>,
                               ModuleFactoryFn>;
    std::vector<Entry> _entries;
    Mutex _mutex;
    bool _collectedStaticEntries = false;

    void collectStaticEntries();
};

/**
 * Used to statically register a module into the ModuleFactoryRegistry.
 */
class RegisterModuleFactory {
public:
    RegisterModuleFactory(ModuleFactoryFn factory);

private:
    ModuleFactoryFn _factory;
    const RegisterModuleFactory* _prev = nullptr;

    friend ModuleFactoryRegistry;
};

} // namespace Valdi
