import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/tflite_benchmark.dart';

// Vista di TEST per il modello TFLite a classi (stesso schema della vista
// del pixel matching): si scelgono una o più foto, per ognuna si stampano
// libro scelto, confidenza, primi tre candidati e tempi, sia a schermo che
// nel terminale con il prefisso [ML].
class TfliteTestView extends StatefulWidget {
  const TfliteTestView({super.key});

  @override
  State<TfliteTestView> createState() => _TfliteTestViewState();
}

class _TfliteTestViewState extends State<TfliteTestView> {
  final ImagePicker _picker = ImagePicker();
  final TfliteBenchmark _benchmark = TfliteBenchmark();

  bool _occupato = true;
  String? _errore;
  String _risultato = '';

  // Interruttori per confrontare come l'app prepara l'immagine rispetto al
  // training, senza ricompilare
  bool _normalizzaMenoUnoUno = true;
  bool _interpolazioneLineare = true;
  bool _applicaExif = true;

  @override
  void initState() {
    super.initState();
    _caricaModello();
  }

  Future<void> _caricaModello() async {
    try {
      await _benchmark.carica();
    } catch (e) {
      _errore = 'Errore caricamento modello: $e';
      debugPrint('[ML] $_errore');
    }
    if (!mounted) return;
    setState(() => _occupato = false);
  }

  @override
  void dispose() {
    _benchmark.dispose();
    super.dispose();
  }

  // Testo di una singola foto, usato identico a schermo e nel terminale
  String _formattaFoto(String nome, Map<String, dynamic> r) {
    final classifica = r['classifica'] as List<Map<String, dynamic>>;
    final righe = StringBuffer();
    righe.writeln('Foto: $nome (${r['larghezza']}x${r['altezza']})');
    righe.writeln(
      'Preparazione: ${r['tempoPreparazioneMs']} ms, '
      'inferenza: ${r['tempoInferenzaMs']} ms'
      '${(r['primaInferenza'] as bool) ? ' (prima inferenza, include il riscaldamento)' : ''}',
    );
    for (int k = 0; k < classifica.length; k++) {
      righe.writeln(
        '#${k + 1}: ${classifica[k]['nome']} '
        '${(classifica[k]['score'] as double).toStringAsFixed(3)}',
      );
    }
    final String esito;
    if (r['isNone'] as bool) {
      esito = 'classe None: non è un libro del catalogo';
    } else if (r['affidabile'] as bool) {
      esito =
          'AFFIDABILE (>= ${TfliteBenchmark.sogliaAffidabile.toStringAsFixed(2)}): '
          '${r['nomeMigliore']}';
    } else {
      esito =
          'SCARTATA (sotto la soglia ${TfliteBenchmark.sogliaAffidabile.toStringAsFixed(2)})';
    }
    righe.write('Esito: $esito');
    return righe.toString();
  }

  Future<void> _elabora(List<XFile> files, String sorgente) async {
    if (files.isEmpty) return;

    setState(() => _occupato = true);

    final testo = StringBuffer();
    int affidabili = 0;
    int scartate = 0;
    int none = 0;
    int errori = 0;
    int sommaInferenzaMs = 0;
    int contate = 0;

    final intestazione =
        '[ML] ===== RISULTATO (foto da: $sorgente, '
        'normalizzazione: ${_normalizzaMenoUnoUno ? '-1..1' : '0..1'}, '
        'interpolazione: ${_interpolazioneLineare ? 'lineare' : 'nearest'}, '
        'exif: $_applicaExif) =====';
    debugPrint(intestazione);

    for (final f in files) {
      String blocco;
      try {
        final bytes = await f.readAsBytes();
        final r = await _benchmark.riconosci(
          bytes,
          normalizzaMenoUnoUno: _normalizzaMenoUnoUno,
          interpolazioneLineare: _interpolazioneLineare,
          applicaOrientamentoExif: _applicaExif,
        );
        blocco = _formattaFoto(f.name, r);
        if (r['isNone'] as bool) {
          none++;
        } else if (r['affidabile'] as bool) {
          affidabili++;
        } else {
          scartate++;
        }
        // La prima inferenza include il riscaldamento: non entra nella media
        if (!(r['primaInferenza'] as bool)) {
          sommaInferenzaMs += r['tempoInferenzaMs'] as int;
          contate++;
        }
      } catch (e) {
        errori++;
        blocco = 'Foto: ${f.name}\nErrore: $e';
      }

      testo.writeln(blocco);
      testo.writeln();
      for (final riga in blocco.split('\n')) {
        debugPrint('[ML] $riga');
      }
      debugPrint('[ML] -----');
    }

    final riepilogo =
        'Riepilogo: ${files.length} foto, $affidabili affidabili, '
        '$scartate scartate, $none None, $errori errori'
        '${contate > 0 ? ', inferenza media ${(sommaInferenzaMs / contate).toStringAsFixed(1)} ms' : ''}';
    testo.writeln(riepilogo);
    debugPrint('[ML] $riepilogo');
    debugPrint('[ML] ===== FINE RISULTATO =====');

    if (!mounted) return;
    setState(() {
      _occupato = false;
      _risultato = testo.toString();
    });
  }

  Future<void> _dallaGalleria() async {
    final files = await _picker.pickMultiImage();
    await _elabora(files, 'galleria');
  }

  Future<void> _dallaFotocamera() async {
    final foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;
    await _elabora([foto], 'camera');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test modello TFLite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _errore ??
                  'Modello: ${_benchmark.numUscite} classi, '
                      '${_benchmark.numLabels} labels',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Normalizzazione -1..1 (come il training)'),
              subtitle: const Text('Spento = 0..1, come fa ora l\'app'),
              value: _normalizzaMenoUnoUno,
              onChanged: _occupato
                  ? null
                  : (v) => setState(() => _normalizzaMenoUnoUno = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Ridimensionamento lineare'),
              subtitle: const Text('Spento = nearest, il default attuale'),
              value: _interpolazioneLineare,
              onChanged: _occupato
                  ? null
                  : (v) => setState(() => _interpolazioneLineare = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Applica orientamento EXIF'),
              subtitle: const Text('Spento = la foto può restare ruotata'),
              value: _applicaExif,
              onChanged: _occupato
                  ? null
                  : (v) => setState(() => _applicaExif = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_occupato || _errore != null) ? null : _dallaGalleria,
              child: const Text('Scegli foto dalla galleria (anche più di una)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  (_occupato || _errore != null) ? null : _dallaFotocamera,
              child: const Text('Scatta una foto'),
            ),
            const SizedBox(height: 16),
            if (_occupato) const CircularProgressIndicator(),
            if (_risultato.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_risultato, style: const TextStyle(fontSize: 15)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}