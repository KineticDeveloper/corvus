import Vapor
import Fluent

/// A class that wraps a component which utilizes a `.children()` modifier. That
/// allows Corvus to chain modifiers, as it gets treated as any other struct
/// conforming to `ReadEndpoint`.
public final class ChildrenModifier<Q: ReadEndpoint, E: CorvusModel>:
ReadEndpoint {

    /// The type of the value loaded with the `.children()` modifier.
    public typealias Element = [E]

    /// The return value of the `.handler()`, so the type being operated on in
    /// the current component.
    public typealias QuerySubject = Q.QuerySubject

    /// The `KeyPath` to the related attribute of the `QuerySubject` that is to
    /// be loaded.
    public typealias Path = KeyPath<Q.QuerySubject, Q.QuerySubject.Children<E>>

    /// The `ReadEndpoint` the `.with()` modifier is attached to.
    let queryEndpoint: Q

    /// The `KeyPath` passed to the `QuerySubject`.
    let path: Path

    /// Initializes the modifier with its underlying `QueryEndpoint` and its
    /// `with` relation, which is the keypath to the related property.
    ///
    /// - Parameters:
    ///     - queryEndpoint: The `QueryEndpoint` which the modifer is attached
    ///     to.
    ///     - with: A `KeyPath` which leads to the desired property.
    public init(_ queryEndpoint: Q, path: Path) {
        self.queryEndpoint = queryEndpoint
        self.path = path
    }

    /// Builds a query on the `queryEndpoint`'s query by attaching a with query
    /// modifier.
    ///
    /// - Parameter req: An incoming `Request`.
    /// - Returns: A `QueryBuilder`, which represents a `Fluent` query after
    /// having attached a with modifier to the `queryEndpoint`'s query.
    public func query(_ req: Request) throws -> QueryBuilder<QuerySubject> {
        try queryEndpoint.query(req).with(path)
    }

    /// A method which eager loads objects related to the `QuerySubject` as
    /// defined by the `KeyPath`.
    ///
    /// - Parameter req: An incoming `Request`.
    /// - Returns: An `EventLoopFuture` containing an eagerloaded value as
    /// defined by `Element`.
    public func handler(_ req: Request) throws -> EventLoopFuture<Element> {
        try query(req).first().flatMapThrowing { optionalItem in
            guard let item = optionalItem else {
                throw Abort(.notFound)
            }
            
            guard let eagerLoaded = item[keyPath: self.path].value else {
                throw Abort(.notFound)
            }
            
            return eagerLoaded
        }
    }

    /// A method that registers the `.handler()` to the supplied `RoutesBuilder`.
    ///
    /// - Parameter routes: A `RoutesBuilder` containing all the information
    /// about the HTTP route leading to the current component.
    public func register(to routes: RoutesBuilder) {
        routes.get(use: handler)
    }
}

/// An extension that adds a `.children()` modifier to `ReadEndpoints`.
extension ReadEndpoint {

    /// A modifier used to return items related to a component as defined by a
    /// given `KeyPath`.
    ///
    /// - Parameter with: A `KeyPath` to the related property.
    /// - Returns: An instance of a `ChildrenModifier` with the supplied
    /// `KeyPath` to the relationship.
    public func children<M: CorvusModel>(
        _ path: ChildrenModifier<Self, M>.Path
    ) -> ChildrenModifier<Self, M> {
        ChildrenModifier(self, path: path)
    }
}