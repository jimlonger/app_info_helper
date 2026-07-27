// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "app_info_utils",
  platforms: [.iOS("15.0")],
  products: [.library(name: "app-info-utils", targets: ["app_info_utils"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [
    .target(
      name: "app_info_utils",
      dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
      resources: [.process("PrivacyInfo.xcprivacy")]
    )
  ]
)
