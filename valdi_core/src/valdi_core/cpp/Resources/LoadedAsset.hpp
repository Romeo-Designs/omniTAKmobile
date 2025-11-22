//
//  LoadedAsset.hpp
//  valdi
//
//  Created by Simon Corsin on 8/12/21.
//

#pragma once

#include "valdi_core/cpp/Utils/Bytes.hpp"
#include "valdi_core/cpp/Utils/Result.hpp"
#include "valdi_core/cpp/Utils/ValdiObject.hpp"

namespace Valdi {

class LoadedAsset : public ValdiObject {
public:
    virtual Result<BytesView> getBytesContent();
};

} // namespace Valdi
