import ProjectDescription

let project = Project(
    name: "MoePeek",
    settings: .settings(
        base: [
            "INFOPLIST_KEY_LSUIElement": "YES",
            "INFOPLIST_KEY_NSAccessibilityUsageDescription":
                "PeekTrans needs accessibility access to read selected text.",
            "INFOPLIST_KEY_NSScreenCaptureUsageDescription":
                "PeekTrans needs screen capture for OCR translation.",
            "SWIFT_STRICT_CONCURRENCY": "complete",
        ],
        configurations: [
            .debug(name: "Debug", xcconfig: "Configurations/Signing.xcconfig"),
            .release(name: "Release", xcconfig: "Configurations/Signing.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "MoePeek",
            destinations: .macOS,
            product: .app,
            bundleId: "com.tranmanhtuanlabs.peektrans",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDevelopmentRegion": "en",
                "CFBundleDisplayName": "PeekTrans",
                "CFBundleName": "PeekTrans",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "SUFeedURL": "https://github.com/TranManhTuanLabs/PeekTrans/releases/latest/download/appcast.xml",
                "SUPublicEDKey": "$(SPARKLE_ED_PUBLIC_KEY)",
                "CFBundleURLTypes": [
                    [
                        "CFBundleURLName": "com.tranmanhtuanlabs.peektrans",
                        "CFBundleURLSchemes": ["peektrans"],
                    ],
                ],
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: .file(path: "Entitlements/MoePeek.entitlements"),
            dependencies: [
                .external(name: "KeyboardShortcuts"),
                .external(name: "Defaults"),
                .external(name: "Sparkle"),
                .external(name: "Textual"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "$(MOEPEEK_CODE_SIGN_STYLE)",
                    "CODE_SIGN_IDENTITY": "$(MOEPEEK_CODE_SIGN_IDENTITY)",
                    "DEVELOPMENT_TEAM": "$(MOEPEEK_DEVELOPMENT_TEAM)",
                    "MARKETING_VERSION": "0.21.0",
                    "CURRENT_PROJECT_VERSION": "1",
                ],
                configurations: [
                    .debug(name: "Debug", xcconfig: "Configurations/Signing.xcconfig"),
                    .release(name: "Release", xcconfig: "Configurations/Signing.xcconfig"),
                ]
            )
        ),
        .target(
            name: "MoePeekTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.tranmanhtuanlabs.peektransTests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "MoePeek"),
            ]
        ),
    ]
)
