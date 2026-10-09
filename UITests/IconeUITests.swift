import XCTest

// Laboratório do ícone: um app da Tela de Início consegue ter ícone diferente no modo noturno?
// O workflow instala lab/icone-a, icone-b, icone-c (modo claro), fotografa a Tela de Início, liga o modo
// noturno e fotografa de novo; depois instala icone-a2 já no modo noturno.
final class IconeUITests: XCTestCase {
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

    func testInstalar() throws {
        guard let nome = ProcessInfo.processInfo.environment["LUME_ICONE"] else { throw XCTSkip("só no workflow do ícone") }
        safari.activate()
        sleep(4)
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { break }
        }
        if let mais = achar(safari, ["MoreMenuButton", "More"], espera: 4) { mais.tap(); sleep(2) }
        var add = achar(safari, ["Add to Home Screen"], espera: 2)
        if add == nil, let comp = achar(safari, ["Share", "ShareButton"], espera: 4) {
            comp.tap(); sleep(3)
            add = achar(safari, ["Add to Home Screen"], espera: 3)
            var n = 0
            while (add == nil || !add!.isHittable) && n < 5 { safari.swipeUp(); sleep(1); add = achar(safari, ["Add to Home Screen"], espera: 2); n += 1 }
        }
        guard let botao = add else { foto("\(nome)_sem_menu"); XCTFail("sem Add to Home Screen"); return }
        botao.tap()
        sleep(3)
        foto("\(nome)_tela_de_adicionar")
        guard let confirmar = achar(safari, ["Add"], espera: 4) else { XCTFail("sem Add"); return }
        confirmar.tap()
        sleep(4)
        XCUIDevice.shared.press(.home)
        sleep(2)
    }

    func testFotoInicio() throws {
        guard let rotulo = ProcessInfo.processInfo.environment["LUME_FOTO"] else { throw XCTSkip("só no workflow do ícone") }
        XCUIDevice.shared.press(.home)
        sleep(3)
        // Vai até a página onde estão os ícones novos e fotografa.
        var i = 0
        while !springboard.icons["IconeA"].firstMatch.isHittable && i < 4 { springboard.swipeLeft(); sleep(1); i += 1 }
        sleep(2)
        foto("inicio_\(rotulo)")
    }
}
