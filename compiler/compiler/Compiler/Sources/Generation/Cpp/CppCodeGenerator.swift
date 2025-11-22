//
//  CppCodeGenerator.swift
//  
//
//  Created by Simon Corsin on 4/11/23.
//

import Foundation

struct CppMethodParameter {
    let name: String
    let typeName: String
}

struct CppMethod {
    let returnTypeName: String
    let parameters: [CppMethodParameter]
}

struct CppTypeParser {
    let typeName: String
    let method: CppMethod?
    let isMovable: Bool
    let isIntrinsicallyNullable: Bool
    let isTypeAlias: Bool
    let defaultInitializationString: String?
}

final class CppIncludeSection: CodeWriterContent {

    private(set) var includedFiles = Set<String>()

    @discardableResult func addInclude(path: String) -> Bool {
        return includedFiles.insert(path).inserted
    }

    var content: String {
        return includedFiles.sorted().map { "#include \"\($0)\"\n" }.joined()
    }
}

class CppCodeWriter: CodeWriter {

}

final class CppFileGenerator: CodeWriterContent {

    var content: String {
        return writer.content
    }

    let includeSection = CppIncludeSection()
    let forwardDeclarations = CppCodeWriter()

    let body = CppCodeWriter()

    private let writer = CodeWriter()

    init(namespace: CPPNamespace, isHeader: Bool) {
        if isHeader {
            writer.appendHeader("#pragma once\n")
        }
        writer.appendHeader(includeSection)
        writer.appendHeader("\n")

        if namespace.components.isEmpty {
            writer.appendBody(forwardDeclarations)
            writer.appendBody(body)
        } else {
            writer.appendBody("namespace \(namespace.components.joined(separator: "::" )) {\n\n")
            writer.appendBody(forwardDeclarations)
            writer.appendBody(body)
            writer.appendBody("\n}\n")
        }

        forwardDeclarations.nonEmptyTerminator = "\n"
    }
}

struct CppTypeAlias {
    let statement: String
    let isOnMethod: Bool
}

final class CppCodeGenerator {

    static let valdiNamespace = "Valdi"

    let nameAllocator = PropertyNameAllocator.forCpp()
    let header: CppFileGenerator
    let impl: CppFileGenerator

    private(set) var referencedTypes: [String] = []
    private(set) var typealiases: [CppTypeAlias] = []

    private let namespace: CPPNamespace

    private let isInValdiNamespace: Bool

    init(namespace: CPPNamespace) {
        self.namespace = namespace
        self.header = CppFileGenerator(namespace: namespace, isHeader: true)
        self.impl = CppFileGenerator(namespace: namespace, isHeader: false)
        self.isInValdiNamespace = CPPNamespace(components: [CppCodeGenerator.valdiNamespace]).resolve(other: namespace).components.isEmpty
    }

    func getValdiTypeName(typeName: String) -> String {
        if isInValdiNamespace {
            return typeName
        } else {
            return "\(CppCodeGenerator.valdiNamespace)::\(typeName)"
        }
    }

    private func makeCppMarshallerCall(callName: String) -> String {
        return "\(getValdiTypeName(typeName: "CppMarshaller"))::\(callName)"
    }

    func makeRefType(typeName: String) -> String {
        let refTypeName = getValdiTypeName(typeName: "Ref")
        return "\(refTypeName)<\(typeName)>"
    }

    private func getPrimitiveTypeParser(primitiveType: String,
                                        isMovable: Bool,
                                        isIntrinsicallyNullable: Bool,
                                        defaultInitializationString: String?) -> CppTypeParser {
        return CppTypeParser(
            typeName: primitiveType,
            method: nil,
            isMovable: isMovable,
            isIntrinsicallyNullable: isIntrinsicallyNullable,
            isTypeAlias: false,
            defaultInitializationString: defaultInitializationString
        )
    }

    private func toOptionalTypeParser(typeParser: CppTypeParser) -> CppTypeParser {
        return CppTypeParser(
            typeName: "std::optional<\(typeParser.typeName)>",
            method: typeParser.method,
            isMovable: typeParser.isMovable,
            isIntrinsicallyNullable: true,
            isTypeAlias: false,
            defaultInitializationString: nil)
    }

