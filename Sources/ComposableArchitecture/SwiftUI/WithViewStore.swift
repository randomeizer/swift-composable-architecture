import Combine
import CustomDump
import SwiftUI

/// A view helper that transforms a ``Store`` into a ``ViewStore`` so that its state can be observed
/// by a view builder.
///
/// This helper is an alternative to observing the view store manually on your view, which requires
/// the boilerplate of a custom initializer.
///
/// For example, the following view, which manually observes the store it is handed by constructing
/// a view store in its initializer:
///
/// ```swift
/// struct ProfileView: View {
///   let store: Store<ProfileState, ProfileAction>
///   @ObservedObject var viewStore: ViewStore<ProfileState, ProfileAction>
///
///   init(store: Store<ProfileState, ProfileAction>) {
///     self.store = store
///     self.viewStore = ViewStore(store)
///   }
///
///   var body: some View {
///     Text("\(self.viewStore.username)")
///     // ...
///   }
/// }
/// ```
///
/// Can be written more simply using `WithViewStore`:
///
/// ```swift
/// struct ProfileView: View {
///   let store: Store<ProfileState, ProfileAction>
///
///   var body: some View {
///     WithViewStore(self.store) { viewStore in
///       Text("\(viewStore.username)")
///       // ...
///     }
///   }
/// }
/// ```
///
/// > Note: `WithViewStore` expressions are more complex than views that observe view stores using
/// > `@ObservedObject`, and can lead to a degraded compiler performance. For large, complex view,
/// > consider manually observing the store using `@ObservedObject`, instead.
public struct WithViewStore<State, Action, Content: View>: View {
  private let content: (ViewStore<State, Action>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (State) -> State?
  #endif
  //@ObservedObject private var viewStore: ViewStore<State, Action>
  private let store: Store<State, Action>
  private let isDuplicate: (State, State) -> Bool

  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      var previousState: State? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
    #endif
    //self.viewStore = ViewStore(store, removeDuplicates: isDuplicate)
    self.store = store
    self.isDuplicate = isDuplicate
  }

  /// Prints debug information to the console whenever the view is computed.
  ///
  /// - Parameter prefix: A string with which to prefix all debug messages.
  /// - Returns: A structure that prints debug messages for all computations.
  public func debug(_ prefix: String = "") -> Self {
    var view = self
    #if DEBUG
      view.prefix = prefix
    #endif
    return view
  }

  public var body: some View {
//    #if DEBUG
//      if let prefix = self.prefix {
//        var stateDump = ""
//        customDump(self.viewStore.state, to: &stateDump, indent: 2)
//        let difference =
//          self.previousState(self.viewStore.state)
//          .map {
//            diff($0, self.viewStore.state).map { "(Changed state)\n\($0)" }
//              ?? "(No difference in state detected)"
//          }
//          ?? "(Initial state)\n\(stateDump)"
//        func typeName(_ type: Any.Type) -> String {
//          var name = String(reflecting: type)
//          if let index = name.firstIndex(of: ".") {
//            name.removeSubrange(...index)
//          }
//          return name
//        }
//        print(
//          """
//          \(prefix.isEmpty ? "" : "\(prefix): ")\
//          WithViewStore<\(typeName(State.self)), \(typeName(Action.self)), _>\
//          @\(self.file):\(self.line) \(difference)
//          """
//        )
//      }
//    #endif

    if #available(iOS 14, *) {
      StateObjectViewStore(
        viewStore: ViewStore(self.store, removeDuplicates: self.isDuplicate),
        content: self.content
      )
    } else {
      ObservedObjectViewStore(
        viewStore: ViewStore(self.store, removeDuplicates: self.isDuplicate),
        content: self.content
      )
    }

//    return self.content(ViewStore(self.viewStore))
  }
}

@available(iOS 14.0, *)
struct StateObjectViewStore<State, Action, Content: View>: View {
  @StateObject var viewStore: ViewStore<State, Action>
  let content: (ViewStore<State, Action>) -> Content

  init(
    viewStore: @escaping @autoclosure () -> ViewStore<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self._viewStore = .init(wrappedValue: viewStore())
    self.content = content
  }

  var body: some View {
    self.content(ViewStore(self.viewStore))
  }
}

struct ObservedObjectViewStore<State, Action, Content: View>: View {
  @ObservedObject var viewStore: ViewStore<State, Action>
  let content: (ViewStore<State, Action>) -> Content

