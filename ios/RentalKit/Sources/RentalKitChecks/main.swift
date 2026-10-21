import Foundation
import RentalKit

// Plain-assertion self checks (no XCTest needed): `swift run RentalKitChecks`.
var failures = 0
var passed = 0
func check(_ cond: @autoclosure () -> Bool, _ what: String, line: Int = #line) {
    if cond() { passed += 1 } else { failures += 1; print("✗ line \(line): \(what)") }
}
func section(_ name: String) { print("· \(name)") }

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
let fit = Fitting(mask: .m, headCircumferenceCm: 57, headMeasured: true, leftDiopter: 300, rightDiopter: 250, earphone: .rent)

section("pricing")
check(RentalPlan.allCases.map(\.days) == [1, 3, 7], "plans are 1/3/7 days")
check(RentalPlan.oneDay.price == 99 && RentalPlan.threeDays.price == 249 && RentalPlan.sevenDays.price == 449, "illustrative prices")
check(Pricing.isIllustrative && Pricing.label == "示意价", "prices labelled 示意价")

section("payment window")
var o = Order(id: "A", cabinet: DemoIDs.cabinet, fitting: fit, plan: .threeDays, now: t0)
check(o.phase(at: t0) == .pendingPayment(remaining: 600), "new order pending with 10 min")
check(o.phase(at: t0.addingTimeInterval(599)) == .pendingPayment(remaining: 1), "1 s left")
check(o.phase(at: t0.addingTimeInterval(600)) == .closed, "derived closed at deadline")
check(o.refresh(now: t0.addingTimeInterval(300)) == false && o.status == .pendingPayment, "refresh before deadline keeps pending")
var late = o
check((try? late.pay(now: t0.addingTimeInterval(601))) == nil && late.status == .closed, "pay after deadline fails and closes")
do { var x = o; try x.pay(now: t0.addingTimeInterval(601)) } catch let e as OrderError { check(e == .paymentExpired, "error is paymentExpired") } catch { check(false, "unexpected error") }

section("pay → renting / expiring / overdue")
try! o.pay(now: t0.addingTimeInterval(120))
let start = t0.addingTimeInterval(120)
check(o.status == .renting && o.amountPaid == 249, "paid 249, renting")
check(o.endsAt == start.addingTimeInterval(3 * 86_400), "ends after 3 days")
check(o.phase(at: start) == .renting(remaining: 3 * 86_400), "3-day rental starts as plain renting (threshold is 1 day)")
check(o.phase(at: start.addingTimeInterval(2 * 86_400)) == .expiringSoon(remaining: 86_400), "exactly 1 day left → expiringSoon")
check(o.phase(at: start.addingTimeInterval(2 * 86_400 - 1)) == .renting(remaining: 86_401), "just over 1 day left → still renting")
var seven = Order(id: "S", cabinet: "c", fitting: fit, plan: .sevenDays, now: t0)
try! seven.pay(now: t0)
check(seven.phase(at: t0.addingTimeInterval(86_400)) == .renting(remaining: 6 * 86_400), "7-day rental after 1 day is renting")
check(seven.phase(at: t0.addingTimeInterval(5 * 86_400)) == .renting(remaining: 2 * 86_400), "2 days left → not yet expiring")
check(seven.phase(at: t0.addingTimeInterval(6.5 * 86_400)) == .expiringSoon(remaining: 0.5 * 86_400), "12 h left → expiringSoon")
check(seven.phase(at: t0.addingTimeInterval(7 * 86_400 + 5 * 3600)) == .overdue(by: 5 * 3600), "5 h past end → overdue")
check((try? o.pay(now: start)) == nil, "cannot pay twice")

section("renew")
let endBefore = seven.endsAt!
try! seven.renew(.oneDay, now: t0.addingTimeInterval(7 * 86_400 + 3600))
check(seven.endsAt == endBefore.addingTimeInterval(86_400), "renew extends from the old end (covers overdue)")
check(seven.amountPaid == 449 + 99 && seven.renewals.count == 1, "renew charges and records")
check(seven.phase(at: t0.addingTimeInterval(7 * 86_400 + 3600)).title == "即将到期", "overdue → expiring after renewal")

