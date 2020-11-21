import Foundation

/**
 Protocol to group predicates in brackets.
 */
public protocol GroupingPredicate: CompoundablePredicate {

    /**
     Compound prev predicate with a predicate group, using AND.
     
     - parameter group: a predicate group.
     
     - returns: self for chaining.
     */
    @discardableResult
    func and(_ group: Self) -> Self

    /**
     Compound prev predicate with a predicate group, using AND NOT.
     
     - parameter group: a predicate group.
     
     - returns: self for chaining.
     */
    @discardableResult
    func andNot(_ group: Self) -> Self

    /**
     Compound prev predicate with a predicate group, using OR.
     
     - parameter group: a predicate group.
     
     - returns: self for chaining.
     */
    @discardableResult
    func or(_ group: Self) -> Self

    /**
     Compound prev predicate with a predicate group, using OR NOT.
     
     - parameter group: a predicate group.
     
     - returns: self for chaining.
     */
    @discardableResult
    func orNot(_ group: Self) -> Self
}
