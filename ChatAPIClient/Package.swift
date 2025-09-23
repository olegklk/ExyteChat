// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ChatAPIClient",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],   
    dependencies: [                                                                                                                                                                                                            
    	.package(url: "https://github.com/exyte/ExyteChat.git", from: "1.0.0") // если версия отличается, измените accordingly                                                                                                 
	] 
)
