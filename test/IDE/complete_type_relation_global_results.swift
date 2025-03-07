// RUN: %empty-directory(%t)
// RUN: %empty-directory(%t/ImportPath)
// RUN: %{python} %utils/split_file.py -o %t %s

// RUN: %target-swift-frontend -disable-availability-checking -emit-module %t/Lib.swift -o %t/ImportPath/Lib.swiftmodule -emit-module-interface-path %t/ImportPath/Lib.swiftinterface

// BEGIN Lib.swift

public protocol MyBaseProto {}

public protocol MyProto: MyBaseProto {}

public protocol MyOtherProto {}

public struct Foo: MyProto {
	public init() {}
}
public struct Bar: MyOtherProto {
	public init() {}
}
public struct FooBar: MyProto, MyOtherProto {
	public init() {}
}

public func makeFoo() -> Foo {
	return Foo()
}

public let GLOBAL_FOO = Foo()

public class MyClass {}
public class MySubclass: MyClass {}
public class MySubclassConformingToMyProto: MyClass, MyProto {}

public func makeMyClass() -> MyClass { return MyClass() }
public func makeMySubclass() -> MySubclass { return MySubclass() }

public func returnSomeMyProto() -> some MyProto { return Foo() }

public protocol ProtoWithAssocType {
  associatedtype MyAssoc
}

public struct StructWithAssocType: ProtoWithAssocType {
  public typealias MyAssoc = Int
}

public func makeProtoWithAssocType() -> some ProtoWithAssocType { return StructWithAssocType() }

// BEGIN test.swift

import Lib

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token COMPLETE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s
// Perform the same completion again, this time using the code completion cache that implicitly gets added to swift-ide-test
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token COMPLETE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s

func test() -> MyProto {
	return #^COMPLETE^#
}

// CHECK: Begin completions
// CHECK-DAG: Decl[Struct]/OtherModule[Lib]/TypeRelation[Convertible]: Foo[#Foo#];
// CHECK-DAG: Decl[GlobalVar]/OtherModule[Lib]/TypeRelation[Convertible]: GLOBAL_FOO[#Foo#];
// CHECK-DAG: Decl[Struct]/OtherModule[Lib]:      Bar[#Bar#];
// CHECK-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]/TypeRelation[Identical]: MyProto[#MyProto#];
// CHECK-DAG: Decl[FreeFunction]/OtherModule[Lib]/TypeRelation[Convertible]: makeFoo()[#Foo#];
// CHECK-DAG: Decl[FreeFunction]/OtherModule[Lib]/TypeRelation[Identical]: returnSomeMyProto()[#MyProto#];
// CHECK: End completions


// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token COMPLETE_OPAQUE_COMPOSITION -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=COMPLETE_OPAQUE_COMPOSITION
// Perform the same completion again, this time using the code completion cache that implicitly gets added to swift-ide-test
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token COMPLETE_OPAQUE_COMPOSITION -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=COMPLETE_OPAQUE_COMPOSITION

func testOpaqueComposition() -> some MyProto & MyOtherProto {
	return #^COMPLETE_OPAQUE_COMPOSITION^#
}

// COMPLETE_OPAQUE_COMPOSITION: Begin completions
// COMPLETE_OPAQUE_COMPOSITION-DAG: Decl[Struct]/OtherModule[Lib]: Foo[#Foo#];
// COMPLETE_OPAQUE_COMPOSITION-DAG: Decl[GlobalVar]/OtherModule[Lib]: GLOBAL_FOO[#Foo#];
// COMPLETE_OPAQUE_COMPOSITION-DAG: Decl[Struct]/OtherModule[Lib]:      Bar[#Bar#];
// COMPLETE_OPAQUE_COMPOSITION-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]: MyProto[#MyProto#];
// COMPLETE_OPAQUE_COMPOSITION-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeFoo()[#Foo#];
// COMPLETE_OPAQUE_COMPOSITION-DAG: Decl[Struct]/OtherModule[Lib]/TypeRelation[Convertible]: FooBar[#FooBar#];
// COMPLETE_OPAQUE_COMPOSITION: End completions

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token ALSO_CONSIDER_METATYPE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=ALSO_CONSIDER_METATYPE
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token ALSO_CONSIDER_METATYPE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=ALSO_CONSIDER_METATYPE

