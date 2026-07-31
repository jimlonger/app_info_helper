// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "x_app_utils",
  platforms: [.iOS("15.0")],
  products: [.library(name: "x-app-utils", targets: ["x_app_utils"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [
    .target(
      name: "x_app_utils",
      dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
      resources: [.process("PrivacyInfo.xcprivacy")]
    )
  ]
)
