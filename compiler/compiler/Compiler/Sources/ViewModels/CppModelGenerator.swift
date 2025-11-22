//
//  CppModelGenerator.swift
//
//
//  Created by Simon Corsin on 4/11/23.
//

import Foundation

private struct CppPropertyName {
    let fieldName: String
    let getterName: String
    let setterName: String
    let constructorParameterName: String
}

private struct CppProperty {
    let name: CppPropertyName
    let property: ValdiModelProperty
    let typeParser: CppTypeParser
    let implementationTypeName: String
}

final class CppModelGenerator {
    private let cppType: CPPType
    private let bundleInfo: CompilationItem.BundleInfo
    private let typeParameters: [ValdiTypeParameter]?
    private let properties: [ValdiModelProperty]
    private let classMapping: ResolvedClassMapping
    private let sourceFileName: GeneratedSourceFilename
    private let isInterface: Bool
    private let comments: String?

    init(cppType: CPPType,
         bundleInfo: CompilationItem.BundleInfo,
         typeParameters: [ValdiTypeParameter]?,
         properties: [ValdiModelProperty],
         classMapping: ResolvedClassMapping,
         sourceFileName: GeneratedSourceFilename,
         isInterface: Bool,
         comments: String?) {
        self.cppType = cppType
        self.bundleInfo = bundleInfo
        self.typeParameters = typeParameters
        self.properties = properties
        self.classMapping = classMapping
        self.sourceFileName = sourceFileName
        self.isInterface = isInterface
        self.comments = comments
    }

    private func resolveProperties(codeGenerator: CppCodeGenerator) throws -> [CppProperty] {
        return try properties.map { property in
            let typeParser = try codeGenerator.getTypeParser(type: property.type, namePaths: [property.name], nameAllocator: codeGenerator.nameAllocator)
            let fieldName = codeGenerator.nameAllocator.allocate(property: "_\(property.name)").name
            let getterName = codeGenerator.nameAllocator.allocate(property: "get\(property.name.pascalCased)").name
            let setterName = codeGenerator.nameAllocator.allocate(property: "set\(property.name.pascalCased)").name
            let constructorParameterName = codeGenerator.nameAllocator.allocate(property: property.name).name
            let implementationTypeName = typeParser.isTypeAlias ? "\(cppType.declaration.name)::\(typeParser.typeName)" : typeParser.typeName

            return CppProperty(name:
                                CppPropertyName(fieldName: fieldName, getterName: getterName, setterName: setterName, constructorParameterName: constructorParameterName),
                               property: property,
                               typeParser: typeParser,
                               implementationTypeName: implementationTypeName)
        }
    }

    private func generateClassFields(cppProperties: [CppProperty]) -> CppCodeWriter {
        let decl = CppCodeWriter()
        for cppProperty in cppProperties {
            if let fieldInitializationString = cppProperty.typeParser.defaultInitializationString {
                decl.appendBody("\(cppProperty.typeParser.typeName) \(cppProperty.name.fieldName) = \(fieldInitializationString);\n")
            } else {
                decl.appendBody("\(cppProperty.typeParser.typeName) \(cppProperty.name.fieldName);\n")
            }
        }

        return decl
    }

