//
//  Exception.hpp
//  ValdiRuntime
//
//  Created by Simon Corsin on 5/25/18.
//  Copyright © 2018 Snap Inc. All rights reserved.
//

#pragma once

#include "valdi_core/cpp/Utils/StringBox.hpp"
#include <string>

namespace Valdi {

class Exception : public std::exception {
public:
    explicit Exception(std::string_view message);
    explicit Exception(StringBox message);
    explicit Exception(const char* message);

    const char* what() const noexcept override;

    const StringBox& getMessage() const;

    static StringBox getMessageForException(const std::exception& exc);

private:
    StringBox _message;
};

} // namespace Valdi
