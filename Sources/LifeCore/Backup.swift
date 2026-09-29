import CryptoKit
import Foundation

public struct BackupEnvelope: Codable {
  public var format = 1
  public var created: Date
  public var checksum: String
  public var payload: Data
  public init(data: Data, created: Date) {
    self.created = created
    payload = data
    checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  public func library() throws -> Library {
    guard format == 1 else { throw LifeError("不支持的备份格式") }
    guard checksum == SHA256.hash(data: payload).map({ String(format: "%02x", $0) }).joined() else {
      throw LifeError("备份校验失败，文件可能已损坏")
    }
    return try LibraryStore.decode(payload)
  }
}
public final class BackupService {
  public let store: LibraryStore
  public init(store: LibraryStore) { self.store = store }
  public func directory(for library: Library) -> URL {
    library.backupPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
      ?? store.directory.appendingPathComponent("Backups", isDirectory: true)
  }
  @discardableResult public func create(
    _ library: Library, kind: String = "manual", now: Date = Date()
  ) throws -> URL {
    let folder = directory(for: library)
    let name =
      kind == "daily"
      ? "daily-\(Day.key(now)).lifebackup"
      : "\(kind)-\(Int(now.timeIntervalSince1970))-\(UUID().uuidString).lifebackup"
    let url = folder.appendingPathComponent(name)
    let envelope = BackupEnvelope(data: try LibraryStore.encode(library), created: now)
    try LibraryStore(directory: folder).atomicWrite(JSONEncoder().encode(envelope), to: url)
    return url
  }
  public func inspect(_ url: URL) throws -> BackupEnvelope {
    let b = try JSONDecoder().decode(BackupEnvelope.self, from: Data(contentsOf: url))
    _ = try b.library()
    return b
  }
  public func automatic(_ library: Library, now: Date = Date()) throws {
    guard library.autoBackup else { return }
    let dir = directory(for: library)
    let daily = dir.appendingPathComponent("daily-\(Day.key(now)).lifebackup")
    if !FileManager.default.fileExists(atPath: daily.path) {
      try create(library, kind: "daily", now: now)
    } else {
      _ = try inspect(daily)
    }
    let files = try FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("daily-") && $0.pathExtension == "lifebackup" }.sorted
    { $0.lastPathComponent > $1.lastPathComponent }
    for old in files.dropFirst(7) { try FileManager.default.removeItem(at: old) }
  }
  public func latest(_ library: Library) -> Date? {
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory(for: library), includingPropertiesForKeys: [.contentModificationDateKey])
    else { return nil }
    return files.filter { $0.pathExtension == "lifebackup" }.compactMap {
      try? inspect($0).created
    }.max()
  }
  public func restore(_ url: URL, current: Library) throws -> Library {
    let incoming = try inspect(url).library()
    // Preserve exact on-disk contents, including damaged originals, before replacing anything.
    if FileManager.default.fileExists(atPath: store.file.path) {
      let raw = try Data(contentsOf: store.file)
      let folder = directory(for: current)
      let safety = folder.appendingPathComponent("before-restore-\(UUID().uuidString).original")
      try LibraryStore(directory: folder).atomicWrite(raw, to: safety)
      if let valid = try? LibraryStore.decode(raw) {
        var safe = valid
        safe.backupPath = folder.path
        try create(safe, kind: "before-restore")
      }
    }
    try store.save(incoming)
    return incoming
  }
}
