import XCTest

// Teste no Simulador do iOS com o Safari de verdade.
// test1: o Lume dentro do Safari (abre o livro de exemplo, vira páginas, controles, ajustes, voz, deitado).
// test2: instala na Tela de Início, abre como app (tela cheia), usa, fecha e reabre (tem que voltar na mesma página).
final class LumeUITests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    var site: String { ProcessInfo.processInfo.environment["LUME_URL"] ?? "https://goncalves-tf.github.io/lume/" }
    var tela: CGSize { XCUIScreen.main.screenshot().image.size }

    override func setUp() {
        continueAfterFailure = true
    }

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

    // Primeiro elemento que existe entre vários rótulos/identificadores possíveis.
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

    // Toque por posição (pontos) na tela inteira: vale para qualquer app em primeiro plano.
    func tocar(_ x: CGFloat, _ y: CGFloat) {
        springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    func fecharDicasDoSafari() {
        for _ in 0..<3 {
            if let x = achar(safari, ["xmark.circle.fill", "Close", "Not Now", "Continue"], espera: 1), x.isHittable { x.tap(); sleep(1) } else { return }
        }
    }

    // Qualquer sinal de que o Lume carregou (estante ou leitor).
    let sinaisDoLume = ["Ou experimente com Dom Casmurro, de Machado de Assis", "Adicionar livro", "Trocar informação do rodapé", "Ajustes e backup"]

    func abrirSite() {
        safari.activate()
        sleep(3)
        fecharDicasDoSafari()
        if achar(safari, sinaisDoLume, espera: 15) != nil { return }
        // Não carregou: abre o endereço e espera a página de verdade (não instala página em branco).
        if let campo = achar(safari, ["TabBarItemTitle", "URL", "Address", "Search or enter website name"], espera: 3) {
            campo.tap()
            safari.typeText(site + "\n")
        }
        let ok = achar(safari, sinaisDoLume, espera: 45) != nil
        nota(ok ? "site carregado" : "site não carregou", "abrir_site")
        sleep(2)
    }

    // Usa o próprio app (no Safari ou instalado): abre o exemplo, vira, controles, ajustes, voz, deitado.
    func usarLeitor(_ app: XCUIApplication, _ prefixo: String) {
        let t = tela
        let t0 = Date()
        if let ex = achar(app, ["Ou experimente com Dom Casmurro, de Machado de Assis"], espera: 60) {
            nota(String(format: "estante pronta em %.1f s", Date().timeIntervalSince(t0)), prefixo + "tempo_estante")
            ex.tap()
        } else {
            nota("botão do exemplo não apareceu na árvore; tocando pela posição", prefixo + "aviso")
            tocar(t.width / 2, t.height * 0.80)
        }
        sleep(10)
        foto(prefixo + "05_livro_aberto")
        arvore(app, prefixo + "05_livro_arvore")
        for _ in 0..<3 { tocar(t.width * 0.9, t.height * 0.5); sleep(2) }
        foto(prefixo + "06_tres_paginas")
        tocar(t.width * 0.1, t.height * 0.5)
        sleep(2)
        foto(prefixo + "07_voltou_uma")
        tocar(t.width / 2, t.height * 0.5)
        sleep(2)
        foto(prefixo + "08_controles")
        arvore(app, prefixo + "08_controles_arvore")
        if let texto = achar(app, ["Texto"], espera: 3) {
            texto.tap()
            sleep(2)
            foto(prefixo + "09_ajustes")
            if let noite = achar(app, ["Noite"], espera: 3) { noite.tap(); sleep(2) }
            foto(prefixo + "10a_logo_apos_noite")
            foto(prefixo + "10_ajustes_noite")
            if let fechar = achar(app, ["Fechar"], espera: 2) { fechar.tap() }
            sleep(2)
            foto(prefixo + "11_pagina_noite")
        } else { nota("botão Texto não apareceu", prefixo + "aviso") }
        tocar(t.width / 2, t.height * 0.5)
        sleep(2)
        if let ouvir = achar(app, ["Ouvir"], espera: 3) {
            ouvir.tap()
            sleep(3)
            // A voz natural no aparelho pede confirmação para baixar: aceita.
            if let ok = achar(app, ["OK", "Ok"], espera: 4) ?? achar(springboard, ["OK"], espera: 1) { ok.tap() }
            sleep(25)
            foto(prefixo + "12_ouvindo")
            arvore(app, prefixo + "12_ouvindo_arvore")
            sleep(10)
            foto(prefixo + "12b_ouvindo_depois")
            if let pausa = achar(app, ["Pausar"], espera: 2) { pausa.tap(); sleep(1) }
            if let fechar = achar(app, ["Fechar leitura em voz alta"], espera: 2) { fechar.tap(); sleep(1) }
        } else { nota("botão Ouvir não apareceu", prefixo + "aviso") }
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(4)
        foto(prefixo + "13_deitado")
        XCUIDevice.shared.orientation = .portrait
        sleep(4)
        foto(prefixo + "14_em_pe")
    }

    func test1_NoSafari() throws {
        nota("tela \(tela.width)x\(tela.height) pt, iOS \(UIDevice.current.systemVersion)", "aparelho")
        abrirSite()
        foto("s01_safari")
        arvore(safari, "s01_safari_arvore")
        usarLeitor(safari, "s")
    }

    func adicionarATelaDeInicio() -> Bool {
        safari.activate()
        sleep(2)
        fecharDicasDoSafari()
        // Safari 26: "⋯" (More) -> Compartilhar -> Adicionar à Tela de Início. Versões antigas: botão Compartilhar direto.
        if let mais = achar(safari, ["MoreMenuButton", "More"], espera: 4) {
            mais.tap()
            sleep(2)
            foto("t02a_menu_mais")
            arvore(safari, "t02a_menu_mais_arvore")
        }
        var adicionar = achar(safari, ["Add to Home Screen", "Adicionar à Tela de Início"], espera: 2)
        if adicionar == nil {
            guard let comp = achar(safari, ["Share", "ShareButton", "Compartilhar", "Share…"], espera: 4) else {
                nota("não achei Compartilhar", "erro"); return false
            }
            comp.tap()
            sleep(3)
            foto("t02b_compartilhar")
            arvore(safari, "t02b_compartilhar_arvore")
            adicionar = achar(safari, ["Add to Home Screen", "Adicionar à Tela de Início"], espera: 3)
            var n = 0
            while (adicionar == nil || !adicionar!.isHittable) && n < 5 {
                safari.swipeUp()
                sleep(1)
                adicionar = achar(safari, ["Add to Home Screen", "Adicionar à Tela de Início"], espera: 2)
                n += 1
            }
        }
        guard let add = adicionar else { arvore(safari, "t02c_sem_adicionar"); nota("não achei Add to Home Screen", "erro"); return false }
        add.tap()
        sleep(3)
        foto("t02d_tela_adicionar")
        arvore(safari, "t02d_tela_adicionar_arvore")
        guard let confirmar = achar(safari, ["Add", "Adicionar"], espera: 4) else { nota("não achei Add", "erro"); return false }
        confirmar.tap()
        sleep(5)
        foto("t02e_depois_de_adicionar")
        return true
    }

    func abrirPeloIcone() -> Bool {
        XCUIDevice.shared.press(.home)
        sleep(2)
        let icone = springboard.icons["Lume"].firstMatch
        var i = 0
        while !(icone.exists && icone.isHittable) && i < 3 {
            springboard.swipeLeft()
            sleep(1)
            i += 1
        }
        foto("t03_tela_de_inicio")
        guard icone.exists else { arvore(springboard, "t03_springboard_arvore"); nota("ícone não encontrado", "erro"); return false }
        icone.tap()
        sleep(8)
        return true
    }

    // O app da Tela de Início roda num processo próprio: acha qual é pelo que está em primeiro plano.
    func appWeb() -> XCUIApplication {
        for id in ["com.apple.webapp", "com.apple.WebSheet", "com.apple.SafariViewService", "com.apple.mobilesafari"] {
            let a = XCUIApplication(bundleIdentifier: id)
            if a.state == .runningForeground { nota("app web em primeiro plano: \(id)", "webapp"); return a }
        }
        nota("app web: processo não identificado", "webapp")
        return XCUIApplication(bundleIdentifier: "com.apple.webapp")
    }

    func test2_InstaladoNaTelaDeInicio() throws {
        abrirSite()
        guard adicionarATelaDeInicio() else { XCTFail("não consegui adicionar à Tela de Início"); return }
        let inicio = Date()
        guard abrirPeloIcone() else { XCTFail("ícone do Lume não apareceu"); return }
        nota(String(format: "1ª abertura: tocou no ícone há %.1f s", Date().timeIntervalSince(inicio)), "tempo_icone")
        foto("t04_app_aberto")
        let web = appWeb()
        arvore(web, "t04_app_arvore")
        usarLeitor(web, "t")
        // Fecha de vez e reabre: tem que voltar direto no livro, na mesma página.
        XCUIDevice.shared.press(.home)
        sleep(2)
        if web.state != .notRunning { web.terminate() }
        sleep(2)
        foto("t14b_antes_de_fechar")
        let r0 = Date()
        XCTAssertTrue(abrirPeloIcone(), "reabrir pelo ícone")
        // O app instalado roda no processo com.apple.webapp (visto nos testes anteriores).
        let web2 = XCUIApplication(bundleIdentifier: "com.apple.webapp")
        // Reabre direto no livro: os botões do leitor existem (escondidos) e a estante não aparece.
        // No livro, o rodapé (tempo e porcentagem) aparece; na estante, não.
        let noLivro = achar(web2, ["Trocar informação do rodapé"], espera: 30) != nil && achar(web2, ["Sua estante está vazia"], espera: 1) == nil
        nota(String(format: "reabriu no livro: %@ em %.1f s", noLivro ? "sim" : "não", Date().timeIntervalSince(r0)), "reabertura")
        XCTAssertTrue(noLivro, "reabriu direto no livro")
        sleep(2)
        foto("t15_reaberto")
        arvore(web2, "t15_reaberto_arvore")
    }
}
