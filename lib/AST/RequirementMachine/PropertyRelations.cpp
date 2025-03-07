//===--- PropertyRelations.cpp - Relations between property rules ---------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/AST/Type.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include "RewriteSystem.h"

using namespace swift;
using namespace rewriting;

RewriteSystem::Relation
RewriteSystem::getRelation(unsigned index) const {
  return Relations[index];
}

/// Record a relation that transforms the left hand side when it appears
/// at the end of a term to the right hand side. Returns the relation ID,
/// which can be passed to RewriteStep::forRelation().
unsigned RewriteSystem::recordRelation(Term lhs, Term rhs) {
  auto key = std::make_pair(lhs, rhs);
  auto found = RelationMap.find(key);
  if (found != RelationMap.end())
    return found->second;

  unsigned index = Relations.size();
  Relations.push_back(key);
  auto inserted = RelationMap.insert(std::make_pair(key, index));
  assert(inserted.second);
  (void) inserted;

  return index;
}

/// Given a left-hand side symbol [p1] and a right-hand side symbol
/// [p2], record a relation ([p1].[p2] => [p1]), which denotes that
/// the property p1 implies the property p2.
///
/// An example is a superclass requirement that implies a layout
/// requirement.
unsigned RewriteSystem::recordRelation(Symbol lhsProperty,
                                       Symbol rhsProperty) {
  assert(lhsProperty.isProperty());
  assert(rhsProperty.isProperty());

  MutableTerm lhsTerm;
  lhsTerm.add(lhsProperty);
  lhsTerm.add(rhsProperty);

  MutableTerm rhsTerm;
  rhsTerm.add(lhsProperty);

  // Record a relation ([p1].[p2] => [p1]).
  return recordRelation(
      Term::get(lhsTerm, Context),
      Term::get(rhsTerm, Context));
}

/// Record a relation ([concrete: C].[P] => [concrete: C : P])
/// or ([superclass: C].[P] => [concrete: C : P]) which combines a
/// concrete type symbol (or a superclass symbol) with a protocol
/// symbol to form a single a concrete conformance symbol.
unsigned RewriteSystem::recordConcreteConformanceRelation(
    Symbol concreteSymbol, Symbol protocolSymbol,
    Symbol concreteConformanceSymbol) {
  assert(protocolSymbol.getKind() == Symbol::Kind::Protocol);
  assert(protocolSymbol.getProtocol() ==
         concreteConformanceSymbol.getProtocol());
  assert(concreteSymbol.getKind() == Symbol::Kind::Superclass ||
         concreteSymbol.getKind() == Symbol::Kind::ConcreteType);

  MutableTerm lhsTerm;
  lhsTerm.add(concreteSymbol);
  lhsTerm.add(protocolSymbol);

  MutableTerm rhsTerm;
  rhsTerm.add(concreteConformanceSymbol);

  return recordRelation(
      Term::get(lhsTerm, Context),
      Term::get(rhsTerm, Context));
}

/// Record a relation ([concrete: C : P].[P:X].[concrete: C.X] =>
/// [concrete: C : P].[P:X]) which "concretizes" a nested type C.X of a
/// type parameter conforming to P known to equal the concrete type C.
unsigned RewriteSystem::recordConcreteTypeWitnessRelation(
    Symbol concreteConformanceSymbol,
    Symbol associatedTypeSymbol,
    Symbol typeWitnessSymbol) {
  assert(concreteConformanceSymbol.getKind() ==
         Symbol::Kind::ConcreteConformance);
  assert(associatedTypeSymbol.getKind() ==
         Symbol::Kind::AssociatedType);
  assert(concreteConformanceSymbol.getProtocol() ==
         associatedTypeSymbol.getProtocol());
  assert(typeWitnessSymbol.getKind() == Symbol::Kind::ConcreteType);

  MutableTerm rhsTerm;
  rhsTerm.add(concreteConformanceSymbol);
  rhsTerm.add(associatedTypeSymbol);

  MutableTerm lhsTerm(rhsTerm);
  lhsTerm.add(typeWitnessSymbol);

  return recordRelation(
      Term::get(lhsTerm, Context),
      Term::get(rhsTerm, Context));
}

/// Record a relation ([concrete: C : P].[P:X].[concrete: C] =>
/// [concrete: C : P].[P:X]) which "ties off" a nested type C.X that is
/// equivalent to C.
unsigned RewriteSystem::recordSameTypeWitnessRelation(
    Symbol concreteConformanceSymbol,
    Symbol associatedTypeSymbol) {
  assert(concreteConformanceSymbol.getKind() ==
         Symbol::Kind::ConcreteConformance);
  assert(associatedTypeSymbol.getKind() ==
         Symbol::Kind::AssociatedType);

  MutableTerm rhsTerm;
  rhsTerm.add(concreteConformanceSymbol);

  auto concreteSymbol = Symbol::forConcreteType(
      concreteConformanceSymbol.getConcreteType(),
      concreteConformanceSymbol.getSubstitutions(),
      Context);
  MutableTerm lhsTerm(rhsTerm);
  lhsTerm.add(associatedTypeSymbol);
  lhsTerm.add(concreteSymbol);

  return recordRelation(
      Term::get(lhsTerm, Context),
      Term::get(rhsTerm, Context));
}