import XCTest

// Laboratório da faixa do relógio: cada variante (lab/v1..v5) é instalada na Tela de Início e aberta como app.
// O workflow abre a página da variante no Safari antes e passa LUME_VARIANTE (ex.: "v3-dark").
final class LabUITests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func foto(_ nome: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = nome
        a.lifetime = .keepAlways
        add(a)
    }

    func achar(_ app: XCUIApplication, _ rotulos: [String], espera: TimeInterval = 3) -> XCUIElement? {
        let fim = Date().addingTimeInterval(espera)
        let pred = NSPredicate(format: "label IN[c] %@ OR identifier IN[c] %@", rotulos, rotulos)
        repeat {
            let e = app.descendants(matching: .any).matching(pred).firstMatch
            if e.exists { return e }
            usleep(300_000)
        } while Date() < fim
        return nil
    }

    func testVariante() throws {
        continueAfterFailure = true
        guard let variante = ProcessInfo.processInfo.environment["LUME_VARIANTE"] else {
            throw XCTSkip("só roda no workflow do laboratório")
        }
        let nome = String(variante.split(separator: "-").first ?? "v").uppercased()
        safari.activate()
        sleep(4)
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { break }
        }
        foto("\(variante)_a_safari")
        if let mais = achar(safari, ["MoreMenuButton", "More"], espera: 4) { mais.tap(); sleep(2) }
        var add = achar(safari, ["Add to Home Screen"], espera: 2)
        if add == nil, let comp = achar(safari, ["Share", "ShareButton"], espera: 4) {
            comp.tap(); sleep(3)
            add = achar(safari, ["Add to Home Screen"], espera: 3)
            var n = 0
            while (add == nil || !add!.isHittable) && n < 5 { safari.swipeUp(); sleep(1); add = achar(safari, ["Add to Home Screen"], espera: 2); n += 1 }
        }
        guard let botao = add else { XCTFail("sem Add to Home Screen"); return }
        botao.tap()
        sleep(3)
        guard let confirmar = achar(safari, ["Add"], espera: 4) else { XCTFail("sem Add"); return }
        confirmar.tap()
        sleep(4)
        XCUIDevice.shared.press(.home)
        sleep(2)
        let icone = springboard.icons[nome].firstMatch
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 3 { springboard.swipeLeft(); sleep(1); i += 1 }
        guard icone.exists else { foto("\(variante)_sem_icone"); XCTFail("ícone \(nome) não apareceu"); return }
        icone.tap()
        sleep(10)
        foto("\(variante)_b_app")
        sleep(6)
        foto("\(variante)_c_app_depois")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        foto("\(variante)_d_deitado")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(1)
    }
}
