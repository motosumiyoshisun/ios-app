import ComposableArchitecture
import SwiftUI

@Reducer
public struct UnsentDirectMessageListLogic {
  public init() {}

  public struct State: Equatable {
    var child: Child.State?
    public init() {}
  }

  public enum Action {
    case onTask
    case delayCompleted
    case child(Child.Action)
  }

  @Dependency(\.mainQueue) var mainQueue

  public var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .onTask:
        return .run { send in
          try await mainQueue.sleep(for: .seconds(4))
          await send(.delayCompleted)
        }

      case .delayCompleted:
        state.child = .content(UnsentDirectMessageListContentLogic.State())
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.child, action: \.child) {
      Child()
    }
  }

  @Reducer
  public struct Child {
    public enum State: Equatable {
      case content(UnsentDirectMessageListContentLogic.State)
    }

    public enum Action {
      case content(UnsentDirectMessageListContentLogic.Action)
    }

    public var body: some Reducer<State, Action> {
      Scope(state: \.content, action: \.content, child: UnsentDirectMessageListContentLogic.init)
    }
  }
}

public struct UnsentDirectMessageListView: View {
  let store: StoreOf<UnsentDirectMessageListLogic>

  public init(store: StoreOf<UnsentDirectMessageListLogic>) {
    self.store = store
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("RECENT MATCH", bundle: .module)
        .font(.system(.callout, weight: .semibold))
        .padding(.horizontal, 16)

      IfLetStore(store.scope(state: \.child, action: \.child)) { store in
        SwitchStore(store) { initialState in
          switch initialState {
          case .content:
            CaseLet(
              /UnsentDirectMessageListLogic.Child.State.content,
              action: UnsentDirectMessageListLogic.Child.Action.content,
              then: UnsentDirectMessageListContentView.init(store:)
            )
          }
        }
      } else: {
        VStack(spacing: 0) {
          ProgressView()
            .tint(Color.white)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 150)
      }
    }
    .task { await store.send(.onTask).finish() }
  }
}

#Preview {
  NavigationStack {
    UnsentDirectMessageListView(
      store: .init(
        initialState: UnsentDirectMessageListLogic.State(),
        reducer: { UnsentDirectMessageListLogic() }
      )
    )
  }
  .environment(\.colorScheme, .dark)
}
