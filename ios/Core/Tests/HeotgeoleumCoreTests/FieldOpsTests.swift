import XCTest
@testable import HeotgeoleumCore

/// 눈 가린 조사 목록·운영 성적표 — 웹(app.js #plan-btn·dayBars)과 같은 규칙
final class FieldOpsTests: XCTestCase {
    struct Seeded: RandomNumberGenerator {   // 정해진 난수 (검사가 매번 같게)
        var s: UInt64
        mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s }
    }

    func testBlindPlanMixesNearestAlarmsWithNearbyControls() {
        // 경도 0.01° ≈ 880m (위도 37.5). 경보: a0(0)·a1(1)·a2(2)·a9(9, 멀어서 빠짐). 경보 없음: c1(0.5)·c2(1.5)·c9(20, 1.5km 밖)
        let p = { (id: String, k: Double) in Station(id: id, name: "대여소 \(id)", gu: "마포구", lat: 37.5, lon: 127 + 0.01 * k) }
        let st = Dictionary(uniqueKeysWithValues: [p("a0", 0), p("a1", 1), p("a2", 2), p("a9", 9), p("c1", 0.5), p("c2", 1.5), p("c9", 20)].map { ($0.id, $0) })
        var g = Seeded(s: 42)
        let plan = SurveyPlan.pick(alarm: ["a9", "a2", "a1", "a0", "없는곳"], stations: st, from: GeoPoint(lat: 37.5, lon: 126.999), using: &g)
        XCTAssertEqual(plan.count, 5)
        XCTAssertEqual(Set(plan.filter { $0.hasPrefix("a") }), ["a0", "a1", "a2"])   // 가까운 경보 3곳
        XCTAssertEqual(Set(plan.filter { $0.hasPrefix("c") }), ["c1", "c2"])          // 그 근처 경보 없는 곳 2곳 (c9 는 멀어서 빠짐)
        XCTAssertTrue(SurveyPlan.pick(alarm: [], stations: st, from: nil).isEmpty)
        let noHere = SurveyPlan.pick(alarm: ["a0"], stations: st, from: nil)           // 위치를 모르면 첫 경보 대여소 기준
        XCTAssertTrue(noHere.contains("a0") && noHere.count == 3)
    }

    func testAlarmDaysSummary() throws {
        let rows = try JSONDecoder().decode([AlarmDay].self, from: Data(#"[{"day":"2026-09-27","scored":285,"hit":86},{"day":"2026-10-04","scored":297,"hit":70},{"day":"2026-10-06","scored":306,"hit":119},{"day":"2026-10-08","scored":50,"hit":9}]"#.utf8))
        let d = AlarmDay.shown(rows)
        XCTAssertEqual(d.map(\.short), ["9/27", "10/4", "10/6"])   // 결과가 100건 안 되는 날(오늘)은 뺌
        XCTAssertEqual(AlarmDay.headline(d), "3일 하루도 빠짐없이 평소의 9배 이상 (24~39%)")
        XCTAssertTrue(AlarmDay.shown(Array(rows.prefix(2))).isEmpty)   // 3일 미만이면 안 그림
    }
}
