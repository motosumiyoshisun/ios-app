import AnalyticsClient
import AnalyticsKeys
import BeMatch
import BeMatchClient
import CachedAsyncImage
import ComposableArchitecture
import Constants
import DirectMessageFeature
import FeedbackGeneratorClient
import ProfileSharedFeature
import ReportFeature
import Styleguide
import SwiftUI

@Reducer
public struct ProfileExternalLogic {
  public init() {}

  public struct State: Equatable {
    let match: BeMatch.MatchGrid
    @BindingState var selection: BeMatch.MatchGrid.TargetUser.Image
    @PresentationState var destination: Destination.State?

    var pictureSlider: PictureSliderLogic.State?

    var createdAt: Date {
      guard let timeInterval = TimeInterval(match.createdAt)
      else { return .now }
      return Date(timeIntervalSince1970: timeInterval / 1000.0)
    }

    public init(match: BeMatch.MatchGrid) {
      self.match = match
      selection = match.targetUser.images.first!
      pictureSlider = PictureSliderLogic.State(data: match.targetUser.fragments.pictureSlider)
    }
  }

  public enum Action {
    case onTask
    case onAppear
    case closeButtonTapped
    case unmatchButtonTapped
    case reportButtonTapped
    case addBeRealButtonTapped
    case jumpBeRealButtonTapped
    case deleteMatchResponse(Result<BeMatch.DeleteMatchMutation.Data, Error>)
    case readMatchResponse(Result<BeMatch.ReadMatchMutation.Data, Error>)
    case destination(PresentationAction<Destination.Action>)
    case pictureSlider(PictureSliderLogic.Action)
    case delegate(Delegate)

    public enum ConfirmationDialog: Equatable {
      case confirm
    }

    public enum Delegate: Equatable {
      case unmatch(String)
    }
  }

  @Dependency(\.openURL) var openURL
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.analytics) var analytics
  @Dependency(\.bematch.readMatch) var readMatch
  @Dependency(\.bematch.deleteMatch) var deleteMatch
  @Dependency(\.feedbackGenerator) var feedbackGenerator

  public var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .onTask:
        analytics.logScreen(screenName: "ProfileExternal", of: self)

        let matchId = state.match.id
        return .run { send in
          await readMatchRequest(matchId: matchId, send: send)
        }

      case .unmatchButtonTapped:
        state.destination = .confirmationDialog(
          ConfirmationDialogState {
            TextState("Unmatch", bundle: .module)
          } actions: {
            ButtonState(role: .destructive, action: .confirm) {
              TextState("Confirm", bundle: .module)
            }
          } message: {
            TextState("Are you sure you want to unmatch?", bundle: .module)
          }
        )
        return .none

      case .reportButtonTapped:
        state.destination = .report(ReportLogic.State(
          targetUserId: state.match.targetUser.id
        ))
        return .none

      case .closeButtonTapped:
        return .run { _ in
          await feedbackGenerator.impactOccurred()
          await dismiss()
        }

      case .addBeRealButtonTapped:
        let username = state.match.targetUser.berealUsername
        state.destination = .directMessage(
          DirectMessageLogic.State(username: username)
        )
        return .run { _ in
          await feedbackGenerator.impactOccurred()
        }

      case .jumpBeRealButtonTapped:
        let username = state.match.targetUser.berealUsername
        guard let url = URL(string: "https://bere.al/\(username)")
        else { return .none }

        analytics.buttonClick(name: \.addBeReal, parameters: [
          "url": url.absoluteString,
          "match_id": state.match.id,
        ])

        return .run { _ in
          await feedbackGenerator.impactOccurred()
          await openURL(url)
        }

      case .deleteMatchResponse:
        let matchId = state.match.id
        return .run { send in
          await send(.delegate(.unmatch(matchId)))
          await dismiss()
        }

      case .destination(.presented(.confirmationDialog(.confirm))):
        state.destination = nil
        let targetUserId = state.match.targetUser.id
        let input = BeMatch.DeleteMatchInput(targetUserId: targetUserId)

        return .run { send in
          await send(.deleteMatchResponse(Result {
            try await deleteMatch(input)
          }))
        }

      case .destination(.dismiss):
        state.destination = nil
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
    .ifLet(\.pictureSlider, action: \.pictureSlider) {
      PictureSliderLogic()
    }
  }

  func readMatchRequest(matchId: String, send: Send<Action>) async {
    await send(.readMatchResponse(Result {
      try await readMatch(matchId)
    }))
  }

  @Reducer
  public struct Destination {
    public enum State: Equatable {
      case report(ReportLogic.State)
      case directMessage(DirectMessageLogic.State)
      case confirmationDialog(ConfirmationDialogState<Action.ConfirmationDialog>)
    }

    public enum Action {
      case report(ReportLogic.Action)
      case directMessage(DirectMessageLogic.Action)
      case confirmationDialog(ConfirmationDialog)

      public enum ConfirmationDialog: Equatable {
        case confirm
      }
    }

    public var body: some Reducer<State, Action> {
      Scope(state: \.report, action: \.report, child: ReportLogic.init)
      Scope(state: \.directMessage, action: \.directMessage, child: DirectMessageLogic.init)
      Scope(state: \.confirmationDialog, action: \.confirmationDialog) {}
    }
  }
}

