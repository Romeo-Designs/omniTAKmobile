//
//  Error.hpp
//  valdi-ios
//
//  Created by Simon Corsin on 8/30/19.
//

#pragma once

#include "valdi_core/cpp/Utils/StringBox.hpp"

namespace Valdi {

struct ErrorStorage : public SimpleRefCountable {
    StringBox message;
    StringBox stackTrace;
    Ref<ErrorStorage> cause;

    ErrorStorage(StringBox&& message, StringBox&& stackTrace, const Ref<ErrorStorage>& cause);
    ~ErrorStorage() override;

    bool operator==(const ErrorStorage& storage) const;

    size_t hash() const;
};

class Error {
public:
    Error();
    explicit Error(StringBox message);
    explicit Error(const std::string& message);
    explicit Error(const char* message);
    Error(StringBox message, StringBox stackTrace, const Error* cause);
    Error(Ref<ErrorStorage> storage);

    bool isEmpty() const;
    bool hasStack() const;

    std::string toString() const;
    StringBox toStringBox() const;

    /**
     Return the outer message in the Error hierarchy.
     */
    const StringBox& getMessage() const noexcept;

    /**
     Return the outer stack in the Error hierarchy.
     */
    const StringBox& getStack() const noexcept;

    std::optional<Error> getCause() const noexcept;

    bool operator==(const Error& other) const noexcept;
    bool operator!=(const Error& other) const noexcept;

    Error rethrow(const StringBox& message) const;
    Error rethrow(std::string_view message) const;
    Error rethrow(const Error& error) const;

    /**
     Return an error message that contains a merged message from all the causes, and contains the first resolved stack
     */
    Error flatten() const;

    size_t hash() const;

    const Ref<ErrorStorage>& getStorage() const;

private:
    Ref<ErrorStorage> _storage;

    std::string toString(bool includeCauses) const;
};

std::ostream& operator<<(std::ostream& os, const Error& error);

} // namespace Valdi
