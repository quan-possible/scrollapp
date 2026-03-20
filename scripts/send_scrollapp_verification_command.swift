import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3 else {
    fputs("Usage: swift scripts/send_scrollapp_verification_command.swift <session-id> <command> <sequence> [key=value ...]\n", stderr)
    exit(64)
}

let sessionID = arguments[0]
let command = arguments[1]
guard let sequence = Int(arguments[2]) else {
    fputs("Sequence must be an integer.\n", stderr)
    exit(64)
}

var userInfo: [String: Any] = [
    "command": command,
    "sequence": sequence
]

for argument in arguments.dropFirst(3) {
    let components = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
    guard components.count == 2 else {
        continue
    }

    let key = String(components[0])
    let rawValue = String(components[1])
    if let intValue = Int(rawValue) {
        userInfo[key] = intValue
    } else if let doubleValue = Double(rawValue) {
        userInfo[key] = doubleValue
    } else {
        userInfo[key] = rawValue
    }
}

DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.fromis9.scrollapp.verification.command"),
    object: sessionID,
    userInfo: userInfo,
    deliverImmediately: true
)
