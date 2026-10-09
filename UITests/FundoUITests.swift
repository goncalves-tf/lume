import XCTest

// Laboratório: qual jeito de tocar áudio continua com o app da Tela de Início fora da tela?
// O workflow abre lab/fundo-<modo>/ no Safari e passa LUME_FUNDO (nome do ícone: FElemento, FWebaudio, FMse).
final class FundoUITests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let web = XCUIApplication(bundleIdentifier: "com.apple.webapp")

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

    func acharContendo(_ app: XCUIApplication, _ trecho: String, espera: TimeInterval = 3) -> XCUIElement? {
        let fim = Date().addingTimeInterval(espera)
        let pred = NSPredicate(format: "label CONTAINS[c] %@", trecho)
        repeat {
            let e = app.descendants(matching: .any).matching(pred).firstMatch
            if e.exists { return e }
            usleep(300_000)
        } while Date() < fim
        return nil
    }

    func testFundo() throws {
        guard let nome = ProcessInfo.processInfo.environment["LUME_FUNDO"] else { throw XCTSkip("só no workflow do fundo") }
        safari.activate()
        sleep(4)
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { break }
        }
        guard achar(safari, ["Começar"], espera: 40) != nil else { XCTFail("página não carregou"); return }
        sleep(3)
        if let mais = achar(safari, ["MoreMenuButton", "More"], espera: 4) { mais.tap(); sleep(2) }
        var adicionar = achar(safari, ["Add to Home Screen"], espera: 2)
        if adicionar == nil, let comp = achar(safari, ["Share", "ShareButton"], espera: 4) {
            comp.tap(); sleep(3)
            adicionar = achar(safari, ["Add to Home Screen"], espera: 3)
            var n = 0
            while (adicionar == nil || !adicionar!.isHittable) && n < 5 { safari.swipeUp(); sleep(1); adicionar = achar(safari, ["Add to Home Screen"], espera: 2); n += 1 }
        }
        guard let botao = adicionar else { XCTFail("sem Add to Home Screen"); return }
        botao.tap(); sleep(3)
        guard let ok = achar(safari, ["Add"], espera: 4) else { XCTFail("sem Add"); return }
        var espera = 0
        while !ok.isEnabled && espera < 30 { sleep(1); espera += 1 }
        ok.tap(); sleep(4)
        XCUIDevice.shared.press(.home); sleep(2)
        let icone = springboard.icons[nome].firstMatch
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 3 { springboard.swipeLeft(); sleep(1); i += 1 }
        guard icone.exists else { XCTFail("ícone \(nome) não encontrado"); return }
        icone.tap()
        guard let comecar = achar(web, ["Começar"], espera: 40) else { XCTFail("app não abriu"); return }
        comecar.tap()
        sleep(12)
        foto("\(nome)_tocando")
        // Sai da tela por 40 s (Ajustes) e volta.
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        sleep(40)
        web.activate()
        sleep(4)
        foto("\(nome)_de_volta")
        let r = acharContendo(web, "RESULTADO", espera: 5)?.label ?? "sem resultado"
        print("LUME: fundo_\(nome): \(r)")
        let a = XCTAttachment(string: web.debugDescription)
        a.name = "\(nome)_arvore"
        a.lifetime = .keepAlways
        add(a)
    }
}