    private func generateClassConstructors(cppProperties: [CppProperty]) -> (decl: CppCodeWriter, impl: CppCodeWriter) {
        let constructorsDecl = CppCodeWriter()
        constructorsDecl.appendBody("\(cppType.declaration.name)();\n")

        let constructorsImpl = CppCodeWriter()
        constructorsImpl.appendBody("\(cppType.declaration.name)::\(cppType.declaration.name)() = default;\n\n")

        if !cppProperties.isEmpty {
            let ctorDeclParameters = cppProperties.map { "\($0.typeParser.typeName) \($0.name.constructorParameterName)" }.joined(separator: ", ")
            let ctorImplParameters = cppProperties.map { "\($0.implementationTypeName) \($0.name.constructorParameterName)" }.joined(separator: ", ")
            let ctorFieldInitializers = cppProperties.map {
                let initializer = $0.typeParser.isMovable ? "std::move(\($0.name.constructorParameterName))" : $0.name.constructorParameterName
                return "\($0.name.fieldName)(\(initializer))"
            }.joined(separator: ",\n")

            constructorsDecl.appendBody("\(cppType.declaration.name)(\(ctorDeclParameters));\n")
            constructorsImpl.appendBody("""
            \(cppType.declaration.name)::\(cppType.declaration.name)(\(ctorImplParameters)):
            \(ctorFieldInitializers) {
            }


            """)
        }

        return (constructorsDecl, constructorsImpl)
    }

    private func generateClassMethods(cppProperties: [CppProperty]) -> (decl: CppCodeWriter, impl: CppCodeWriter) {
        let decl = CppCodeWriter()
        let impl = CppCodeWriter()

        for cppProperty in cppProperties {
            if cppProperty.typeParser.isMovable {
                decl.appendBody("""
                    const \(cppProperty.typeParser.typeName) &\(cppProperty.name.getterName)() const;
                    void \(cppProperty.name.setterName)(const \(cppProperty.typeParser.typeName) &value);
                    void \(cppProperty.name.setterName)(\(cppProperty.typeParser.typeName) value);


                    """)

                impl.appendBody("""
                    const \(cppProperty.implementationTypeName) &\(cppType.declaration.name)::\(cppProperty.name.getterName)() const {
                      return \(cppProperty.name.fieldName);
                    }

                    void \(cppType.declaration.name)::\(cppProperty.name.setterName)(const \(cppProperty.implementationTypeName) &value) const {
                      \(cppProperty.name.fieldName) = value;
                    }

                    void \(cppType.declaration.name)::\(cppProperty.name.setterName)(\(cppProperty.implementationTypeName) value) const {
                      \(cppProperty.name.fieldName) = std::move(value);
                    }


                    """)
            } else {
                decl.appendBody("""
                    \(cppProperty.typeParser.typeName) \(cppProperty.name.getterName)() const;
                    void \(cppProperty.name.setterName)(\(cppProperty.typeParser.typeName) value);


                    """)

                impl.appendBody("""
                    \(cppProperty.implementationTypeName) \(cppType.declaration.name)::\(cppProperty.name.getterName)() const {
                      return \(cppProperty.name.fieldName);
                    }

                    void \(cppType.declaration.name)::\(cppProperty.name.setterName)(\(cppProperty.implementationTypeName) value) const {
                      \(cppProperty.name.fieldName) = value;
                    }


                    """)
            }
        }

        return (decl, impl)
    }

    private func generateRegisterClassBody(generator: CppCodeGenerator) throws -> CppCodeWriter {
        let cppGeneratedClass = generator.getValdiTypeName(typeName: "CppGeneratedClass")
        let registeredClassType = generator.getValdiTypeName(typeName: "RegisteredCppGeneratedClass")

        let schemaWriter = CppSchemaWriter(typeParameters: typeParameters)
        if isInterface {
            try schemaWriter.appendInterface(cppType.declaration.fullTypeName, properties: self.properties)
        } else {
            try schemaWriter.appendClass(cppType.declaration.fullTypeName, properties: self.properties)
        }

        let typeReferencesVecString = generator.referencedTypes.map { "&\($0)::registeredClass" }.joined(separator: ", ")

        let writer = CppCodeWriter()

        writer.appendBody("""
        \(registeredClassType) *\(cppType.declaration.name)::getRegisteredClass() const {
            return &\(cppType.declaration.name)::registeredClass;
        }

       \(registeredClassType) \(cppType.declaration.name)::registeredClass = \(cppGeneratedClass)::registerSchema("\(schemaWriter.str)", []() -> \(registeredClassType)::TypeReferencesVec {
           return {\(typeReferencesVecString)};
       });


       """)

        return writer
    }

