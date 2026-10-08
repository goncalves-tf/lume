import XCTest

// Teste no Simulador do iOS com o Safari de verdade: instala o Lume na Tela de Início,
// abre como app (modo tela cheia), abre o livro de exemplo, usa os controles, fecha e reabre
// para conferir que voltou na mesma página. Tira prints de cada passo.
final class LumeUITests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    var site: String { ProcessInfo.processInfo.environment["LUME_URL"] ?? "https://goncalves-tf.github.io/lume/" }

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

    func nota(_ texto: String, _ nome: String) {
        let a = XCTAttachment(string: texto)
        a.name = nome
        a.lifetime = .keepAlways
        add(a)
        print("LUME: \(nome): \(texto)")
    }

    // Primeiro elemento que existe entre vários rótulos possíveis (o Safari muda de versão para versão).
    func achar(_ app: XCUIApplication, _ rotulos: [String], tipos: [XCUIElement.ElementType] = [.button, .cell, .staticText, .other, .link], espera: TimeInterval = 2) -> XCUIElement? {
        let fim = Date().addingTimeInterval(espera)
        repeat {
            for r in rotulos {
                for t in tipos {
                    let e = app.descendants(matching: t).matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@", r, r)).firstMatch
                    if e.exists { return e }
                }
            }
            usleep(250_000)
        } while Date() < fim
        return nil
    }

    func tocarTela(_ x: CGFloat, _ y: CGFloat) {
        // Toque por posição na tela inteira (vale para o app da Tela de Início).
        let c = springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
        c.tap()
    }

    func adicionarATelaDeInicio() -> Bool {
        safari.activate()
        sleep(3)
        // Botão Compartilhar direto, ou dentro do menu "Mais" (Safari 26).
        var compartilhar = achar(safari, ["Share", "ShareButton", "Compartilhar"], tipos: [.button], espera: 4)
        if compartilhar == nil || !(compartilhar!.isHittable) {
            if let mais = achar(safari, ["More", "Page Menu", "PageFormatMenuButton", "Mais", "…", "MoreButton"], tipos: [.button], espera: 3) {
                mais.tap()
                sleep(2)
                foto("02a_menu_mais")
                arvore(safari, "02a_menu_mais_arvore")
                compartilhar = achar(safari, ["Share", "Compartilhar", "Share…"], espera: 3)
            }
        }
        guard let botao = compartilhar else { nota("não achei Compartilhar", "erro"); return false }
        botao.tap()
        sleep(3)
        foto("02b_compartilhar")
        arvore(safari, "02b_compartilhar_arvore")
        var adicionar = achar(safari, ["Add to Home Screen", "Adicionar à Tela de Início"], espera: 3)
        var tentativas = 0
        while (adicionar == nil || !adicionar!.isHittable) && tentativas < 5 {
            safari.swipeUp()
            sleep(1)
            adicionar = achar(safari, ["Add to Home Screen", "Adicionar à Tela de Início"], espera: 2)
            tentativas += 1
        }
        guard let add = adicionar else { arvore(safari, "02c_sem_adicionar"); nota("não achei Add to Home Screen", "erro"); return false }
        add.tap()
        sleep(3)
        foto("02d_tela_adicionar")
        arvore(safari, "02d_tela_adicionar_arvore")
        guard let confirmar = achar(safari, ["Add", "Adicionar"], tipos: [.button], espera: 4) else { nota("não achei Add", "erro"); return false }
        confirmar.tap()
        sleep(4)
        return true
    }

    func abrirPeloIcone() -> Bool {
        XCUIDevice.shared.press(.home)
        sleep(2)
        let icone = springboard.icons["Lume"]
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 4 {
            springboard.swipeLeft()
            sleep(1)
            i += 1
        }
        foto("03a_tela_de_inicio")
        guard icone.exists else { arvore(springboard, "03a_springboard_arvore"); nota("ícone não encontrado", "erro"); return false }
        icone.tap()
        sleep(7)
        return true
    }

    func testInstalarEUsarComoApp() throws {
        continueAfterFailure = true
        let tela = XCUIScreen.main.screenshot().image.size
        nota("tela \(tela.width)x\(tela.height) pt, iOS \(UIDevice.current.systemVersion), \(UIDevice.current.name)", "aparelho")

        safari.activate()
        sleep(8)
        foto("01_safari")
        arvore(safari, "01_safari_arvore")

        XCTAssertTrue(adicionarATelaDeInicio(), "adicionar à Tela de Início")
        XCTAssertTrue(abrirPeloIcone(), "abrir pelo ícone")
        foto("04_app_estante_vazia")
        arvore(springboard, "04_springboard_com_app")
        let webapp = XCUIApplication(bundleIdentifier: "com.apple.webapp")
        nota("estado webapp: \(webapp.state.rawValue)", "webapp")
        arvore(webapp, "04_webapp_arvore")

        // Livro de exemplo
        if let ex = achar(webapp, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 5) {
            nota("botão exemplo em \(ex.frame)", "exemplo")
            ex.tap()
        } else {
            tocarTela(tela.width / 2, tela.height * 0.66)
        }
        sleep(10)
        foto("05_livro_aberto")
        arvore(webapp, "05_livro_arvore")

        // Virar páginas (lado direito) e voltar (esquerdo)
        for _ in 0..<3 { tocarTela(tela.width * 0.9, tela.height * 0.5); sleep(2) }
        foto("06_tres_paginas_depois")
        tocarTela(tela.width * 0.1, tela.height * 0.5)
        sleep(2)
        foto("07_voltou_uma")

        // Controles
        tocarTela(tela.width / 2, tela.height * 0.5)
        sleep(2)
        foto("08_controles")
        arvore(webapp, "08_controles_arvore")

        // Ajustes de texto: tema Noite
        if let texto = achar(webapp, ["Texto"], tipos: [.button], espera: 3) {
            texto.tap()
            sleep(2)
            foto("09_ajustes")
            if let noite = achar(webapp, ["Noite"], tipos: [.button], espera: 3) { noite.tap(); sleep(2) }
            foto("10_ajustes_noite")
            if let fechar = achar(webapp, ["Fechar"], tipos: [.button], espera: 2) { fechar.tap() }
            sleep(2)
            foto("11_pagina_noite")
        }

        // Ouvir (voz do aparelho)
        tocarTela(tela.width / 2, tela.height * 0.5)
        sleep(2)
        if let ouvir = achar(webapp, ["Ouvir"], tipos: [.button], espera: 3) {
            ouvir.tap()
            sleep(6)
            foto("12_ouvindo")
            arvore(webapp, "12_ouvindo_arvore")
            if let pausa = achar(webapp, ["Pausar"], tipos: [.button], espera: 2) { pausa.tap(); sleep(1) }
            if let fechar = achar(webapp, ["Fechar leitura em voz alta"], tipos: [.button], espera: 2) { fechar.tap(); sleep(1) }
        }

        // Deitado
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(4)
        foto("13_deitado")
        XCUIDevice.shared.orientation = .portrait
        sleep(4)
        foto("14_em_pe_de_novo")

        // Fecha o app de vez e abre de novo: precisa voltar na mesma página, com o livro guardado.
        XCUIDevice.shared.press(.home)
        sleep(2)
        webapp.terminate()
        sleep(2)
        XCTAssertTrue(abrirPeloIcone(), "reabrir pelo ícone")
        sleep(3)
        foto("15_reaberto")
        arvore(webapp, "15_reaberto_arvore")
    }
}
