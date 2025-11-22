//
//  ProtobufMessageFactory.cpp
//  valdi-ios
//
//  Created by Simon Corsin on 11/22/19.
//

#include "valdi/runtime/JavaScript/Modules/ProtobufMessageFactory.hpp"
#include "valdi_core/cpp/Utils/Format.hpp"
#include "valdi_core/cpp/Utils/StringCache.hpp"
#include "valdi_protobuf/DescriptorDatabase.hpp"

namespace Valdi {

ProtobufMessageFactory::ProtobufMessageFactory()
    : _descriptorDatabase(std::make_unique<Protobuf::DescriptorDatabase>()), _pool(_descriptorDatabase.get()) {
    _pool.InternalSetLazilyBuildDependencies();
}
ProtobufMessageFactory::~ProtobufMessageFactory() = default;

bool ProtobufMessageFactory::load(const BytesView& data, ExceptionTracker& exceptionTracker) {
    return _descriptorDatabase->addFileDescriptorSet(data, exceptionTracker);
}

bool ProtobufMessageFactory::parseAndLoad(const std::string& filename,
                                          std::string_view protoFileContent,
                                          ExceptionTracker& exceptionTracker) {
    return _descriptorDatabase->parseAndAddFileDescriptorSet(filename, protoFileContent, exceptionTracker);
}

size_t ProtobufMessageFactory::getMessagePrototypeIndexForDescriptor(const google::protobuf::Descriptor* descriptor,
                                                                     ExceptionTracker& exceptionTracker) const {
    auto index =
        _descriptorDatabase->getSymbolIndexForName(StringCache::getGlobal().makeString(descriptor->full_name()));
    if (!index) {
        exceptionTracker.onError("Unrecognized messages descriptor");
        return 0;
    }

    return index.value();
}

const google::protobuf::Descriptor* ProtobufMessageFactory::getDescriptorAtIndex(size_t index,
                                                                                 ExceptionTracker& exceptionTracker) {
    if (index >= _descriptorDatabase->getSymbolsSize()) {
        exceptionTracker.onError("Invalid descriptor index");
        return nullptr;
    }

    const auto* descriptor = _descriptorDatabase->getDescriptorOfSymbolAtIndex(index);
    if (descriptor == nullptr) {
        std::string symbolNameStr;
        const auto& symbolName = _descriptorDatabase->getSymbolNameAtIndex(index);
        symbolName.toString(symbolNameStr);
        descriptor = _pool.FindMessageTypeByName(symbolNameStr);
        SC_ASSERT_NOTNULL(descriptor);
        if (descriptor == nullptr) {
            exceptionTracker.onError(Error(STRING_FORMAT("Internal error: cannot find message type {}", symbolName)));
        }
        _descriptorDatabase->setDescriptorOfSymbolAtIndex(index, descriptor);
    }

    return descriptor;
}

static std::vector<ProtobufMessageFactory::NamespaceEntry> getNamespaceEntriesForPackage(
    const Protobuf::DescriptorDatabase& database, const Protobuf::DescriptorDatabase::Package& package) {
    std::vector<ProtobufMessageFactory::NamespaceEntry> output;

    output.reserve(package.symbolIndexes.size() + package.nestedPackageIndexes.size());

    for (const auto& symbolIndex : package.symbolIndexes) {
        const auto& fullName = database.getSymbolNameAtIndex(symbolIndex);

        auto& it = output.emplace_back();
        it.id = symbolIndex;
        it.isMessage = true;
        it.name = fullName.getLastComponent();
    }

    for (const auto& nestedPackageIndex : package.nestedPackageIndexes) {
        const auto& fullName = database.getPackageAtIndex(nestedPackageIndex).fullName;

        auto& it = output.emplace_back();
        it.id = nestedPackageIndex;
        it.isMessage = false;
        it.name = fullName.getLastComponent();
    }

    return output;
}

std::vector<Protobuf::FullyQualifiedName> ProtobufMessageFactory::getDescriptorNames() const {
    return _descriptorDatabase->getAllSymbolNames();
}

std::vector<ProtobufMessageFactory::NamespaceEntry> ProtobufMessageFactory::getRootNamespaceEntries() const {
    return getNamespaceEntriesForPackage(*_descriptorDatabase, _descriptorDatabase->getRootPackage());
}

std::vector<ProtobufMessageFactory::NamespaceEntry> ProtobufMessageFactory::getNamespaceEntriesForId(
    size_t id, ExceptionTracker& exceptionTracker) const {
    if (id >= _descriptorDatabase->getPackagesSize()) {
        exceptionTracker.onError("Invalid package id");
        return {};
    }
    return getNamespaceEntriesForPackage(*_descriptorDatabase, _descriptorDatabase->getPackageAtIndex(id));
}

VALDI_CLASS_IMPL(ProtobufMessageFactory)

} // namespace Valdi
