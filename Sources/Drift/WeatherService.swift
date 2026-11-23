import Foundation
import CoreLocation

/// What the live forecast says right now, reduced to what the overlay needs.
struct LiveWeather {
    let scene: WeatherScene
    let symbol: String        // MET Norway symbol code, e.g. "lightsnow_day"
    let temperature: Double   // °C
    let wind: Double          // sideways drift for the particles, pt/s (negative = to the left)
    let place: String
}

/// Turns a city name into coordinates (Apple's geocoder) and fetches the forecast
/// from MET Norway's free Locationforecast API. Only rounded coordinates are sent.
final class WeatherService {
    enum WeatherError: LocalizedError {
        case cityNotFound, badResponse
        var errorDescription: String? {
            switch self {
            case .cityNotFound: return "Couldn't find that city."
            case .badResponse: return "The weather service didn't answer."
            }
        }
    }

    private var cachedCity: String?
    private var cachedCoordinate: CLLocationCoordinate2D?
    private var cachedPlace = ""

    func fetch(city: String) async throws -> LiveWeather {
        let (coordinate, place) = try await locate(city)
        // MET Norway asks for at most 4 decimals; 2 decimals (~1 km) is plenty and more private.
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100
        var request = URLRequest(url: URL(string:
            "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(lat)&lon=\(lon)")!)
        // MET Norway requires an identifying User-Agent. Add a contact URL or email before shipping.
        request.setValue("Drift/0.1 (personal prototype)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
        let forecast = try JSONDecoder().decode(Forecast.self, from: data)
        guard let now = forecast.properties.timeseries.first else { throw WeatherError.badResponse }

        let symbol = now.data.next_1_hours?.summary.symbol_code
            ?? now.data.next_6_hours?.summary.symbol_code ?? "clearsky_day"
        let details = now.data.instant.details
        // Wind "from" 270° (west) blows toward the east, i.e. particles drift right.
        let radians = (details.wind_from_direction ?? 0) * .pi / 180
        let drift = max(-45, min(45, -sin(radians) * (details.wind_speed ?? 0) * 5))

        return LiveWeather(scene: Self.scene(for: symbol), symbol: symbol,
                           temperature: details.air_temperature ?? 0, wind: drift, place: place)
    }

    /// MET symbol codes: https://api.met.no/weatherapi/weathericon/2.0/documentation
    static func scene(for symbol: String) -> WeatherScene {
        if symbol.contains("snow") || symbol.contains("sleet") { return .snow }
        if symbol.contains("rain") || symbol.contains("thunder") { return .rain }
        return .clear
    }

    private func locate(_ city: String) async throws -> (CLLocationCoordinate2D, String) {
        if city == cachedCity, let c = cachedCoordinate { return (c, cachedPlace) }
        let placemarks = try await CLGeocoder().geocodeAddressString(city)
        guard let mark = placemarks.first, let location = mark.location else { throw WeatherError.cityNotFound }
        cachedCity = city
        cachedCoordinate = location.coordinate
        cachedPlace = [mark.locality, mark.country].compactMap { $0 }.joined(separator: ", ")
        return (location.coordinate, cachedPlace)
    }
}

// MARK: - MET Norway response (only the fields we use)

private struct Forecast: Decodable {
    let properties: Properties
    struct Properties: Decodable { let timeseries: [Entry] }
    struct Entry: Decodable { let data: EntryData }
    struct EntryData: Decodable {
        let instant: Instant
        let next_1_hours: Period?
        let next_6_hours: Period?
    }
    struct Instant: Decodable { let details: Details }
    struct Details: Decodable {
        let air_temperature: Double?
        let wind_speed: Double?
        let wind_from_direction: Double?
    }
    struct Period: Decodable { let summary: Summary }
    struct Summary: Decodable { let symbol_code: String }
}
