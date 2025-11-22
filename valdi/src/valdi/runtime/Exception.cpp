//
//  Exception.cpp
//  ValdiRuntime
//
//  Created by Simon Corsin on 5/25/18.
//  Copyright © 2018 Snap Inc. All rights reserved.
//

#include "valdi/runtime/Exception.hpp"
#include "valdi_core/cpp/Utils/StringCache.hpp"

namespace Valdi {

Exception::Exception(std::string_view message) : _message(StringCache::getGlobal().makeString(std::move(message))) {}

Exception::Exception(StringBox message) : _message(std::move(message)) {}

Exception::Exception(const char* message) : _message(STRING_LITERAL(message)) {}

const char* Exception::what() const noexcept {
    return _message.getCStr();
}

const StringBox& Exception::getMessage() const {
    return _message;
}

StringBox Exception::getMessageForException(const std::exception& exc) {
    const auto* valdiException = dynamic_cast<const Exception*>(&exc);
    if (valdiException != nullptr) {
        return valdiException->getMessage();
    }

    return STRING_LITERAL(exc.what());
}

} // namespace Valdi