section("activation")
try! seven.activate(device: DemoIDs.device, now: t0)
check(seven.deviceID == DemoIDs.device && seven.activatedAt != nil, "device bound")
let tl = seven.timeline.count
try! seven.activate(device: DemoIDs.device, now: t0)
check(seven.timeline.count == tl, "re-activation is idempotent")

section("return: courier")
var c = seven
try! c.scheduleReturn(.courier(address: "测试路 1 号", slot: ReturnCatalog.courierSlots[0]), now: t0)
check(c.status == .returning && c.phase(at: t0) == .returning(.scheduled), "courier scheduled")
check((try? c.renew(.oneDay, now: t0)) == nil, "cannot renew while returning")
var stages: [ReturnStage] = [c.returnStage!]
while c.nextReturnStageTitle != nil { try! c.advanceReturn(now: t0); stages.append(c.returnStage!) }
check(stages == [.scheduled, .inTransit, .verifying, .completed], "courier stages in order")
check(c.status == .completed && c.phase(at: t0) == .completed, "courier completes order")
check((try? c.advanceReturn(now: t0)) == nil, "no stage after completed")

section("return: cabinet")
var k = seven
try! k.scheduleReturn(.cabinet(cinemaID: "C01"), now: t0)
var ks: [ReturnStage] = [k.returnStage!]
while k.nextReturnStageTitle != nil { try! k.advanceReturn(now: t0); ks.append(k.returnStage!) }
check(ks == [.scheduled, .verifying, .completed], "cabinet skips inTransit")
check(ReturnStage.verifying.title(for: .cabinet(cinemaID: "C01")) == "已交还，待核验", "cabinet verifying label")
check(ReturnCatalog.cinemas.count == 3 && ReturnCatalog.cinemas.contains { !$0.isAvailable }, "3 cinemas, one full")

section("QR contract")
check(QRRoute.parse("xeorental://rent?cabinet=XEO-IMAX-DEMO-01") == .rent(cabinet: "XEO-IMAX-DEMO-01"), "rent")
check(QRRoute.parse("xeorental://activate?device=ROM-DEMO-0001") == .activate(device: "ROM-DEMO-0001"), "activate")
check(QRRoute.parse("xeorental://renew?device=ROM-DEMO-0001") == .renew(device: "ROM-DEMO-0001"), "renew")
check(QRRoute.parse("XEORENTAL://RENT") == .rent(cabinet: nil), "case-insensitive, params optional")
check(QRRoute.parse("xeorental://renew?device=") == .renew(device: nil), "empty param = missing")
check(QRRoute.parse("xeorental:///activate?device=X") == .activate(device: "X"), "path form tolerated")
check(QRRoute.parse("xeorental://pay?x=1") == nil, "unknown host rejected")
check(QRRoute.parse("https://xeo.cn/rent") == nil, "other scheme rejected")
check(QRRoute.parse("hello world") == nil, "garbage rejected")
for r in [QRRoute.rent(cabinet: "A B"), .activate(device: DemoIDs.device), .renew(device: nil)] {
    check(QRRoute.parse(r.url) == r, "round trip \(r.url)")
}

section("diopter input")
check(DiopterRule.validate("350") == .success(350), "350 ok")
check(DiopterRule.validate("0") == .success(0), "0 ok")
check(DiopterRule.validate(" 1200 ") == .success(1200), "max ok, trimmed")
check(DiopterRule.validate("1201") == .failure(.tooLarge), "too large")
check(DiopterRule.validate("-100") == .failure(.negative), "negative")
check(DiopterRule.validate("3.5") == .failure(.decimal), "decimal")
check(DiopterRule.validate("") == .failure(.empty), "empty")
check(DiopterRule.validate("12a") == .failure(.notNumber), "letters")
check(DiopterRule.validate("３５０") == .failure(.notNumber), "full-width digits rejected")
check(DiopterRule.sanitize("-3.50度") == "350", "sanitize keeps digits")
check(DiopterRule.sanitize("0350") == "350", "sanitize strips leading zeros")
check(DiopterRule.sanitize("123456") == "1234", "sanitize caps length")