public struct ProfileExternalView: View {
  @Environment(\.displayScale) var displayScale
  @State var translation: CGSize = .zero
  @State var scaleEffect: Double = 1.0
  let store: StoreOf<ProfileExternalLogic>

  public init(store: StoreOf<ProfileExternalLogic>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack {
        VStack(spacing: 24) {
          HStack(spacing: 0) {
            Button {
              store.send(.closeButtonTapped)
            } label: {
              Image(systemName: "chevron.down")
                .bold()
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 0) {
              Text(viewStore.match.targetUser.berealUsername)
                .foregroundStyle(Color.white)
                .font(.system(.callout, weight: .semibold))

              Text(viewStore.createdAt, format: Date.FormatStyle(date: .numeric))
                .foregroundStyle(Color.gray)
                .font(.system(.caption2, weight: .semibold))
            }
            Spacer()
            Menu {
              Button(role: .destructive) {
                store.send(.unmatchButtonTapped)
              } label: {
                Label {
                  Text("Unmatch", bundle: .module)
                } icon: {
                  Image(systemName: "trash")
                }
              }

              Button {
                store.send(.reportButtonTapped)
              } label: {
                Label {
                  Text("Report", bundle: .module)
                } icon: {
                  Image(systemName: "exclamationmark.triangle")
                }
              }
            } label: {
              Image(systemName: "ellipsis")
                .bold()
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
            }
          }
          .padding(.top, 56)
          .padding(.horizontal, 16)

          IfLetStore(
            store.scope(state: \.pictureSlider, action: \.pictureSlider),
            then: PictureSliderView.init(store:),
            else: {
              Color.black
                .aspectRatio(3 / 4, contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width)
            }
          )

          VStack(spacing: 12) {
            PrimaryButton(
              String(localized: "Send Message", bundle: .module)
            ) {
              store.send(.addBeRealButtonTapped)
            }
            .padding(.horizontal, 16)

            Button {
              store.send(.jumpBeRealButtonTapped)
            } label: {
              Text("🔗 BeRe.al/\(viewStore.match.targetUser.berealUsername)")
                .font(.system(.caption))
                .foregroundStyle(Color.primary)
            }
          }

          Spacer()
        }
        .background(Color.black)
        .cornerRadius(40)
        .scaleEffect(scaleEffect)
        .ignoresSafeArea()
      }
      .background(Material.ultraThin)
      .presentationBackground(Color.clear)
      .task { await store.send(.onTask).finish() }
      .confirmationDialog(
        store: store.scope(
          state: \.$destination.confirmationDialog,
          action: \.destination.confirmationDialog
        )
      )
      .sheet(
        store: store.scope(state: \.$destination.report, action: \.destination.report)
      ) { store in
        ReportView(store: store)
          .presentationDragIndicator(.visible)
          .presentationDetents([.medium, .large])
      }
      .sheet(
        store: store.scope(state: \.$destination.directMessage, action: \.destination.directMessage)
      ) { store in
        NavigationStack {
          DirectMessageView(store: store)
        }
      }
      .gesture(
        DragGesture()
          .onEnded { _ in
            translation = .zero
            scaleEffect = 1.0
          }
          .onChanged {
            translation = $0.translation

            let startValue = 0.85
            let endValue = 1.0

            let clampedValue = min(max(translation.height, 0.0), 150.0)
            let normalizedValue = clampedValue / 100.0

            scaleEffect = startValue + (endValue - startValue) * (1.0 - normalizedValue)

            if translation.height > 150 {
              store.send(.closeButtonTapped)
            }
          }
      )
    }
  }
}

#Preview {
  Color.black
    .fullScreenCover(isPresented: .constant(true)) {
      ProfileExternalView(
        store: .init(
          initialState: ProfileExternalLogic.State(
            match: BeMatch.MatchGrid(
              _dataDict: DataDict(
                data: [
                  "id": "1",
                  "isRead": 0,
                  "createdAt": "1702462075770",
                  "targetUser": DataDict(
                    data: [
                      "id": "2",
                      "berealUsername": "tomomisun",
                      "images": [
                        DataDict(
                          data: [
                            "id": "3",
                            "imageUrl": "https://asia-northeast1-bematch-staging.cloudfunctions.net/onRequestResizedImage/users/profile_images/vJ2NQU467OgyW6czPxFvfWoUOFC2/0.png?size=1500x2000",
                          ],
                          fulfilledFragments: []
                        ),
                      ],
                    ],
                    fulfilledFragments: []
                  ),
                ],
                fulfilledFragments: []
              )
            )
          ),
          reducer: { ProfileExternalLogic() }
        )
      )
      .environment(\.colorScheme, .dark)
    }
}
