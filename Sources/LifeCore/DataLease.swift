import Darwin
import Foundation

/// Lifetime lock prevents two application processes from overwriting the same library.
public final class DataLease {
  private var fd: Int32 = -1
  public init(directory: URL) throws {
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    fd = Darwin.open(directory.appendingPathComponent("library.lock").path, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { throw LifeError("无法访问数据目录") }
    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
      Darwin.close(fd)
      fd = -1
      throw LifeError("另一个应用进程正在使用这份数据，请先关闭其他实例")
    }
  }
  deinit {
    if fd >= 0 {
      _ = flock(fd, LOCK_UN)
      Darwin.close(fd)
    }
  }
}
