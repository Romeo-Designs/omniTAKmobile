//
//  File.swift
//  
//
//  Created by Simon Corsin on 4/12/23.
//

import Foundation

class CppSchemaWriterListener: SchemaWriterListener {
    func getClassName(nodeMapping: ValdiNodeClassMapping) throws -> String? {
        guard let cppType = nodeMapping.cppType else {
            if !nodeMapping.isGenerated {
                return nil
            }

            throw CompilerError("No C++ type provided for type \(nodeMapping.tsType)")
        }

        return cppType.declaration.fullTypeName
    }
}

class CppSchemaWriter: SchemaWriter {
    init(typeParameters: [ValdiTypeParameter]?) {
        super.init(typeParameters: typeParameters,
                   listener: CppSchemaWriterListener(),
                   alwaysBoxFunctionParametersAndReturnValue: false,
                   boxIntEnums: false)
    }
}
