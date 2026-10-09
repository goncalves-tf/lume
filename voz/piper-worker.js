// Voz natural Piper rodando no próprio aparelho (Web Worker): texto -> fonemas (espeak-ng) -> áudio (ONNX).
// Os arquivos são baixados uma vez e guardados no aparelho (Cache Storage "lume-voz-v1").
// Mensagens recebidas:
//   {tipo:'iniciar', base, voz}          -> {tipo:'progresso', parte, feito, total} ... {tipo:'pronto'}
//   {tipo:'falar', id, texto}            -> {tipo:'audio', id, wav, duracao, ms}
//   {tipo:'limpar'}                      -> descarta pedidos de 'falar' que ainda não começaram ({tipo:'descartado', id})
// Erros: {tipo:'erro', id?, erro}
/* global ort, createPiperPhonemize */
let sessao = null
let config = null
let fonemizador = null
let saidaFonemas = null
const fila = []
let ocupado = false

// Memória do motor (para o relatório de problemas): guarda as memórias WebAssembly criadas aqui.
const memorias = []
const guardarMemoria = (r) => {
  const inst = (r && r.instance) || r
  const m = inst && inst.exports && Object.values(inst.exports).find((x) => x instanceof WebAssembly.Memory)
  if (m && !memorias.includes(m)) memorias.push(m)
  return r
}
for (const nome of ['instantiate', 'instantiateStreaming']) {
  const orig = WebAssembly[nome]
  if (orig) WebAssembly[nome] = function (...a) { return orig.apply(this, a).then(guardarMemoria) }
}
const memoriaMB = () => Math.round(memorias.reduce((t, m) => t + m.buffer.byteLength, 0) / 1048576)

async function baixar(url, aoProgresso) {
  let cache = null
  try { cache = await caches.open('lume-voz-v1') } catch { cache = null }
  const ja = cache && (await cache.match(url))
  if (ja) return await ja.arrayBuffer()
  const r = await fetch(url)
  if (!r.ok) throw new Error('download ' + r.status)
  const total = Number(r.headers.get('content-length')) || 0
  const leitor = r.body.getReader()
  const partes = []
  let feito = 0
  let ultimo = 0
  for (;;) {
    const { done, value } = await leitor.read()
    if (done) break
    partes.push(value)
    feito += value.length
    if (aoProgresso && feito - ultimo > 512 * 1024) { ultimo = feito; aoProgresso(feito, total) }
  }
  const buf = new Uint8Array(feito)
  let o = 0
  for (const p of partes) { buf.set(p, o); o += p.length }
  if (cache) { try { await cache.put(url, new Response(buf.slice().buffer, { headers: { 'content-type': 'application/octet-stream' } })) } catch { /* sem espaço */ } }
  return buf.buffer
}

async function iniciar(msg) {
  const base = msg.base
  importScripts(base + 'ort.wasm.min.js')
  ort.env.wasm.numThreads = 1
  ort.env.wasm.proxy = false
  importScripts(base + 'piper_phonemize.js')
  const urlModelo = base + msg.voz + '.onnx'
  config = JSON.parse(new TextDecoder().decode(await baixar(urlModelo + '.json')))
  // Tamanhos para a barra de progresso: idioma (18 MB) + motor (10 MB) + voz (63 MB).
  let dadosEspeak = await baixar(base + 'piper_phonemize.data', (f, t) => postMessage({ tipo: 'progresso', parte: 'idioma', feito: f, total: t }))
  // Os binários vão direto da cópia guardada (funciona sem internet depois da 1ª vez).
  let binOrt = await baixar(base + 'ort-wasm-simd.wasm', (f, t) => postMessage({ tipo: 'progresso', parte: 'motor', feito: f, total: t }))
  const urlOrt = URL.createObjectURL(new Blob([binOrt], { type: 'application/wasm' }))
  binOrt = null
  ort.env.wasm.wasmPaths = { 'ort-wasm-simd.wasm': urlOrt }
  let wasmFonemas = await baixar(base + 'piper_phonemize.wasm')
  fonemizador = await createPiperPhonemize({
    wasmBinary: wasmFonemas,
    print: (txt) => { saidaFonemas?.(txt) },
    printErr: (txt) => console.warn('fonemas', txt),
    locateFile: (u) => (u.endsWith('.wasm') ? base + 'piper_phonemize.wasm' : u.endsWith('.data') ? base + 'piper_phonemize.data' : u),
    getPreloadedPackage: (nome) => (nome.endsWith('.data') ? dadosEspeak : null),
  })
  // Já copiados para dentro do fonemizador: solta as cópias (memória conta no limite do iPhone).
  dadosEspeak = null
  wasmFonemas = null
  let modelo = await baixar(urlModelo, (f, t) => postMessage({ tipo: 'progresso', parte: 'voz', feito: f, total: t }))
  // Sem "arena" e sem "padrões de memória": cada trecho tem um tamanho diferente, e com eles ligados o motor
  // guarda um bloco novo de memória para cada tamanho (a memória só cresce até o iPhone fechar o app).
  const economia = msg.economia !== false
  const opcoes = { executionProviders: ['wasm'], graphOptimizationLevel: msg.otimizacao || 'all', enableCpuMemArena: !economia, enableMemPattern: !economia }
  if (msg.semPrepack === true) opcoes.extra = { session: { disable_prepacking: '1' } }
  sessao = await ort.InferenceSession.create(modelo, opcoes)
  modelo = null
  URL.revokeObjectURL(urlOrt)
  postMessage({ tipo: 'pronto' })
}

