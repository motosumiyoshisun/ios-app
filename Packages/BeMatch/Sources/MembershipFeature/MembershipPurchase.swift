import AnalyticsClient
import ComposableArchitecture
import Styleguide
import SwiftUI

@Reducer
public struct MembershipPurchaseLogic {
  public init() {}

  public struct State: Equatable {
    public init() {}
  }

  public enum Action {
    case onTask
  }

  @Dependency(\.analytics) var analytics

  public var body: some Reducer<State, Action> {
    Reduce<State, Action> { _, action in
      switch action {
      case .onTask:
        return .none
      }
    }
  }
}

public struct MembershipPurchaseView: View {
  let store: StoreOf<MembershipPurchaseLogic>

  public init(store: StoreOf<MembershipPurchaseLogic>) {
    self.store = store
  }

  var gradient: LinearGradient {
    LinearGradient(
      colors: [
        Color(0xFFE8_B423),
        Color(0xFFF5_D068),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { _ in
      VStack(spacing: 16) {
        ScrollView {
          VStack(spacing: 24) {
            Image(ImageResource.purchaseHeader)
              .resizable()

            VStack(spacing: 40) {
              Text("続ける - ¥500円/週")
                .font(.system(.subheadline, weight: .semibold))
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.black)
                .background(gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))

              VStack(spacing: 60) {
                Image(ImageResource.membershipBenefit)
                  .resizable()

                PurchaseAboutView()
              }
            }
          }
          .padding(.top, 96)
          .padding(.bottom, 48)
          .padding(.horizontal, 16)
        }

        Text("続ける - ¥500円/週")
          .font(.system(.subheadline, weight: .semibold))
          .frame(height: 50)
          .frame(maxWidth: .infinity)
          .foregroundStyle(Color.black)
          .background(gradient)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .padding(.horizontal, 16)
          .padding(.bottom, 36)
      }
      .background()
      .task { await store.send(.onTask).finish() }
    }
  }
}

#Preview {
  NavigationStack {
    MembershipPurchaseView(
      store: .init(
        initialState: MembershipPurchaseLogic.State(),
        reducer: { MembershipPurchaseLogic() }
      )
    )
  }
  .environment(\.colorScheme, .dark)
  .environment(\.locale, Locale(identifier: "ja-JP"))
}