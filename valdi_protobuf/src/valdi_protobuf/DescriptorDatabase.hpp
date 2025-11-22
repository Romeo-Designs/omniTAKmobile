// Copyright © 2024 Snap, Inc. All rights reserved.

#pragma once

#include "valdi_core/cpp/Utils/Bytes.hpp"
#include "valdi_core/cpp/Utils/FlatMap.hpp"
#include "valdi_core/cpp/Utils/StringBox.hpp"
#include "valdi_core/cpp/Utils/Value.hpp"

#include "valdi_protobuf/FullyQualifiedName.hpp"

#include <google/protobuf/descriptor.h>
#include <google/protobuf/descriptor_database.h>

#include <vector>

namespace Valdi {
class ExceptionTracker;
}

namespace Valdi::Protobuf {

class FullyQualifiedName;
class Message;
class Raw;
class Field;
class MessagePool;

/**
 * DescriptorDatabase is a memory efficient implementation of google::protobuf::DescriptorDatabase
 * that is similar to Protobuf's builtin EncodedDescriptorDatabase but is faster to ingest
 * and exposes public APIs to query about the ingested types which won't induce parsing the
 * files.
 */
class DescriptorDatabase : public google::protobuf::DescriptorDatabase {
public:
    DescriptorDatabase();
    ~DescriptorDatabase() override;

    struct FileEntry {
        StringBox fileName;
        const void* data = nullptr;
        size_t length = 0;
    };

    struct Symbol {
        FullyQualifiedName fullName;
        size_t fileIndex = 0;
        const google::protobuf::Descriptor* descriptor = nullptr;
    };

    struct Package {
        FullyQualifiedName fullName;
        std::vector<size_t> symbolIndexes;
        std::vector<size_t> nestedPackageIndexes;
    };

    bool addFileDescriptorSet(const BytesView& data, ExceptionTracker& exceptionTracker);

    bool addFileDescriptor(const BytesView& data, ExceptionTracker& exceptionTracker);

    bool parseAndAddFileDescriptorSet(const std::string& filename,
                                      std::string_view protoFileContent,
                                      ExceptionTracker& exceptionTracker);

    bool FindFileByName(const std::string& filename, google::protobuf::FileDescriptorProto* output) final;

    bool FindFileContainingSymbol(const std::string& symbolName, google::protobuf::FileDescriptorProto* output) final;

    bool FindFileContainingExtension(const std::string& containingType,
                                     int fieldNumber,
                                     google::protobuf::FileDescriptorProto* output) final;

    bool FindAllExtensionNumbers(const std::string& extendeeType, std::vector<int>* output) final;

    bool FindAllFileNames(std::vector<std::string>* output) final;

    std::vector<FullyQualifiedName> getAllSymbolNames() const;

    size_t getSymbolsSize() const;

    const google::protobuf::Descriptor* getDescriptorOfSymbolAtIndex(size_t index) const;

    const FullyQualifiedName& getSymbolNameAtIndex(size_t index) const;

    void setDescriptorOfSymbolAtIndex(size_t index, const google::protobuf::Descriptor* descriptor);

    size_t getPackagesSize() const;

    const Package& getPackageAtIndex(size_t index) const;

    const Package& getRootPackage() const;

    std::optional<size_t> getSymbolIndexForName(const StringBox& name);

    Value toDebugJSON() const;

private:
    std::vector<BytesView> _retainedBuffers;
    std::vector<FileEntry> _files;
    std::vector<Symbol> _symbols;
    std::vector<Package> _packages;
    FlatMap<StringBox, size_t> _fileIndexByName;
    FlatMap<FullyQualifiedName, size_t> _symbolIndexByName;
    FlatMap<FullyQualifiedName, size_t> _packageIndexByName;

    bool addFileDescriptorInner(MessagePool& messagePool,
                                const Byte* data,
                                size_t length,
                                ExceptionTracker& exceptionTracker);

    bool copyProtoOfFile(size_t fileIndex, google::protobuf::FileDescriptorProto* output);

    bool addDescriptor(size_t fileIndex,
                       size_t packageIndex,
                       const FullyQualifiedName& packageName,
                       MessagePool& messagePool,
                       const Protobuf::Field& field,
                       ExceptionTracker& exceptionTracker);

    bool addSymbol(size_t fileIndex,
                   size_t packageIndex,
                   const FullyQualifiedName& name,
                   ExceptionTracker& exceptionTracker);

    bool addSymbolFromField(size_t fileIndex,
                            size_t packageIndex,
                            FullyQualifiedName& outputName,
                            Message& outMessage,
                            const Protobuf::Field& field,
                            ExceptionTracker& exceptionTracker);

    size_t getOrCreatePackageIndex(const FullyQualifiedName& name);

    Value packageToDebugJSON(const Package& package) const;
};

} // namespace Valdi::Protobuf
