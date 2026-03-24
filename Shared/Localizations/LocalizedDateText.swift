//
//  LocalizedDateText.swift
//  GluVibProbe
//

import Foundation

enum LocalizedDateText {

    static func shortMonth(from raw: String, locale: Locale = .autoupdatingCurrent) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let monthIndex: Int? = {
            switch normalized {
            case "jan", "jän":
                return 1
            case "feb":
                return 2
            case "mar", "mär":
                return 3
            case "apr":
                return 4
            case "may", "mai":
                return 5
            case "jun":
                return 6
            case "jul":
                return 7
            case "aug":
                return 8
            case "sep", "sept":
                return 9
            case "oct", "okt":
                return 10
            case "nov":
                return 11
            case "dec", "dez":
                return 12
            default:
                return nil
            }
        }()

        guard let monthIndex else { return raw }

        var components = DateComponents()
        components.year = 2000
        components.month = monthIndex
        components.day = 1

        guard let date = Calendar.current.date(from: components) else { return raw }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        return formatter.string(from: date).capitalized
    }
}
