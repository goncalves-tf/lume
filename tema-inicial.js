// Pinta o fundo do tema salvo antes de tudo carregar: abre sem piscar branco à noite.
;(function () {
  try {
    var a = JSON.parse(localStorage.getItem('lume:ajustes') || '{}')
    var T = { papel: '#fbfaf7', sepia: '#f5ecda', areia: '#e7e2d6', noite: '#1b1a18', preto: '#000000' }
    var escuro = matchMedia('(prefers-color-scheme: dark)').matches
    var auto = a.temaAuto !== false
    var id = auto ? (escuro ? a.temaEscuro || 'noite' : a.temaClaro || 'papel') : a.tema || 'papel'
    var cor = T[id] || T.papel
    document.documentElement.style.backgroundColor = cor
    document.querySelector('meta[name=theme-color]').content = cor
  } catch (e) {}
})()
