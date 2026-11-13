import ProjectDescription

let project = Project(
    name: "TransPeek",
    settings: .settings(
        base: [
            "INFOPLIST_KEY_LSUIElement": "YES",
            "INFOPLIST_KEY_NSAccessibilityUsageDescription":
                "TransPeek needs accessibility access to read selected text.",
            "INFOPLIST_KEY_NSScreenCaptureUsageDescription":
                "TransPeek needs screen capture for OCR translation.",
            "SWIFT_STRICT_CONCURRENCY": "complete",
        ],
        configurations: [
            .debug(name: "Debug", xcconfig: "Configurations/Signing.xcconfig"),
            .release(name: "Release", xcconfig: "Configurations/Signing.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "TransPeek",
            destinations: .macOS,
            product: .app,
            bundleId: "com.tranmanhtuanlabs.transpeek",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDevelopmentRegion": "en",
                "CFBundleDisplayName": "TransPeek",
                "CFBundleName": "TransPeek",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "SUFeedURL": "https://github.com/TranManhTuanLabs/TransPeek/releases/latest/download/appcast.xml",
                "SUPublicEDKey": "$(SPARKLE_ED_PUBLIC_KEY)",
                // Opt out of Sparkle's "check for updates automatically?"
                // permission prompt on 2nd launch: automatic checks run
                // silently in the background instead, so the app never
                // shows a "no update available" alert on first launch
                // without the user asking. The user can still turn
                // automatic checks off in Settings → About.
                // NOTE: must be a Bool, not the string "YES" — a string
                // value made Sparkle's manual check show nothing at all
                // (no update prompt, no "up to date" alert) on 0.1.2/161.
                "SUEnableAutomaticChecks": true,
                "CFBundleURLTypes": [
                    [
                        "CFBundleURLName": "com.tranmanhtuanlabs.transpeek",
                        "CFBundleURLSchemes": ["transpeek"],
                    ],
                ],
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: .file(path: "Entitlements/TransPeek.entitlements"),
            dependencies: [
                .external(name: "KeyboardShortcuts"),
                .external(name: "Defaults"),
                .external(name: "Sparkle"),
                .external(name: "Textual"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "$(TRANSPEEK_CODE_SIGN_STYLE)",
                    "CODE_SIGN_IDENTITY": "$(TRANSPEEK_CODE_SIGN_IDENTITY)",
                    "DEVELOPMENT_TEAM": "$(TRANSPEEK_DEVELOPMENT_TEAM)",
                    "MARKETING_VERSION": "0.1.2",
                    "CURRENT_PROJECT_VERSION": "1",
                ],
                configurations: [
                    .debug(name: "Debug", xcconfig: "Configurations/Signing.xcconfig"),
                    .release(name: "Release", xcconfig: "Configurations/Signing.xcconfig"),
                ]
            )
        ),
        .target(
            name: "TransPeekTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.tranmanhtuanlabs.transpeekTests",
            deploymentTargets: .macOS("15.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "TransPeek"),
            ]
        ),
    ]
)