section("head circumference")
check(HeadEstimator.circumferenceCm(faceWidthMeters: 0.145) == 58, "14.5 cm face → 58 cm head (model value)")
check(HeadEstimator.circumferenceCm(faceWidthMeters: 0.130) >= 51 && HeadEstimator.circumferenceCm(faceWidthMeters: 0.130) <= 54, "smaller face → smaller head")
check(HeadEstimator.circumferenceCm(faceWidthMeters: 0.5) == 66, "clamped to range")
var est = HeadEstimator()
for i in 0..<29 { est.add(faceWidthMeters: 0.145 + Double(i % 3 - 1) * 0.001) }
check(!est.isReady && est.estimateCm == nil, "not ready before 30 samples")
est.add(faceWidthMeters: 0.30) // outlier ignored
est.add(faceWidthMeters: 0.145)
check(est.isReady && est.estimateCm == 58, "median estimate after 30 samples")
check(MaskSize.recommended(forHeadCircumference: 54) == .s && MaskSize.recommended(forHeadCircumference: 57) == .m && MaskSize.recommended(forHeadCircumference: 60) == .l, "mask recommendation")

section("store + demo clock")
let file = FileManager.default.temporaryDirectory.appendingPathComponent("rentalkit-checks-\(UUID().uuidString).json")
var fake = t0
let clock = DemoClock(base: { fake })
let store = RentalStore(fileURL: file, clock: clock)
check(store.loginWithPhone("1381234", code: "123456") == .badPhone, "short phone rejected")
check(store.loginWithPhone("13812345678", code: "12a456") == .badCode, "bad code rejected")
check(store.handle(.rent(cabinet: nil)) == .startRent(cabinet: DemoIDs.cabinet, needsLogin: true), "rent before login needs login")
check(store.loginWithPhone("138 1234 5678", code: "000000") == nil && store.account?.display == "138****5678", "phone login masks number")
check(store.handle(.activate(device: nil)) == .activationNeedsOrder, "activate without rental")
check(store.handle(.renew(device: nil)) == .renewNeedsOrder, "renew without rental")
let placed = store.placeOrder(fitting: fit, plan: .sevenDays)
check(store.draft == nil && store.order(placed.id)?.status == .pendingPayment, "order placed")
check(store.demoJump(.pendingRemaining30s) && store.order(placed.id)!.phase(at: store.now) == .pendingPayment(remaining: 30), "jump: 30 s left to pay")
fake = fake.addingTimeInterval(31)
store.refreshAll()
check(store.order(placed.id)?.status == .closed, "timeout closes the unpaid order")
let second = store.placeOrder(fitting: fit, plan: .sevenDays)
try! store.pay(second.id)
check(store.handle(.activate(device: DemoIDs.device)) == .activated(orderID: second.id, device: DemoIDs.device), "activate binds to rental")
check(store.handle(.renew(device: DemoIDs.device)) == .openRenew(orderID: second.id), "renew opens the device's order")
check(store.demoJump(.expiringIn20Hours) && store.order(second.id)!.phase(at: store.now) == .expiringSoon(remaining: 20 * 3600), "jump: 20 hours left")
check(store.demoJump(.overdue5Hours) && store.order(second.id)!.phase(at: store.now) == .overdue(by: 5 * 3600), "jump: 5 h overdue")
let reloaded = RentalStore(fileURL: file, clock: DemoClock(base: { fake }))
check(reloaded.orders == store.orders && reloaded.account == store.account, "state persists across launches")
check(reloaded.order(second.id)!.phase(at: reloaded.now) == .overdue(by: 5 * 3600), "clock offset persists")
store.resetAll()
check(store.orders.isEmpty && store.account == nil && store.clock.offset == 0, "reset clears everything")
try? FileManager.default.removeItem(at: file)

section("duration text")
check(DurationText.format(599, clock: true) == "09:59", "mm:ss")
check(DurationText.format(2 * 86_400 + 3 * 3600) == "2 天 3 小时", "days")
check(DurationText.format(5 * 3600 + 12 * 60) == "5 小时 12 分", "hours")

print(failures == 0 ? "✓ all \(passed) checks passed" : "✗ \(failures) failed, \(passed) passed")
exit(failures == 0 ? 0 : 1)
