import CoreHaptics

enum MazeHapticPatterns {
    static let rollingDuration: TimeInterval = 0.24
    static let completionDuration: TimeInterval = 0.30

    static func rolling() throws -> CHHapticPattern {
        let vibration = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.28),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.22)
            ],
            relativeTime: 0,
            duration: rollingDuration
        )
        // A seamless texture, rather than a series of heavy collision impacts.
        let texture = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: stride(from: 0, through: 8, by: 1).map { index in
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: Double(index) * rollingDuration / 8,
                    value: index.isMultiple(of: 2) ? 0.68 : 1
                )
            },
            relativeTime: 0
        )
        return try CHHapticPattern(events: [vibration], parameterCurves: [texture])
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
