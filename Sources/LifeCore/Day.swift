import Foundation

public enum Day {
  public static func key(_ date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
  public static func date(_ key: String, calendar: Calendar = .current) -> Date? {
    let p = key.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3,
      let d = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])),
      self.key(d, calendar: calendar) == key
    else { return nil }
    return d
  }
  public static func adding(_ count: Int, to key: String, calendar: Calendar = .current) -> String {
    guard let d = date(key, calendar: calendar),
      let next = calendar.date(byAdding: .day, value: count, to: d)
    else { return key }
    return self.key(next, calendar: calendar)
  }
}