function fonemas(texto) {
  return new Promise((ok, erro) => {
    saidaFonemas = (txt) => {
      saidaFonemas = null
      try { ok(JSON.parse(txt).phoneme_ids) } catch (e) { erro(e) }
    }
    try {
      fonemizador.callMain(['-l', config.espeak.voice, '--input', JSON.stringify([{ text: texto }]), '--espeak_data', '/espeak-ng-data'])
    } catch (e) {
      saidaFonemas = null
      erro(e)
    }
  })
}

function wav(pcm, taxa) {
  const n = pcm.length
  const buf = new ArrayBuffer(44 + n * 2)
  const v = new DataView(buf)
  const s = (o, t) => { for (let i = 0; i < t.length; i++) v.setUint8(o + i, t.charCodeAt(i)) }
  s(0, 'RIFF'); v.setUint32(4, 36 + n * 2, true); s(8, 'WAVE'); s(12, 'fmt ')
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true)
  v.setUint32(24, taxa, true); v.setUint32(28, taxa * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true)
  s(36, 'data'); v.setUint32(40, n * 2, true)
  // Volume uniforme entre os trechos.
  let pico = 0
  for (let i = 0; i < n; i++) { const a = Math.abs(pcm[i]); if (a > pico) pico = a }
  const ganho = pico > 0 ? Math.min(0.92 / pico, 4) : 1
  for (let i = 0; i < n; i++) v.setInt16(44 + i * 2, Math.max(-1, Math.min(1, pcm[i] * ganho)) * 32767, true)
  return buf
}

async function falar(msg) {
  const t0 = performance.now()
  const ids = await fonemas(msg.texto)
  const inf = config.inference
  const feeds = {
    input: new ort.Tensor('int64', BigInt64Array.from(ids.map(BigInt)), [1, ids.length]),
    input_lengths: new ort.Tensor('int64', BigInt64Array.from([BigInt(ids.length)])),
    // Velocidade pela própria voz (mais devagar ou mais rápido sem mudar o tom).
    scales: new ort.Tensor('float32', Float32Array.from([inf.noise_scale, inf.length_scale / Math.max(0.5, Math.min(2.5, msg.velocidade || 1)), inf.noise_w])),
  }
  if (config.num_speakers > 1) feeds.sid = new ort.Tensor('int64', BigInt64Array.from([0n]))
  const { output } = await sessao.run(feeds)
  const taxa = config.audio.sample_rate
  const { pesos, inicioVoz, fimVoz } = sincronia(ids, output.data, taxa)
  const dados = wav(output.data, taxa)
  postMessage({ tipo: 'audio', id: msg.id, wav: dados, duracao: output.data.length / taxa, ms: performance.now() - t0, memMB: memoriaMB(), pesos, inicioVoz, fimVoz }, [dados])
}

// Para o destaque acompanhar a voz: quantos sons tem cada palavra (pausas de pontuação pesam mais) e onde a
// fala começa e termina de verdade no áudio (sem o silêncio das pontas).
function sincronia(ids, pcm, taxa) {
  const mapa = config.phoneme_id_map
  const id = (c) => (mapa[c] ? mapa[c][0] : -1)
  const ignorar = new Set([id('_'), id('^'), id('$')])
  const espaco = id(' ')
  const pausaForte = new Set(['.', '!', '?', ';', ':'].map(id))
  const pausaFraca = new Set([',', '"'].map(id))
  const pesos = []
  let atual = 0
  for (const x of ids) {
    if (ignorar.has(x)) continue
    if (x === espaco) { if (atual > 0) pesos.push(atual); atual = 0; continue }
    atual += pausaForte.has(x) ? 5 : pausaFraca.has(x) ? 2.5 : 1
  }
  if (atual > 0) pesos.push(atual)
  let pico = 0
  for (let i = 0; i < pcm.length; i++) { const a = Math.abs(pcm[i]); if (a > pico) pico = a }
  const limiar = pico * 0.06
  let a = 0
  while (a < pcm.length && Math.abs(pcm[a]) < limiar) a++
  let b = pcm.length - 1
  while (b > a && Math.abs(pcm[b]) < limiar) b--
  return { pesos, inicioVoz: a / taxa, fimVoz: (b + 1) / taxa }
}

async function andar() {
  if (ocupado) return
  ocupado = true
  while (fila.length) {
    // Deixa as mensagens novas chegarem entre um trecho e outro (senão o pedido "passa na frente" só era
    // atendido depois de gerar a fila inteira de trechos adiantados).
    await new Promise((ok) => setTimeout(ok, 0))
    if (!fila.length) break
    const m = fila.shift()
    try {
      if (m.tipo === 'iniciar') await iniciar(m)
      else if (m.tipo === 'falar') await falar(m)
    } catch (err) {
      postMessage({ tipo: 'erro', id: m.id, erro: String((err && err.message) || err) })
    }
  }
  ocupado = false
}

onmessage = (e) => {
  const m = e.data
  if (m.tipo === 'limpar') {
    for (let i = fila.length - 1; i >= 0; i--) {
      if (fila[i].tipo === 'falar') postMessage({ tipo: 'descartado', id: fila.splice(i, 1)[0].id })
    }
    return
  }
  fila.push(m)
  andar()
}
