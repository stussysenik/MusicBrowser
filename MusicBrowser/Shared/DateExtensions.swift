import Foundation

/// Extensions for Date to simplify common operations
extension Date {
    /// Returns the year component of the date
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}
