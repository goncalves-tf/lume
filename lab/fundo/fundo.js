// Laboratório: qual jeito de tocar áudio continua com o app fora da tela no iPhone (app da Tela de Início)?
// Modo vem do caminho: fundo-elemento, fundo-webaudio, fundo-mse. Mede quanto o áudio avançou fora da tela.
const modo = (location.pathname.match(/fundo-(\w+)/) || [])[1] || 'elemento'
const log = []
const saida = document.getElementById('saida')
const resultado = document.getElementById('resultado')
const escrever = (t) => { log.push(new Date().toTimeString().slice(0, 8) + ' ' + t); saida.textContent = log.slice(-30).join('\n') }
let tempo = () => 0 // quanto áudio já tocou (s)
let saiu = null
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') { saiu = { t: tempo(), quando: Date.now() }; escrever('saiu da tela, tempo ' + saiu.t.toFixed(1)) }
  else if (saiu) {
    const avancou = tempo() - saiu.t
    const fora = (Date.now() - saiu.quando) / 1000
    escrever('voltou, tempo ' + tempo().toFixed(1))
    resultado.textContent = `RESULTADO ${modo}: avançou ${avancou.toFixed(0)} s em ${fora.toFixed(0)} s fora da tela`
  }
})

function tom(seg, freq) {
  const taxa = 22050, n = Math.floor(taxa * seg)
  const buf = new ArrayBuffer(44 + n * 2), v = new DataView(buf)
  const s = (o, t) => { for (let i = 0; i < t.length; i++) v.setUint8(o + i, t.charCodeAt(i)) }
  s(0, 'RIFF'); v.setUint32(4, 36 + n * 2, true); s(8, 'WAVE'); s(12, 'fmt ')
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true)
  v.setUint32(24, taxa, true); v.setUint32(28, taxa * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true)
  s(36, 'data'); v.setUint32(40, n * 2, true)
  for (let i = 0; i < n; i++) v.setInt16(44 + i * 2, Math.sin(2 * Math.PI * freq * i / taxa) * 6000, true)
  return buf
}

async function comecar() {
  try { if (navigator.audioSession) navigator.audioSession.type = 'playback' } catch {}
  if (modo === 'elemento') {
    // Como o Lume faz hoje: um trecho de 3 s por vez, troca o src no fim de cada um.
    const a = new Audio(); a.setAttribute('playsinline', '')
    let tocados = 0, k = 0
    tempo = () => tocados * 3 + (a.currentTime || 0)
    const proximo = () => {
      const url = URL.createObjectURL(new Blob([tom(3, k % 2 ? 330 : 392)], { type: 'audio/wav' })); k++
      a.src = url
      a.play().then(() => escrever('play ok')).catch((e) => escrever('play recusado ' + e.name))
    }
    a.onended = () => { tocados++; proximo() }
    proximo()
  } else if (modo === 'webaudio') {
    // Um contexto de áudio contínuo: os trechos entram na fila sem trocar de fonte.
    const ctx = new AudioContext()
    await ctx.resume()
    let fim = ctx.currentTime + 0.1
    tempo = () => ctx.currentTime
    const agendar = async () => {
      while (fim - ctx.currentTime < 6) {
        const ab = await ctx.decodeAudioData(tom(3, 330))
        const src = ctx.createBufferSource(); src.buffer = ab; src.connect(ctx.destination); src.start(fim); fim += ab.duration
      }
    }
    await agendar()
    setInterval(() => { agendar(); }, 1000)
    setInterval(() => escrever(`ctx ${ctx.state} t=${ctx.currentTime.toFixed(1)}`), 5000)
  } else if (modo === 'mse') {
    // Um único arquivo que cresce enquanto toca (MediaSource): nunca troca de fonte.
    const MS = window.ManagedMediaSource || window.MediaSource
    if (!MS) { escrever('sem MediaSource'); return }
    const a = document.createElement('audio'); a.disableRemotePlayback = true; a.setAttribute('playsinline', ''); document.body.append(a)
    const ms = new MS()
    a.src = URL.createObjectURL(ms)
    tempo = () => a.currentTime
    await new Promise((ok) => ms.addEventListener('sourceopen', ok, { once: true }))
    const sb = ms.addSourceBuffer('audio/mpeg')
    const dados = new Uint8Array(await (await fetch('../fundo/tom.mp3')).arrayBuffer())
    let pos = 0
    const anexar = () => {
      if (sb.updating || pos >= dados.length) return
      const buf = a.buffered.length ? a.buffered.end(0) - a.currentTime : 0
      if (buf > 8) return
      sb.appendBuffer(dados.slice(pos, pos + 24000)); pos += 24000
    }
    sb.addEventListener('updateend', anexar)
    anexar()
    setInterval(anexar, 1000)
    a.play().then(() => escrever('play ok')).catch((e) => escrever('play recusado ' + e.name))
    setInterval(() => escrever(`mse t=${a.currentTime.toFixed(1)} buf=${a.buffered.length ? a.buffered.end(0).toFixed(1) : 0}`), 5000)
  }
  escrever('começou ' + modo)
}
document.getElementById('comecar').addEventListener('click', comecar)
document.getElementById('titulo').textContent = 'Fundo ' + modo