    private func generateFieldsReferenceArgument(cppProperties: [CppProperty]) -> String {
        if cppProperties.isEmpty {
            return ""
        } else {
            let fieldsReferenceString = cppProperties.map { "self.\($0.name.fieldName)" }.joined(separator: ", ")
            return ", \(fieldsReferenceString)"
        }
    }

    private func generateMethodsReferenceArgument(receiverArgument: String, cppProperties: [CppProperty]) -> String {
        if cppProperties.isEmpty {
            return ""
        } else {
            let methodsReferenceString = cppProperties.map { cppProperty in
                if cppProperty.typeParser.method != nil {
                    // TODO(3521): Update to Valdi
                    return "Valdi::CppMarshaller::methodToFunction(\(receiverArgument), &\(cppType.declaration.name)::\(cppProperty.name.constructorParameterName))"
                } else {
                    return "\(receiverArgument)->\(cppProperty.name.constructorParameterName)()"
                }
            }.joined(separator: ", ")
            return ", \(methodsReferenceString)"
        }
    }

    private func writeClass(generator: CppCodeGenerator, cppProperties: [CppProperty]) throws {
        let parentClassName = generator.getValdiTypeName(typeName: "CppGeneratedModel")
        let cppTypeRefType = generator.makeRefType(typeName: cppType.declaration.name)
        let exceptionTrackerTypeName = generator.getValdiTypeName(typeName: "ExceptionTracker")
        let valueType = generator.getValdiTypeName(typeName: "Value")
        let registeredClassType = generator.getValdiTypeName(typeName: "RegisteredCppGeneratedClass")

        let (constructorsDecl, constructorsImpl) = generateClassConstructors(cppProperties: cppProperties)
        let (methodsDecl, methodsImpl) = generateClassMethods(cppProperties: cppProperties)
        let fieldsDeclaration = generateClassFields(cppProperties: cppProperties)
        let registerClassBody = try generateRegisterClassBody(generator: generator)

        /* Header generation */
        generator.header.body.appendBody("class \(cppType.declaration.name): public \(parentClassName) {\n")
        generator.header.body.appendBody("public:\n")
        if !generator.typealiases.isEmpty {
            for cppTypealias in generator.typealiases {
                generator.header.body.appendBody(cppTypealias.statement)
            }
            generator.header.body.appendBody("\n")
        }

        generator.header.body.appendBody(constructorsDecl)
        generator.header.body.appendBody("\n")
        generator.header.body.appendBody(methodsDecl)
        generator.header.body.appendBody("""

        \(registeredClassType) *getRegisteredClass() const final;

        static void unmarshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(valueType) &value, \(cppTypeRefType) &out);
        static void marshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(cppTypeRefType) &value, \(valueType) &out);

        static \(registeredClassType) registeredClass;

        """)

        generator.header.body.appendBody("\nprivate:\n")
        generator.header.body.appendBody(fieldsDeclaration)
        generator.header.body.appendBody("};\n")

        /* Impl generation */

        generator.impl.body.appendBody(constructorsImpl)
        generator.impl.body.appendBody(methodsImpl)

        let fieldsReferenceArguments = generateFieldsReferenceArgument(cppProperties: cppProperties)

        let unmarshallTypedObjectString = "Valdi::CppMarshaller::unmarshallTypedObject(exceptionTracker, \(cppType.declaration.name)::registeredClass, value\(fieldsReferenceArguments));"
        let marshallTypedObjectString = "Valdi::CppMarshaller::marshallTypedObject(exceptionTracker, \(cppType.declaration.name)::registeredClass, out\(fieldsReferenceArguments));"

        generator.impl.body.appendBody("""

        void \(cppType.declaration.name)::unmarshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(valueType) &value, \(cppTypeRefType) &out) {
           out = Valdi::makeShared<\(cppType.declaration.name)>();
           auto &self = *out;
           \(unmarshallTypedObjectString)
       }

        void \(cppType.declaration.name)::marshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(cppTypeRefType) &value, \(valueType) &out) {
           auto &self = *value;
          \(marshallTypedObjectString)
       }


       """)

        generator.impl.body.appendBody(registerClassBody)
    }

