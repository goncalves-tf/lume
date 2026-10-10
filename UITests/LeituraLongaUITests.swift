import XCTest

// Leitura longa com a voz Faber (livro de exemplo Dom Casmurro, domínio público), para medir a memória do
// app e ver se a página fecha sozinha. O workflow passa LUME_MINUTOS e mede o processo durante o teste.
final class LeituraLongaUITests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let web = XCUIApplication(bundleIdentifier: "com.apple.webapp")
    var tela: CGSize { XCUIScreen.main.screenshot().image.size }

    func foto(_ nome: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = nome
        a.lifetime = .keepAlways
        add(a)
    }

    func nota(_ texto: String, _ nome: String) { print("LUME: \(nome): \(texto)") }

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

    func tocar(_ x: CGFloat, _ y: CGFloat) {
        springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    func testLeituraLonga() throws {
        guard let minutosTexto = ProcessInfo.processInfo.environment["LUME_MINUTOS"] else { throw XCTSkip("só no workflow da memória") }
        let minutos = Int(minutosTexto) ?? 10
        let t = tela
        safari.activate()
        sleep(4)
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { break }
        }
        guard achar(safari, ["Ou experimente com Dom Casmurro, de Machado de Assis", "Adicionar livro"], espera: 45) != nil else { XCTFail("site não carregou"); return }
        if let mais = achar(safari, ["MoreMenuButton", "More"], espera: 4) { mais.tap(); sleep(2) }
        var add = achar(safari, ["Add to Home Screen"], espera: 2)
        if add == nil, let comp = achar(safari, ["Share", "ShareButton"], espera: 4) {
            comp.tap(); sleep(3)
            add = achar(safari, ["Add to Home Screen"], espera: 3)
            var n = 0
            while (add == nil || !add!.isHittable) && n < 5 { safari.swipeUp(); sleep(1); add = achar(safari, ["Add to Home Screen"], espera: 2); n += 1 }
        }
        guard let botao = add else { XCTFail("sem Add to Home Screen"); return }
        botao.tap(); sleep(3)
        guard let ok = achar(safari, ["Add"], espera: 4) else { XCTFail("sem Add"); return }
        var espera = 0
        while !ok.isEnabled && espera < 30 { sleep(1); espera += 1 }
        ok.tap(); sleep(4)
        XCUIDevice.shared.press(.home); sleep(2)
        let icone = springboard.icons["Lume"].firstMatch
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 3 { springboard.swipeLeft(); sleep(1); i += 1 }
        guard icone.exists else { XCTFail("ícone não encontrado"); return }
        icone.tap()
        guard let exemplo = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 60) else { XCTFail("estante não carregou"); return }
        exemplo.tap()
        var aberto = achar(web, ["Trocar informação do rodapé"], espera: 30) != nil
        if !aberto {
            foto("livro_nao_abriu_1")
            // Às vezes o primeiro toque chega antes da estante ficar pronta: toca de novo.
            if let de_novo = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 3) { de_novo.tap() }
            aberto = achar(web, ["Trocar informação do rodapé"], espera: 45) != nil
        }
        guard aberto else { foto("livro_nao_abriu_2"); XCTFail("livro não abriu"); return }
        sleep(3)
        nota("livro aberto, sem voz", "medir_1_sem_voz")
        sleep(20)
        tocar(t.width / 2, t.height * 0.5); sleep(2)
        guard let ouvir = achar(web, ["Ouvir"], espera: 4) else { XCTFail("sem Ouvir"); return }
        ouvir.tap(); sleep(2)
        if let okVoz = achar(web, ["OK"], espera: 5) ?? achar(springboard, ["OK"], espera: 1) { okVoz.tap() }
        XCTAssertTrue(achar(web, ["Pausar"], espera: 150) != nil, "começou a ler")
        nota("começou", "longa_inicio")
        var parou = -1
        for minuto in 1...minutos {
            sleep(60)
            if minuto == 2 { nota("lendo há 2 min", "medir_2_lendo") }
            if minuto == minutos { nota("lendo há \(minuto) min", "medir_3_fim") }
            let lendo = achar(web, ["Pausar"], espera: 3) != nil
            nota(lendo ? "lendo" : "PAROU", "longa_minuto_\(minuto)")
            if !lendo && parou < 0 { parou = minuto; foto("parou_\(minuto)") }
        }
        foto("fim")
        nota(parou < 0 ? "leu \(minutos) minutos sem parar" : "parou no minuto \(parou)", "longa_resultado")
        XCTAssertTrue(parou < 0, "leitura longa sem parar")
    }

    // Com a voz lendo, ele abre outro app (Relógio, para o cronômetro) por 90 s e volta.
    // A voz tem que continuar fora da tela; o relatório do app mostra o que tocou enquanto estava escondido.
    func testForaDaTela() throws {
        guard ProcessInfo.processInfo.environment["LUME_FORA"] != nil else { throw XCTSkip("só no workflow") }
        let t = tela
        safari.activate()
        sleep(4)
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { break }
        }
        guard achar(safari, ["Ou experimente com Dom Casmurro, de Machado de Assis", "Adicionar livro"], espera: 45) != nil else { XCTFail("site não carregou"); return }
        if let mais = achar(safari, ["MoreMenuButton", "More"], espera: 4) { mais.tap(); sleep(2) }
        var add = achar(safari, ["Add to Home Screen"], espera: 2)
        if add == nil, let comp = achar(safari, ["Share", "ShareButton"], espera: 4) {
            comp.tap(); sleep(3)
            add = achar(safari, ["Add to Home Screen"], espera: 3)
            var n = 0
            while (add == nil || !add!.isHittable) && n < 5 { safari.swipeUp(); sleep(1); add = achar(safari, ["Add to Home Screen"], espera: 2); n += 1 }
        }
        guard let botao = add else { XCTFail("sem Add to Home Screen"); return }
        botao.tap(); sleep(3)
        guard let ok = achar(safari, ["Add"], espera: 4) else { XCTFail("sem Add"); return }
        var espera = 0
        while !ok.isEnabled && espera < 30 { sleep(1); espera += 1 }
        ok.tap(); sleep(4)
        XCUIDevice.shared.press(.home); sleep(2)
        let icone = springboard.icons["Lume"].firstMatch
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 3 { springboard.swipeLeft(); sleep(1); i += 1 }
        guard icone.exists else { XCTFail("ícone não encontrado"); return }
        icone.tap()
        var exemploAchado = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 60)
        if exemploAchado == nil {
            foto("estante_demorou")
            web.terminate(); sleep(2); icone.tap()
            exemploAchado = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 60)
        }
        guard let exemplo = exemploAchado else { foto("estante_nao_carregou"); XCTFail("estante não carregou"); return }
        exemplo.tap()
        var aberto = achar(web, ["Trocar informação do rodapé"], espera: 30) != nil
        if !aberto, let de_novo = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 3) { de_novo.tap(); aberto = achar(web, ["Trocar informação do rodapé"], espera: 45) != nil }
        guard aberto else { XCTFail("livro não abriu"); return }
        sleep(3)
        tocar(t.width / 2, t.height * 0.5); sleep(2)
        guard let ouvir = achar(web, ["Ouvir"], espera: 4) else { XCTFail("sem Ouvir"); return }
        ouvir.tap(); sleep(2)
        if let okVoz = achar(web, ["OK"], espera: 5) ?? achar(springboard, ["OK"], espera: 1) { okVoz.tap() }
        XCTAssertTrue(achar(web, ["Pausar"], espera: 150) != nil, "começou a ler")
        sleep(40)
        nota("vai para outro app", "fora_inicio")
        // O simulador não tem o Relógio: abre os Ajustes (o efeito é o mesmo, o Lume sai da tela).
        let outro = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        outro.activate()
        sleep(4)
        foto("outro_app")
        sleep(90)
        nota("volta para o Lume", "fora_fim")
        web.activate()
        sleep(5)
        let lendo = achar(web, ["Pausar"], espera: 5) != nil
        nota(lendo ? "lendo ao voltar" : "PAROU", "fora_resultado")
        // Relatório do app (o workflow lê a área de transferência).
        tocar(t.width / 2, t.height * 0.5); sleep(2)
        if let texto = achar(web, ["Texto"], espera: 4) {
            texto.tap(); sleep(2)
            var b = achar(web, ["Copiar relatório de problemas"], espera: 3)
            var n = 0
            while (b == nil || !b!.isHittable) && n < 6 { web.swipeUp(); sleep(1); b = achar(web, ["Copiar relatório de problemas"], espera: 2); n += 1 }
            b?.tap(); sleep(2)
            nota("copiou", "diario_fora_copiado")
            sleep(6)
        }
    }

    // Pinça no livro de exemplo: aumenta e diminui a letra; o relatório do app mostra como foi.
    func testPinca() throws {
        guard ProcessInfo.processInfo.environment["LUME_PINCA"] != nil else { throw XCTSkip("só no workflow") }
        let t = tela
        safari.activate()
        sleep(4)
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { break }
        }
        guard let exemplo = achar(safari, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 45) else { XCTFail("site não carregou"); return }
        exemplo.tap()
        guard achar(safari, ["Trocar informação do rodapé"], espera: 60) != nil else { XCTFail("livro não abriu"); return }
        sleep(3)
        foto("pinca_inicio")
        for i in 0..<5 { tocar(t.width * 0.92, t.height * 0.55); sleep(2); foto("pinca_virou_\(i + 1)") }
        foto("pinca_antes")
        safari.webViews.firstMatch.pinch(withScale: 1.3, velocity: 0.5)
        sleep(3)
        foto("pinca_maior")
        safari.webViews.firstMatch.pinch(withScale: 0.7, velocity: -0.8)
        sleep(3)
        foto("pinca_menor")
        tocar(t.width / 2, t.height * 0.5); sleep(2)
        if let texto = achar(safari, ["Texto"], espera: 4) {
            texto.tap(); sleep(2)
            var b = achar(safari, ["Copiar relatório de problemas"], espera: 3)
            var n = 0
            while (b == nil || !b!.isHittable) && n < 6 { safari.swipeUp(); sleep(1); b = achar(safari, ["Copiar relatório de problemas"], espera: 2); n += 1 }
            b?.tap(); sleep(2)
            nota("copiou", "diario_pinca_copiado")
            sleep(6)
        }
    }
}
