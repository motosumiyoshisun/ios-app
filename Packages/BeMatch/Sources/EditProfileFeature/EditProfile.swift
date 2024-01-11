import AnalyticsKeys
import BeMatch
import ComposableArchitecture
import GenderSettingFeature
import UsernameSettingFeature
import SwiftUI

@Reducer
public struct EditProfileLogic {
  public init() {}

  public struct State: Equatable {
    @PresentationState var destination: Destination.State?
    var user: BeMatch.UserInternal?

    public init(user: BeMatch.UserInternal?) {
      self.user = user
    }
  }

  public enum Action {
    case onAppear
    case genderSettingButtonTapped
    case usernameSettingButtonTapped
    case destination(PresentationAction<Destination.Action>)
  }

  @Dependency(\.analytics) var analytics

  public var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .onAppear:
        analytics.logScreen(screenName: "EditProfile", of: self)
        return .none

      case .genderSettingButtonTapped:
        state.destination = .genderSetting(GenderSettingLogic.State(gender: state.user?.gender.value))
        return .none

      case .usernameSettingButtonTapped:
        state.destination = .usernameSetting(UsernameSettingLogic.State(username: state.user?.berealUsername ?? ""))
        return .none

      case .destination(.dismiss):
        state.destination = nil
        return .none

      case .destination(.presented(.genderSetting(.delegate(.nextScreen)))),
        .destination(.presented(.usernameSetting(.delegate(.nextScreen)))):
        state.destination = nil // TODO: fix for natural
        return .none

      case .destination:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }

  @Reducer
  public struct Destination {
    public enum State: Equatable {
      case genderSetting(GenderSettingLogic.State)
      case usernameSetting(UsernameSettingLogic.State)
    }

    public enum Action {
      case genderSetting(GenderSettingLogic.Action)
      case usernameSetting(UsernameSettingLogic.Action)
    }

    public var body: some Reducer<State, Action> {
      Scope(state: \.genderSetting, action: \.genderSetting) {
        GenderSettingLogic()
      }
      Scope(state: \.usernameSetting, action: \.usernameSetting) {
        UsernameSettingLogic()
      }
    }
  }
}

public struct EditProfileView: View {
  let store: StoreOf<EditProfileLogic>

  public init(store: StoreOf<EditProfileLogic>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      List {
        Section {
          Button {
            store.send(.usernameSettingButtonTapped)
          } label: {
            LabeledContent {
              Image(systemName: "chevron.right")
            } label: {
            Text("Username", bundle: .module)
              .foregroundStyle(Color.primary)
            }
          }

          Button {
            store.send(.genderSettingButtonTapped)
          } label: {
            LabeledContent {
              Image(systemName: "chevron.right")
            } label: {
              Text("Gender", bundle: .module)
                .foregroundStyle(Color.primary)
            }
          }
        } header: {
          Text("PROFILE", bundle: .module)
        }
      }
      .navigationDestination(
        store: store.scope(
          state: \.$destination,
          action: EditProfileLogic.Action.destination
        ),
        state: /EditProfileLogic.Destination.State.genderSetting,
        action: EditProfileLogic.Destination.Action.genderSetting
      ) { store in
        GenderSettingView(store: store)
      }
      .navigationDestination(
        store: store.scope(
          state: \.$destination,
          action: EditProfileLogic.Action.destination
        ),
        state: /EditProfileLogic.Destination.State.usernameSetting,
        action: EditProfileLogic.Destination.Action.usernameSetting
      ) { store in
        UsernameSettingView(store: store)
      }
      .navigationTitle(String(localized: "Edit Profile", bundle: .module))
      .multilineTextAlignment(.center)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { store.send(.onAppear) }
    }
  }
}
