import Foundation

func formatDuration(_ seconds: TimeInterval) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return "\(mins):\(String(format: "%02d", secs))"
}

func formatDurationLong(_ seconds: TimeInterval) -> String {
    let hrs = Int(seconds) / 3600
    let mins = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    if hrs > 0 {
        return "\(hrs):\(String(format: "%02d", mins)):\(String(format: "%02d", secs))"
    }
    return "\(mins):\(String(format: "%02d", secs))"
}
