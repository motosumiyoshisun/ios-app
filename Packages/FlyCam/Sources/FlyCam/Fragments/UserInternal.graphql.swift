// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension FlyCam {
  struct UserInternal: FlyCam.SelectionSet, Fragment {
    public static var fragmentDefinition: StaticString {
      #"fragment UserInternal on User { __typename id displayName }"#
    }

    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: ApolloAPI.ParentType { FlyCam.Objects.User }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("__typename", String.self),
      .field("id", FlyCam.ID.self),
      .field("displayName", String.self),
    ] }

    public var id: FlyCam.ID { __data["id"] }
    public var displayName: String { __data["displayName"] }
  }
}