    private func getArrayTypeParser(elementType: ValdiModelPropertyType, namePaths: [String], nameAllocator: PropertyNameAllocator) throws -> CppTypeParser {
        let elementTypeParser = try getTypeParser(type: elementType, namePaths: namePaths + ["Element"], nameAllocator: nameAllocator)

        return CppTypeParser(typeName: "std::vector<\(elementTypeParser.typeName)>",
                             method: nil,
                             isMovable: true,
                             isIntrinsicallyNullable: false,
                             isTypeAlias: false,
                             defaultInitializationString: nil)
    }

    private func getTypeReferenceTypeParser(referencedType: CPPType,
                                            forwardDeclaration: String,
                                            isObject: Bool,
                                            nameAllocator: PropertyNameAllocator) throws -> CppTypeParser {
        let inserted = header.includeSection.addInclude(path: referencedType.includePath)
        let typeName = referencedType.declaration.resolveTypeName(inNamespace: namespace)

        if inserted {
            // Forward declare as well
            header.forwardDeclarations.appendBody(forwardDeclaration)
            header.forwardDeclarations.appendBody("\n")
            if isObject {
                referencedTypes.append(typeName)
            }
        }

        return CppTypeParser(
            typeName: isObject ? makeRefType(typeName: typeName) : typeName,
            method: nil,
            isMovable: isObject,
            isIntrinsicallyNullable: isObject,
            isTypeAlias: false,
            defaultInitializationString: nil
        )
    }

    // TODO(3521): Update to valid_core
    private func getUntypedTypeParser() -> CppTypeParser {
        header.includeSection.addInclude(path: "valdi_core/cpp/Utils/Value.hpp")
        return CppTypeParser(
            typeName: getValdiTypeName(typeName: "Value"),
            method: nil,
            isMovable: true,
            isIntrinsicallyNullable: true,
            isTypeAlias: false,
            defaultInitializationString: nil
        )
    }

    private func getFunctionTypeParser(parameters: [ValdiModelProperty], returnType: ValdiModelPropertyType, namePaths: [String], nameAllocator: PropertyNameAllocator) throws -> CppTypeParser {
        header.includeSection.addInclude(path: "valdi_core/cpp/Utils/Function.hpp")

        let returnTypeParser = try getTypeParser(type: returnType, namePaths: namePaths + ["Return"], nameAllocator: nameAllocator)

        let parameterTypeParsers = try parameters.map { ($0.name, try getTypeParser(type: $0.type, namePaths: namePaths + [$0.name], nameAllocator: nameAllocator)) }

        let parameterTypeNames = parameterTypeParsers.map { $1.typeName }.joined(separator: ", ")

        let typealiasFunctionName = nameAllocator.allocate(property: (namePaths + ["Fn"]).map { $0.pascalCased }.joined()).name

        let functionType = getValdiTypeName(typeName: "Function")
        let resultType = getValdiTypeName(typeName: "Result")
        let resolvedFunctionReturnType = "\(resultType)<\(returnType.isVoid ? getValdiTypeName(typeName: "Void") : returnTypeParser.typeName)>"

        let realTypeName = "\(functionType)<\(resolvedFunctionReturnType)(\(parameterTypeNames))>"

        var cppMethod: CppMethod?
        if namePaths.count == 1 {
            cppMethod = CppMethod(returnTypeName: resolvedFunctionReturnType, parameters: parameterTypeParsers.map { CppMethodParameter(name: $0, typeName: $1.typeName) })
        }

        typealiases.append(CppTypeAlias(statement: "using \(typealiasFunctionName) = \(realTypeName);\n", isOnMethod: cppMethod != nil))

        return CppTypeParser(typeName: typealiasFunctionName,
                             method: cppMethod,
                             isMovable: true,
                             isIntrinsicallyNullable: false,
                             isTypeAlias: true,
                             defaultInitializationString: nil)
    }

