# 技术设计

目标：Apple Silicon Mac，macOS 14+；本机验证环境 macOS 15.6、Xcode 26.3 / Swift 6.2.4。

- 使用 SwiftUI + AppKit 原生窗口，Swift Package Manager 构建；不引入远程依赖、浏览器运行时、服务器或云服务。
- 生命周期由 AppKit 管理，关闭窗口保留进程，程序坞重开同一窗口；退出前阻止丢弃失败的保存。
- 业务逻辑放入 LifeCore，页面位于 LifeApp，通过统一模型更新。
- 单一版本化 JSON 数据文件位于 Application Support/PersonalLife/library.json。写入先校验，再在同目录写临时文件并同步到磁盘，以原子 rename 替换；文件及目录权限仅当前用户可写。
- 每个对象使用稳定 ID，日期字符串为本地日历日期，提醒为绝对时间。训练安排生成独立日期实例和计划快照，实例唯一键为安排 ID + 日期。
- 所有成功操作自动写入。编辑失败保留内存状态但禁止显示已保存；载入损坏文件后锁住普通写入，只允许显式恢复。
- 备份包含版本、时间、校验和及完整数据。每日首次成功写入后自动备份，保留最近 7 份每日备份；手动和恢复前备份保留。恢复先校验，再保存当前磁盘副本，最后原子替换。
- 通知使用 UserNotifications，本地定时请求交给 macOS。Apple 文档说明系统可在应用不运行时交付已登记通知；本机退出、休眠和重启表现仍须实测，不以文档代替验收。
- 不默认添加登录项；每次启动及本地日期变化刷新训练实例和通知。提醒容量、覆盖区间和未登记数量必须反馈，不能静默丢失。
- 本地构建使用 ad-hoc 签名，仅面向本机运行；不声称已公证或可无警告分发到其他设备。

参考：
- https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app
- https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html

## 实施验证记录

P1：原生应用打包、日期逻辑测试及系统通知实验进行中。尚未完成真实重启验收。

构建环境修复：系统默认 Command Line Tools 的 ManifestAPI 接口与 dylib 不一致。使用现有完整 Xcode，通过命令级 DEVELOPER_DIR 指定，不修改全局 xcode-select。基础日期测试 2 项通过，应用打包和签名验证通过。
