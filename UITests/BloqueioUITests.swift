import XCTest

// Tela bloqueada com a voz lendo: o botão de pausar pausa? Tocar na notificação abre o Lume?
// O workflow instala outro app da Tela de Início (Bobossauro, mesmo endereço do Lume; ou um site de outro
// endereço), abre esse outro app, depois abre o Lume, liga a voz, bloqueia a tela e testa.
final class BloqueioUITests: XCTestCase {
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

    func arvore(_ app: XCUIApplication, _ nome: String) {
        let a = XCTAttachment(string: app.debugDescription)
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

    func tocar(_ x: CGFloat, _ y: CGFloat) {
        springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    func abrirIcone(_ nome: String) -> Bool {
        XCUIDevice.shared.press(.home); sleep(2)
        let icone = springboard.icons[nome].firstMatch
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 3 { springboard.swipeLeft(); sleep(1); i += 1 }
        guard icone.exists else { foto("sem_icone_\(nome)"); return false }
        icone.tap()
        return true
    }

    // Adiciona à Tela de Início a página aberta no Safari (o workflow abre a página antes).
    func testInstalar() throws {
        guard let nome = ProcessInfo.processInfo.environment["LUME_INSTALAR"] else { throw XCTSkip("só no workflow") }
        safari.activate()
        sleep(6)
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
        botao.tap(); sleep(3)
        guard let confirmar = achar(safari, ["Add"], espera: 4) else { XCTFail("sem Add"); return }
        var n = 0
        while !confirmar.isEnabled && n < 30 { sleep(1); n += 1 }
        confirmar.tap(); sleep(4)
        XCUIDevice.shared.press(.home); sleep(2)
        foto("\(nome)_instalado")
    }

    // Abre o outro app da Tela de Início e volta para o início (ele fica aberto por trás, como no iPhone dele).
    func testAbrirOutro() throws {
        guard let nome = ProcessInfo.processInfo.environment["LUME_OUTRO"] else { throw XCTSkip("só no workflow") }
        guard abrirIcone(nome) else { XCTFail("sem ícone \(nome)"); return }
        sleep(12)
        foto("outro_aberto_\(nome)")
        XCUIDevice.shared.press(.home); sleep(2)
    }

    func testBloqueio() throws {
        guard let cenario = ProcessInfo.processInfo.environment["LUME_BLOQUEIO"] else { throw XCTSkip("só no workflow") }
        let t = tela
        guard abrirIcone("Lume") else { XCTFail("sem ícone do Lume"); return }
        var exemplo = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 60)
        if exemplo == nil { web.terminate(); sleep(2); _ = abrirIcone("Lume"); exemplo = achar(web, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 60) }
        guard let ex = exemplo else { foto("\(cenario)_estante_nao_carregou"); XCTFail("estante não carregou"); return }
        ex.tap()
        guard achar(web, ["Trocar informação do rodapé"], espera: 60) != nil else { XCTFail("livro não abriu"); return }
        sleep(3)
        for _ in 0..<4 { tocar(t.width * 0.92, t.height * 0.55); sleep(2) }
        tocar(t.width / 2, t.height * 0.5); sleep(2)
        guard let ouvir = achar(web, ["Ouvir"], espera: 4) else { XCTFail("sem Ouvir"); return }
        ouvir.tap(); sleep(2)
        if let okVoz = achar(web, ["OK"], espera: 5) ?? achar(springboard, ["OK"], espera: 1) { okVoz.tap() }
        XCTAssertTrue(achar(web, ["Pausar"], espera: 180) != nil, "começou a ler")
        sleep(15)
        foto("\(cenario)_1_lendo")
        // Como ele usa: pausa e volta a tocar pelo app antes de bloquear a tela.
        if ProcessInfo.processInfo.environment["LUME_PAUSA_ANTES"] != nil {
            if let p = achar(web, ["Pausar"], espera: 3) { p.tap(); sleep(3) }
            if let t = achar(web, ["Tocar"], espera: 3) { t.tap(); sleep(8) }
            nota(achar(web, ["Pausar"], espera: 3) != nil ? "voltou a ler pelo app" : "NÃO voltou a ler", "\(cenario)_pausa_no_app")
        }

        // Como pode ter acontecido no iPhone dele: com a voz lendo, abre outro app da Tela de Início por cima.
        if let outro = ProcessInfo.processInfo.environment["LUME_OUTRO_POR_ULTIMO"] {
            _ = abrirIcone(outro)
            sleep(12)
            foto("\(cenario)_1b_outro_por_cima")
            nota("abriu \(outro) por cima com a voz lendo", "\(cenario)_outro_por_cima")
        }
        // Bloqueia e acende a tela (fica na tela bloqueada, com os controles da voz).
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(3)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(4)
        foto("\(cenario)_2_bloqueada")
        arvore(springboard, "\(cenario)_2_arvore_bloqueada")

        // Pausar pela tela bloqueada, duas vezes (pausa, toca, pausa, toca).
        for vez in 1...2 {
            if let pausa = achar(springboard, ["Pause", "Pausar"], espera: 5) {
                nota("achou o botão de pausa (\(pausa.label))", "\(cenario)_pausa_\(vez)")
                pausa.tap()
                sleep(6)
                foto("\(cenario)_3_depois_de_pausar_\(vez)")
                if vez == 1 { arvore(springboard, "\(cenario)_3_arvore_depois_de_pausar") }
                let virouPlay = achar(springboard, ["Play", "Reproduzir", "Tocar"], espera: 3) != nil
                nota(virouPlay ? "o botão virou Play" : "o botão continua Pausa", "\(cenario)_pausa_resultado_\(vez)")
                if let play = achar(springboard, ["Play", "Reproduzir", "Tocar"], espera: 2) { play.tap(); sleep(8) }
            } else {
                nota("SEM botão de pausa na tela bloqueada", "\(cenario)_pausa_\(vez)")
            }
        }

        // Toca na notificação (capa/título) para abrir o app.
        let alvo = acharContendo(springboard, "Machado", espera: 3) ?? acharContendo(springboard, "Dom Casmurro", espera: 2)
        if let a = alvo {
            nota("toca em \(a.label)", "\(cenario)_abrir")
            a.tap()
        } else {
            nota("sem título na tela bloqueada; toca na capa", "\(cenario)_abrir")
            tocar(t.width / 2, t.height * 0.33)
        }
        sleep(6)
        foto("\(cenario)_4_abriu")
        // Só conta o que está na frente (o outro app aberto por trás também aparece na árvore, mas não é tocável).
        let lume = achar(web, ["Trocar informação do rodapé", "Pausar", "Ouvir"], espera: 3)?.isHittable ?? false
        let bobo = (acharContendo(web, "código do casal", espera: 2) ?? acharContendo(web, "Segura pra marcar", espera: 1))?.isHittable ?? false
        let site = acharContendo(web, "Example Domain", espera: 1)?.isHittable ?? false
        nota("lume=\(lume) bobossauro=\(bobo) example=\(site) estadoWeb=\(web.state.rawValue)", "\(cenario)_abriu")
        arvore(web, "\(cenario)_4_arvore_web")

        // Relatório do app (o workflow lê a área de transferência).
        if !lume { _ = abrirIcone("Lume"); sleep(5) }
        tocar(t.width / 2, t.height * 0.5); sleep(2)
        if let texto = achar(web, ["Texto"], espera: 4) {
            texto.tap(); sleep(2)
            var b = achar(web, ["Copiar relatório de problemas"], espera: 3)
            var n = 0
            while (b == nil || !b!.isHittable) && n < 6 { web.swipeUp(); sleep(1); b = achar(web, ["Copiar relatório de problemas"], espera: 2); n += 1 }
            b?.tap(); sleep(2)
            nota("copiou", "diario_bloqueio_copiado")
            sleep(6)
        }
    }
}
