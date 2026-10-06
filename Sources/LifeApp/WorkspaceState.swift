import AppKit
import Foundation
import LifeCore

/// UI preferences are deliberately separate from library.json and its backup format.
struct WorkspaceState: Codable {
  var version = 1
  var page = "首页总览"
  var noteID: UUID?
  var projectID: UUID?
  var sidebarVisible = true
  var sidebarWidth = 200.0
  var selectedDay: String?
  var followsToday = true
  var windowFrame: String?

  func validated(in library: Library) -> WorkspaceState {
    var copy = self
    if version != 1 { return WorkspaceState() }
    if !pages.dropLast().contains(page) { copy.page = "首页总览" }
    if !library.notes.contains(where: { $0.id == noteID }) { copy.noteID = nil }
    if !library.projects.contains(where: { $0.id == projectID }) { copy.projectID = nil }
    copy.sidebarWidth = sidebarWidth.isFinite ? min(260, max(180, sidebarWidth)) : 200
    if let day = selectedDay, Day.date(day) == nil {
      copy.selectedDay = nil
      copy.followsToday = true
    }
    return copy
  }
  static func fittedFrame(_ saved: NSRect, screens: [NSRect]) -> NSRect? {
    guard saved.origin.x.isFinite, saved.origin.y.isFinite,
      saved.width.isFinite, saved.height.isFinite, saved.width > 0, saved.height > 0,
      let first = screens.first
    else { return nil }
    let screen =
      screens.max { a, b in
        let x = a.intersection(saved)
        let y = b.intersection(saved)
        return (x.isNull ? 0 : x.width * x.height) < (y.isNull ? 0 : y.width * y.height)
      } ?? first
    let width = min(screen.width, max(880, saved.width))
    let height = min(screen.height, max(648, saved.height))
    return NSRect(
      x: min(max(saved.minX, screen.minX), screen.maxX - width),
      y: min(max(saved.minY, screen.minY), screen.maxY - height), width: width, height: height)
  }
}
