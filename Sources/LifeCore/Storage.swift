import Darwin
import Foundation

public final class LibraryStore {
  public let directory: URL
  public var file: URL { directory.appendingPathComponent("library.json") }
  public var beforeReplace: (() throws -> Void)?
  public init(directory: URL) { self.directory = directory }
  public static func defaultDirectory() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("PersonalLife", isDirectory: true)
  }
  public static func encode(_ library: Library) throws -> Data {
    try library.validate()
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys, .prettyPrinted]
    return try e.encode(library)
  }
  public static func decode(_ data: Data) throws -> Library {
    let value = try JSONDecoder().decode(Library.self, from: data)
    try value.validate()
    return value
  }
  public func load() throws -> Library {
    guard FileManager.default.fileExists(atPath: file.path) else { return Library() }
    return try Self.decode(Data(contentsOf: file))
  }
  public func save(_ library: Library) throws { try atomicWrite(Self.encode(library), to: file) }
  public func atomicWrite(_ data: Data, to destination: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(
      at: destination.deletingLastPathComponent(), withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let tmp = destination.deletingLastPathComponent().appendingPathComponent(
      ".write-" + UUID().uuidString)
    defer { try? fm.removeItem(at: tmp) }
    let fd = Darwin.open(tmp.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer { Darwin.close(fd) }
    try data.withUnsafeBytes { buffer in
      var offset = 0
      while offset < buffer.count {
        let n = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
        if n < 0 && errno == EINTR { continue }
        guard n > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        offset += n
      }
    }
    guard fsync(fd) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    // On macOS request hardware flush, falling back to successful fsync on unsupported filesystems.
    if fcntl(fd, F_FULLFSYNC) != 0 && errno != ENOTSUP && errno != EINVAL {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    try beforeReplace?()
    guard rename(tmp.path, destination.path) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    let dirfd = Darwin.open(destination.deletingLastPathComponent().path, O_RDONLY)
    if dirfd >= 0 {
      _ = fsync(dirfd)
      Darwin.close(dirfd)
    }
  }
}