    func getTypeParser(type: ValdiModelPropertyType, namePaths: [String], nameAllocator: PropertyNameAllocator) throws -> CppTypeParser {
        switch type {
        case .string:
            header.includeSection.addInclude(path: "valdi_core/cpp/Utils/StringBox.hpp")
            return getPrimitiveTypeParser(primitiveType: getValdiTypeName(typeName: "StringBox"), isMovable: true, isIntrinsicallyNullable: false, defaultInitializationString: nil)
        case .double:
            return getPrimitiveTypeParser(primitiveType: "double", isMovable: false, isIntrinsicallyNullable: false, defaultInitializationString: "0.0")
        case .bool:
            return getPrimitiveTypeParser(primitiveType: "bool", isMovable: false, isIntrinsicallyNullable: false, defaultInitializationString: "false")
        case .long:
            return getPrimitiveTypeParser(primitiveType: "int64_t", isMovable: false, isIntrinsicallyNullable: false, defaultInitializationString: "0")
        case .array(elementType: let elementType):
            return try getArrayTypeParser(elementType: elementType, namePaths: namePaths, nameAllocator: nameAllocator)
        case .bytes:
            header.includeSection.addInclude(path: "valdi_core/cpp/Utils/ValueTypedArray.hpp")
            return getPrimitiveTypeParser(primitiveType: getValdiTypeName(typeName: "ValueTypedArray"), isMovable: true, isIntrinsicallyNullable: false, defaultInitializationString: nil)
        case .map:
            header.includeSection.addInclude(path: "valdi_core/cpp/Utils/ValueMap.hpp")
            return getPrimitiveTypeParser(primitiveType: makeRefType(typeName: getValdiTypeName(typeName: "ValueMap")), isMovable: true, isIntrinsicallyNullable: true, defaultInitializationString: nil)
        case .any:
            return getUntypedTypeParser()
        case .void:
            return CppTypeParser(
                typeName: "void",
                method: nil,
                isMovable: false,
                isIntrinsicallyNullable: false,
                isTypeAlias: false,
                defaultInitializationString: nil
            )
        case .function(parameters: let parameters, returnType: let returnType, _, _):
            return try getFunctionTypeParser(parameters: parameters, returnType: returnType, namePaths: namePaths, nameAllocator: nameAllocator)
        case .object(let type):
            guard let cppType = type.cppType else {
                if !type.isGenerated {
                    // No support for @NativeClass and @NativeInterface for now.
                    // We just export them as untyped
                    return getUntypedTypeParser()
                }

                throw CompilerError("No C++ type declared for referenced type \(type.tsType)")
            }

            return try getTypeReferenceTypeParser(referencedType: cppType,
                                                  forwardDeclaration: "class \(cppType.declaration.resolveTypeName(inNamespace: namespace));",
                                                  isObject: true,
                                                  nameAllocator: nameAllocator)
        case .genericTypeParameter:
            // TODO(simon): Implement
            return getUntypedTypeParser()
        case .genericObject:
            // TODO(simon): Implement
            return getUntypedTypeParser()
        case .promise:
            // TODO(simon): Implement
            return getUntypedTypeParser()
        case .enum(let type):
            guard let cppType = type.cppType else {
                if !type.isGenerated {
                    // No support for @NativeClass and @NativeInterface for now.
                    // We just export them as untyped
                    return getUntypedTypeParser()
                }

                throw CompilerError("No C++ type declared for referenced enum \(type.tsType)")
            }

            return try getTypeReferenceTypeParser(referencedType: cppType,
                                                  forwardDeclaration: "enum class \(cppType.declaration.resolveTypeName(inNamespace: namespace));",
                                                  isObject: false,
                                                  nameAllocator: nameAllocator)
        case .nullable(let elementType):
            let elementTypeParser = try getTypeParser(type: elementType, namePaths: namePaths, nameAllocator: nameAllocator)

            if elementTypeParser.isIntrinsicallyNullable {
                return elementTypeParser
            } else {
                return toOptionalTypeParser(typeParser: elementTypeParser)
            }
        }
    }

}
