// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "app_info_helper",
  platforms: [.iOS("15.0")],
  products: [.library(name: "app-info-helper", targets: ["app_info_helper"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [.target(name: "app_info_helper", dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")])]
)
