import Foundation

public enum BaggedURLParser {
    public static func normalizedWebURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let directURL = URL(string: trimmed), isSupportedWebURL(directURL) {
            return directURL
        }

        if !trimmed.contains("://"),
           !trimmed.contains(" "),
           trimmed.contains("."),
           let httpsURL = URL(string: "https://\(trimmed)"),
           isSupportedWebURL(httpsURL) {
            return httpsURL
        }

        return nil
    }

    public static func isSupportedWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        return url.host()?.isEmpty == false
    }
}
