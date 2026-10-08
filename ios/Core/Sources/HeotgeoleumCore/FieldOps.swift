import Foundation

/// 오늘 갈 곳 — 눈 가리고 (docs/field_protocol.md, 웹 app.js #plan-btn 과 같은 규칙):
/// 내 위치에서 가까운 경보 대여소 3곳 + 그 근처(1.5km 안) 경보 없는 대여소 2곳을 섞어 이름만 보여 준다.
/// 어느 곳이 경보인지 숨겨야 '고장일 거야' 하는 선입견 없이 그곳 자전거를 모두 본다.
public enum SurveyPlan {
    public static let alarmCount = 3, controlCount = 2, nearMeters = 1500.0
    /// 이 시간 안에 고른 목록은 폰에 남겨 다시 보여 준다 (웹 localStorage survey_plan 과 같음)
    public static let keepHours = 12.0

    public static func pick<R: RandomNumberGenerator>(alarm: [String], stations: [String: Station], from here: GeoPoint?, using rng: inout R) -> [String] {
        let located = alarm.filter { stations[$0] != nil }
        guard let first = located.first, let origin = here ?? stations[first]?.point else { return [] }
        let a = located.map { ($0, Geo.meters(origin, stations[$0]!.point)) }.sorted { $0.1 < $1.1 }.prefix(alarmCount).map(\.0)
        let isAlarm = Set(located)
        let near = stations.values.filter { s in !isAlarm.contains(s.id) && a.contains { Geo.meters(s.point, stations[$0]!.point) < nearMeters } }
            .sorted { $0.id < $1.id }   // 사전 순서가 매번 달라 같은 난수에도 결과가 흔들리지 않게
        return (a + near.shuffled(using: &rng).prefix(controlCount).map(\.id)).shuffled(using: &rng)
    }
    public static func pick(alarm: [String], stations: [String: Station], from here: GeoPoint?) -> [String] {
        var g = SystemRandomNumberGenerator()
        return pick(alarm: alarm, stations: stations, from: here, using: &g)
    }
}

/// 운영 성적표 — 경보가 울린 날마다 결과가 정해진 실시간 경보 수와 그중 다음 다른 사람도 바로 반납한 수 (public.ops_alarm_days)
public struct AlarmDay: Codable, Hashable, Sendable {
    public let day: String
    public let scored: Int
    public let hit: Int
    public init(day: String, scored: Int, hit: Int) { self.day = day; self.scored = scored; self.hit = hit }
    public var percent: Double { scored > 0 ? 100 * Double(hit) / Double(scored) : 0 }
    /// "2026-10-07" → "10/7"
    public var short: String {
        let p = day.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? "\(p[1])/\(p[2])" : day
    }

    /// 평소 자전거가 다음 사람도 바로 반납하는 비율 (서울 3개월, docs/results.md 연쇄0)
    public static let usual = 2.5
    /// 그릴 날 — 결과가 100건 넘게 정해진 날만 (몇 건으로 낸 % 는 오해를 부른다). 3일 미만이면 안 그림
    public static func shown(_ days: [AlarmDay]) -> [AlarmDay] {
        let d = days.filter { $0.scored >= 100 }.sorted { $0.day < $1.day }
        return d.count >= 3 ? d : []
    }
    /// "11일 하루도 빠짐없이 평소의 9배 이상 (24~39%)"
    public static func headline(_ d: [AlarmDay]) -> String? {
        guard let lo = d.map(\.percent).min(), let hi = d.map(\.percent).max() else { return nil }
        return "\(d.count)일 하루도 빠짐없이 평소의 \(Int((lo / usual).rounded(.down)))배 이상 (\(Int(lo.rounded()))~\(Int(hi.rounded()))%)"
    }
}

extension SupabaseClient {
    public func alarmDays() async throws -> [AlarmDay] {
        try JSONDecoder().decode([AlarmDay].self, from: try await call("rest/v1/ops_alarm_days", query: "select=day,scored,hit&order=day"))
    }
}

/// 내 대여소 — 자주 가는 대여소(5곳까지, 이 폰에만)와 지금 그곳에 서 있는 의심 자전거 (웹 app.js renderMine 과 같은 규칙)
public enum MyStations {
    public static let limit = 5
    /// 넣기 — 이미 있으면 그대로, 다섯 곳이 넘으면 가장 먼저 넣은 곳을 뺌
    public static func add(_ id: String, to list: [String]) -> [String] {
        guard !list.contains(id) else { return list }
        return Array((list + [id]).suffix(limit))
    }
    /// 그 대여소의 의심 자전거 — 모델 확률(없으면 연쇄) 높은 순
    public static func suspects(at id: String, in bikes: [SuspectBike]) -> [SuspectBike] {
        bikes.filter { $0.station == id }.sorted { ($0.pNext ?? $0.chain) > ($1.pNext ?? $1.chain) }
    }
    /// 이름으로 찾기 — 빈칸은 무시, 이미 넣은 곳은 빼고, 이름순 몇 곳
    public static func search(_ q: String, stations: [String: Station], excluding: [String], limit: Int = 6) -> [Station] {
        let key = q.filter { !$0.isWhitespace }
        guard !key.isEmpty else { return [] }
        return stations.values.filter { !excluding.contains($0.id) && $0.name.filter { !$0.isWhitespace }.contains(key) }
            .sorted { $0.name.compare($1.name, locale: Locale(identifier: "ko_KR")) == .orderedAscending }.prefix(limit).map { $0 }
    }
}