func testAlsoConsiderMetatype() -> MyClass.Type {
  return #^ALSO_CONSIDER_METATYPE^#
}
// ALSO_CONSIDER_METATYPE: Begin completions
// ALSO_CONSIDER_METATYPE-DAG: Decl[Class]/OtherModule[Lib]/TypeRelation[Identical]: MyClass[#MyClass#];
// FIXME: MySubclass should be 'Convertible' but we don't currently store metatype supertypes in USRBasedType.
// ALSO_CONSIDER_METATYPE-DAG: Decl[Class]/OtherModule[Lib]: MySubclass[#MySubclass#];
// ALSO_CONSIDER_METATYPE: End completions

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token OPAQUE_WITH_CLASS -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=OPAQUE_WITH_CLASS
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token OPAQUE_WITH_CLASS -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=OPAQUE_WITH_CLASS
func testOpaqueWithClass<T: MyClass & MyProto>() -> T {
  return #^OPAQUE_WITH_CLASS^#
}

// FIXME: We don't support USR-based type comparison in generic contexts. MySubclassConformingToMyProto should be 'Convertible'
// OPAQUE_WITH_CLASS: Begin completions
// OPAQUE_WITH_CLASS-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeMySubclass()[#MySubclass#];
// OPAQUE_WITH_CLASS-DAG: Decl[Class]/OtherModule[Lib]:       MySubclass[#MySubclass#];
// OPAQUE_WITH_CLASS-DAG: Decl[Class]/OtherModule[Lib]: MySubclassConformingToMyProto[#MySubclassConformingToMyProto#];
// OPAQUE_WITH_CLASS-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeMyClass()[#MyClass#];
// OPAQUE_WITH_CLASS-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]: MyProto[#MyProto#];
// OPAQUE_WITH_CLASS-DAG: Decl[FreeFunction]/OtherModule[Lib]: returnSomeMyProto()[#MyProto#];
// OPAQUE_WITH_CLASS: End completions

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token GENERIC_RETURN -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=GENERIC_RETURN
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token GENERIC_RETURN -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=GENERIC_RETURN
func testGenericReturn<T: MyProto>() -> T {
  return #^GENERIC_RETURN^#
}

// FIXME: We don't support USR-based type comparison in generic contexts. MyProto and returnMyProto should be 'Identical'. makeFoo and FooBar should be 'Convertible'
// GENERIC_RETURN: Begin completions
// GENERIC_RETURN-DAG: Decl[Struct]/OtherModule[Lib]: Foo[#Foo#];
// GENERIC_RETURN-DAG: Decl[GlobalVar]/OtherModule[Lib]: GLOBAL_FOO[#Foo#];
// GENERIC_RETURN-DAG: Decl[Struct]/OtherModule[Lib]:      Bar[#Bar#];
// GENERIC_RETURN-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]: MyProto[#MyProto#];
// GENERIC_RETURN-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeFoo()[#Foo#];
// GENERIC_RETURN-DAG: Decl[Struct]/OtherModule[Lib]: FooBar[#FooBar#];
// GENERIC_RETURN-DAG: Decl[FreeFunction]/OtherModule[Lib]: returnSomeMyProto()[#MyProto#];
// GENERIC_RETURN: End completions

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token OPAQUE_CLASS_AND_PROTOCOL -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=OPAQUE_CLASS_AND_PROTOCOL
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token OPAQUE_CLASS_AND_PROTOCOL -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=OPAQUE_CLASS_AND_PROTOCOL
func testGenericReturn() -> some MyClass & MyProto {
  return #^OPAQUE_CLASS_AND_PROTOCOL^#
}

// OPAQUE_CLASS_AND_PROTOCOL: Begin completions
// OPAQUE_CLASS_AND_PROTOCOL-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeMySubclass()[#MySubclass#];
// OPAQUE_CLASS_AND_PROTOCOL-DAG: Decl[Class]/OtherModule[Lib]:       MySubclass[#MySubclass#];
// OPAQUE_CLASS_AND_PROTOCOL-DAG: Decl[Class]/OtherModule[Lib]/TypeRelation[Convertible]: MySubclassConformingToMyProto[#MySubclassConformingToMyProto#];
// OPAQUE_CLASS_AND_PROTOCOL-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeMyClass()[#MyClass#];
// OPAQUE_CLASS_AND_PROTOCOL-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]: MyProto[#MyProto#];
// OPAQUE_CLASS_AND_PROTOCOL-DAG: Decl[FreeFunction]/OtherModule[Lib]: returnSomeMyProto()[#MyProto#];
// OPAQUE_CLASS_AND_PROTOCOL: End completions

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token TRANSITIVE_CONFORMANCE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=TRANSITIVE_CONFORMANCE
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token TRANSITIVE_CONFORMANCE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=TRANSITIVE_CONFORMANCE
func testGenericReturn() -> MyBaseProto {
  return #^TRANSITIVE_CONFORMANCE^#
}

