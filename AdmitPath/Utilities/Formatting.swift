import Foundation

enum FormatterFactory {
    static let usdCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let bdtCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BDT"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let monthDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func makePlainDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func makeISO8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            if let date = parseDate(rawValue) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(rawValue)"
            )
        }
        return decoder
    }

    static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(makeISO8601Formatter().string(from: date))
        }
        return encoder
    }

    static func parseDate(_ rawValue: String) -> Date? {
        if let date = makeISO8601Formatter().date(from: rawValue) {
            return date
        }
        return makePlainDateFormatter().date(from: rawValue)
    }
}

func formatCurrency(_ value: Int) -> String {
    FormatterFactory.usdCurrency.string(from: NSNumber(value: value)) ?? "$\(value)"
}

func formatBDT(_ value: Int) -> String {
    FormatterFactory.bdtCurrency.string(from: NSNumber(value: value)) ?? "BDT \(value)"
}

func formatDate(_ date: Date) -> String {
    FormatterFactory.monthDayYear.string(from: date)
}

func formatDecimal(_ value: Double, digits: Int = 1) -> String {
    String(format: "%.\(digits)f", value)
}

func relativeDaysString(from reference: Date = .now, to date: Date) -> String {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: reference)
    let end = calendar.startOfDay(for: date)
    let delta = calendar.dateComponents([.day], from: start, to: end).day ?? 0
    switch delta {
    case ..<0:
        return "\(abs(delta))d overdue"
    case 0:
        return "Due today"
    case 1:
        return "1 day left"
    default:
        return "\(delta) days left"
    }
}

extension Collection {
    var isNotEmpty: Bool { !isEmpty }
}
