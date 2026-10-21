import Foundation

/// The `xeorental://` QR contract shared with the e-ink demo (docs/tech/01 §2).
public enum QRRoute: Equatable, Sendable {
    case rent(cabinet: String?)
    case activate(device: String?)
    case renew(device: String?)

    public static let scheme = "xeorental"

    public static func parse(_ url: URL) -> QRRoute? {
        guard url.scheme?.lowercased() == scheme,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // `xeorental://rent?…` puts "rent" in the host; tolerate `xeorental:rent` / `xeorental:///rent` too.
        let host = (comps.host?.isEmpty == false ? comps.host! : comps.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        func q(_ name: String) -> String? {
            comps.queryItems?.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        switch host {
        case "rent": return .rent(cabinet: q("cabinet"))
        case "activate": return .activate(device: q("device"))
        case "renew": return .renew(device: q("device"))
        default: return nil
        }
    }

    public static func parse(_ text: String) -> QRRoute? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return parse(url)
    }

    public var url: URL {
        switch self {
        case let .rent(c): return Self.make("rent", "cabinet", c)
        case let .activate(d): return Self.make("activate", "device", d)
        case let .renew(d): return Self.make("renew", "device", d)
        }
    }

    private static func make(_ host: String, _ key: String, _ value: String?) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        if let value { c.queryItems = [URLQueryItem(name: key, value: value)] }
        return c.url!
    }
}
