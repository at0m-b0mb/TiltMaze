import WatchKit

/// Taptic feedback by intent. A wall bump is a light click (with a cooldown so
/// it never machine-guns); falling and winning are distinct.
enum Haptic {
    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    static func bump()   { play(.click) }
    static func fall()   { play(.failure) }
    static func win()    { play(.success) }
    static func star()   { play(.notification) }
    static func uiTap()  { play(.click) }
    static func locked() { play(.failure) }
}