    private func generateInterfaceMethods(generator: CppCodeGenerator, cppProperties: [CppProperty]) -> (decl: CppCodeWriter, impl: CppCodeWriter) {
        let decl = CppCodeWriter()
        let impl = CppCodeWriter()

        for cppProperty in cppProperties {
            let scopedNameAllocator = generator.nameAllocator.scoped()

            if let cppMethod = cppProperty.typeParser.method {
                let parameterNames = cppMethod.parameters.map { scopedNameAllocator.allocate(property: $0.name).name }
                let parameterWithTypes = cppMethod.parameters.indices.map {
                    let parameterName = parameterNames[$0]
                    let parameterType = cppMethod.parameters[$0].typeName
                    return "\(parameterType) \(parameterName)"
                }.joined(separator: ", ")

                decl.appendBody("virtual \(cppMethod.returnTypeName) \(cppProperty.name.constructorParameterName)(\(parameterWithTypes)) = 0;\n")

                impl.appendBody("""
                \(cppMethod.returnTypeName) \(cppProperty.name.constructorParameterName)(\(parameterWithTypes)) final {
                  return \(cppProperty.name.fieldName)(\(parameterNames.joined(separator: ", ") ));
                }


                """)
            } else {
                decl.appendBody("virtual \(cppProperty.typeParser.typeName) \(cppProperty.name.constructorParameterName)() = 0;\n")

                impl.appendBody("""
                \(cppProperty.typeParser.typeName) \(cppProperty.name.constructorParameterName)() final {
                  return \(cppProperty.name.fieldName);
                }
                """)
            }
        }

        return (decl, impl)
    }

