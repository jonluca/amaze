import CoreHaptics

enum MazeHapticPatterns {
    static let rollingDuration: TimeInterval = 0.24
    static let completionDuration: TimeInterval = 0.30

    static func rolling() throws -> CHHapticPattern {
        let vibration = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
            ],
            relativeTime: 0,
            duration: rollingDuration
        )
        return try CHHapticPattern(events: [vibration], parameters: [])
    }

    static func completion() throws -> CHHapticPattern {
        let pulses = (0..<4).map { index in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.30 + Float(index) * 0.17),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25 + Float(index) * 0.16)
                ],
                relativeTime: Double(index) * completionDuration / 3
            )
        }
        return try CHHapticPattern(events: pulses, parameters: [])
    }
}