  init(
    viewStore: ViewStore<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.viewStore = viewStore
    self.content = content
  }

  var body: some View {
    self.content(ViewStore(self.viewStore))
  }
}


// MARK: - View
//extension WithViewStore: View where Content: View {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute views from store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store.
//  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
//  ///     equal, repeat view computations are removed,
//  ///   - content: A function that can generate content from a view store.
//  public init(
//    _ store: Store<State, Action>,
//    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(
//      store: store,
//      removeDuplicates: isDuplicate,
//      file: file,
//      line: line,
//      content: content
//    )
//  }
//}

extension WithViewStore where State: Equatable {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore where State == Void {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from void store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    file: StaticString = #fileID,
    line: UInt = #line,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
  }
}

extension WithViewStore: DynamicViewContent where State: Collection, Content: DynamicViewContent {
  public typealias Data = State

  public var data: State {
    self.store.state.value
  }
}
//
//// MARK: - AccessibilityRotorContent
//@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
//extension WithViewStore: AccessibilityRotorContent where Content: AccessibilityRotorContent {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute accessibility rotor content from store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store.
//  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
//  ///     equal, repeat view computations are removed,
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(
//      store: store,
//      removeDuplicates: isDuplicate,
//      file: file,
//      line: line,
//      content: content
//    )
//  }
//}
//
//@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
//extension WithViewStore where State: Equatable, Content: AccessibilityRotorContent {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute accessibility rotor content from equatable store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
//extension WithViewStore where State == Void, Content: AccessibilityRotorContent {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute accessibility rotor content from void store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from an accessibility rotor content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @AccessibilityRotorContentBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//// MARK: - Commands
//
//@available(iOS 14, macOS 11, *)
//@available(tvOS, unavailable)
//@available(watchOS, unavailable)
//extension WithViewStore: Commands where Content: Commands {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute commands from store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store.
//  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
//  ///     equal, repeat view computations are removed,
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(
//      store: store,
//      removeDuplicates: isDuplicate,
//      file: file,
//      line: line,
//      content: content
//    )
//  }
//}
//
//@available(iOS 14, macOS 11, *)
//@available(tvOS, unavailable)
//@available(watchOS, unavailable)
//extension WithViewStore where State: Equatable, Content: Commands {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute commands from equatable store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//@available(iOS 14, macOS 11, *)
//@available(tvOS, unavailable)
//@available(watchOS, unavailable)
//extension WithViewStore where State == Void, Content: Commands {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute commands from void store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a command builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @CommandsBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//// MARK: - Scene
//@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
//extension WithViewStore: Scene where Content: Scene {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute scenes from store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store.
//  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
//  ///     equal, repeat view computations are removed,
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(
//      store: store,
//      removeDuplicates: isDuplicate,
//      file: file,
//      line: line,
//      content: content
//    )
//  }
//}
//
//@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
//extension WithViewStore where State: Equatable, Content: Scene {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute scenes from equatable store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
//extension WithViewStore where State == Void, Content: Scene {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute scenes from void store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a scene builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @SceneBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//// MARK: - ToolbarContent
//
//@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
//extension WithViewStore: ToolbarContent where Content: ToolbarContent {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute toolbar content from store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store.
//  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
//  ///     equal, repeat view computations are removed,
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(
//      store: store,
//      removeDuplicates: isDuplicate,
//      file: file,
//      line: line,
//      content: content
//    )
//  }
//}
//
//@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
//extension WithViewStore where State: Equatable, Content: ToolbarContent {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute toolbar content from equatable store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
//
//@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
//extension WithViewStore where State == Void, Content: ToolbarContent {
//  /// Initializes a structure that transforms a store into an observable view store in order to
//  /// compute toolbar content from void store state.
//  ///
//  /// - Parameters:
//  ///   - store: A store of equatable state.
//  ///   - content: A function that can generate content from a view store.
//  @available(
//    *,
//    deprecated,
//    message:
//      """
//      For compiler performance, using "WithViewStore" from a toolbar content builder is no longer supported. Extract this "WithViewStore" to the parent view, instead, or observe your view store from an "@ObservedObject" property.
//      """
//  )
//  public init(
//    _ store: Store<State, Action>,
//    file: StaticString = #fileID,
//    line: UInt = #line,
//    @ToolbarContentBuilder content: @escaping (ViewStore<State, Action>) -> Content
//  ) {
//    self.init(store, removeDuplicates: ==, file: file, line: line, content: content)
//  }
//}