    private func writeInterface(generator: CppCodeGenerator, cppProperties: [CppProperty]) throws {
        let parentClassName = generator.getValdiTypeName(typeName: "CppGeneratedInterface")
        let registeredClassType = generator.getValdiTypeName(typeName: "RegisteredCppGeneratedClass")
        let exceptionTrackerTypeName = generator.getValdiTypeName(typeName: "ExceptionTracker")
        let valueType = generator.getValdiTypeName(typeName: "Value")
        let cppTypeRefType = generator.makeRefType(typeName: cppType.declaration.name)
        let registerClassBody = try generateRegisterClassBody(generator: generator)

        let (methodsDecl, methodsImpl) = generateInterfaceMethods(generator: generator, cppProperties: cppProperties)
        let fieldsDeclaration = generateClassFields(cppProperties: cppProperties)

        /* Header generation */
        generator.header.body.appendBody("class \(cppType.declaration.name): public \(parentClassName) {\n")
        generator.header.body.appendBody("public:\n")
        let nonMethodsTypealiases = generator.typealiases.filter { !$0.isOnMethod }
        if !nonMethodsTypealiases.isEmpty {
            for cppTypealias in nonMethodsTypealiases {
                generator.header.body.appendBody(cppTypealias.statement)
            }
            generator.header.body.appendBody("\n")
        }

        generator.header.body.appendBody(methodsDecl)
        generator.header.body.appendBody("""

        \(registeredClassType) *getRegisteredClass() const final;

        static void unmarshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(valueType) &value, \(cppTypeRefType) &out);
        static void marshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(cppTypeRefType) &value, \(valueType) &out);

        static \(registeredClassType) registeredClass;

        """)
        generator.header.body.appendBody("};\n")

        /* Impl generation */

        let proxyClassName = generator.nameAllocator.allocate(property: "\(cppType.declaration.name)Proxy")

        generator.impl.body.appendBody("class \(proxyClassName.name): public \(cppType.declaration.name) {\n")
        generator.impl.body.appendBody("public:\n")

        let methodsTypealiases = generator.typealiases.filter { $0.isOnMethod }
        if !methodsTypealiases.isEmpty {
            for cppTypealias in methodsTypealiases {
                generator.impl.body.appendBody(cppTypealias.statement)
            }
            generator.impl.body.appendBody("\n")
        }

        generator.impl.body.appendBody("\(proxyClassName.name)() = default;\n")
        generator.impl.body.appendBody("~\(proxyClassName.name)() override = default;\n\n")
        generator.impl.body.appendBody(methodsImpl)

        let fieldsReferenceArguments = generateFieldsReferenceArgument(cppProperties: cppProperties)
        let methodsReferenceArguments = generateMethodsReferenceArgument(receiverArgument: "value", cppProperties: cppProperties)
        let unmarshallTypedObjectString = "Valdi::CppMarshaller::unmarshallTypedObject(exceptionTracker, \(cppType.declaration.name)::registeredClass, value\(fieldsReferenceArguments));"

        generator.impl.body.appendBody("""
        static void unmarshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(valueType) &value, \(generator.makeRefType(typeName: proxyClassName.name)) &out) {
             out = Valdi::makeShared<\(proxyClassName.name)>();
             auto &self = *out;
           \(unmarshallTypedObjectString)
        }


        """)

        generator.impl.body.appendBody("private:\n")
        generator.impl.body.appendBody(fieldsDeclaration)
        generator.impl.body.appendBody("};\n\n")

        generator.impl.body.appendBody("""

        void \(cppType.declaration.name)::unmarshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(valueType) &value, \(cppTypeRefType) &out) {
           Valdi::CppMarshaller::unmarshallProxyObject<\(proxyClassName.name)>(exceptionTracker, \(cppType.declaration.name)::registeredClass, value, out);
       }

        void \(cppType.declaration.name)::marshall(\(exceptionTrackerTypeName) &exceptionTracker, const \(cppTypeRefType) &value, \(valueType) &out) {
           Valdi::CppMarshaller::marshallProxyObject(exceptionTracker, \(cppType.declaration.name)::registeredClass, *value, out, [&]() {
              Valdi::CppMarshaller::marshallTypedObject(exceptionTracker, \(cppType.declaration.name)::registeredClass, out\(methodsReferenceArguments));
           });
       }


       """)

        generator.impl.body.appendBody(registerClassBody)
    }

    func write() throws -> [NativeSource] {
        let generator = CppCodeGenerator(namespace: cppType.declaration.namespace)
        ["getRegisteredClass", "registeredClass"].forEach {
            _ = generator.nameAllocator.allocate(property: $0)
        }

        // TODO(3521): Update to valdi_core
        generator.header.includeSection.addInclude(path: "valdi_core/cpp/Utils/CppGeneratedClass.hpp")

        generator.impl.includeSection.addInclude(path: cppType.includePath)
        generator.impl.includeSection.addInclude(path: "valdi_core/cpp/Utils/CppMarshaller.hpp")

        let cppProperties = try resolveProperties(codeGenerator: generator)

        if isInterface {
            try writeInterface(generator: generator, cppProperties: cppProperties)
        } else {
            try writeClass(generator: generator, cppProperties: cppProperties)
        }

        return [
            NativeSource(relativePath: nil,
                         filename: "\(cppType.declaration.name).hpp",
                         file: .data(try generator.header.content.indented.utf8Data()),
                         groupingIdentifier: "\(bundleInfo.name).hpp", groupingPriority: 0),
            NativeSource(relativePath: nil,
                         filename: "\(cppType.declaration.name).cpp",
                         file: .data(try generator.impl.content.indented.utf8Data()),
                         groupingIdentifier: "\(bundleInfo.name).cpp", groupingPriority: 0)
        ]
    }
}