// TRANSITIVE_CONFORMANCE: Begin completions
// TRANSITIVE_CONFORMANCE-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]: MyOtherProto[#MyOtherProto#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Class]/OtherModule[Lib]:       MyClass[#MyClass#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[FreeFunction]/OtherModule[Lib]/TypeRelation[Convertible]: makeFoo()[#Foo#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Struct]/OtherModule[Lib]/TypeRelation[Convertible]: Foo[#Foo#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[FreeFunction]/OtherModule[Lib]/TypeRelation[Convertible]: returnSomeMyProto()[#MyProto#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[GlobalVar]/OtherModule[Lib]/TypeRelation[Convertible]: GLOBAL_FOO[#Foo#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]/TypeRelation[Identical]: MyBaseProto[#MyBaseProto#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Struct]/OtherModule[Lib]:      Bar[#Bar#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Class]/OtherModule[Lib]/TypeRelation[Convertible]: MySubclassConformingToMyProto[#MySubclassConformingToMyProto#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Struct]/OtherModule[Lib]/TypeRelation[Convertible]: FooBar[#FooBar#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeMyClass()[#MyClass#];
// TRANSITIVE_CONFORMANCE-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]/TypeRelation[Convertible]: MyProto[#MyProto#];
// TRANSITIVE_CONFORMANCE: End completions


// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token PROTO_WITH_ASSOC_TYPE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=PROTO_WITH_ASSOC_TYPE
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token PROTO_WITH_ASSOC_TYPE -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=PROTO_WITH_ASSOC_TYPE
func protoWithAssocType() -> ProtoWithAssocType {
  return #^PROTO_WITH_ASSOC_TYPE^#
}

// PROTO_WITH_ASSOC_TYPE: Begin completions
// PROTO_WITH_ASSOC_TYPE-DAG: Decl[Struct]/OtherModule[Lib]/TypeRelation[Convertible]: StructWithAssocType[#StructWithAssocType#];
// PROTO_WITH_ASSOC_TYPE-DAG: Decl[FreeFunction]/OtherModule[Lib]/TypeRelation[Identical]: makeProtoWithAssocType()[#ProtoWithAssocType#];
// PROTO_WITH_ASSOC_TYPE-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]/TypeRelation[Identical]: ProtoWithAssocType[#ProtoWithAssocType#];
// PROTO_WITH_ASSOC_TYPE: End completions

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token PROTO_WITH_ASSOC_TYPE_OPAQUE_CONTEXT -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=PROTO_WITH_ASSOC_TYPE
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token PROTO_WITH_ASSOC_TYPE_OPAQUE_CONTEXT -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=PROTO_WITH_ASSOC_TYPE
func protoWithAssocTypeInOpaqueContext() -> some ProtoWithAssocType {
  return #^PROTO_WITH_ASSOC_TYPE_OPAQUE_CONTEXT^#
}

// RUN: %empty-directory(%t/completion-cache)
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT -completion-cache-path %t/completion-cache -I %t/ImportPath
// Perform the same completion again, this time using the code completion cache
// RUN: %target-swift-ide-test -code-completion -source-filename %t/test.swift -code-completion-token PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT -completion-cache-path %t/completion-cache -I %t/ImportPath | %FileCheck %s --check-prefix=PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT
func protoWithAssocTypeInGenericContext<T: ProtoWithAssocType>() -> T {
  return #^PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT^#
}

// PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT: Begin completions
// PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT-DAG: Decl[Struct]/OtherModule[Lib]: StructWithAssocType[#StructWithAssocType#];
// PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT-DAG: Decl[FreeFunction]/OtherModule[Lib]: makeProtoWithAssocType()[#ProtoWithAssocType#];
// PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT-DAG: Decl[Protocol]/OtherModule[Lib]/Flair[RareType]: ProtoWithAssocType[#ProtoWithAssocType#];
// PROTO_WITH_ASSOC_TYPE_GENERIC_RETURN_CONTEXT: End completions

