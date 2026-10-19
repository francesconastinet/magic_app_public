import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../services/pixel_matching_benchmark.dart';

class PixelMatchingTestView extends StatefulWidget {
  const PixelMatchingTestView({super.key});

  @override
  State<PixelMatchingTestView> createState() => _PixelMatchingTestViewState();
}

class _PixelMatchingTestViewState extends State<PixelMatchingTestView> {
  final ImagePicker _picker = ImagePicker();

  // Catalogo di copertine di riferimento caricate per il test
  final List<img.Image> _catalogo = [];
  bool _caricando = false;
  String? _risultato;

  // AGGIUNTO ORA — interruttori per confrontare i tempi con e senza
  // ottimizzazione senza ricompilare: uscita anticipata (soglia + nitidezza)
  // e ordine dei candidati (ultimo libro riconosciuto per primo)
  bool _usaEarlyExit = true;
  bool _provaPrimaUltimo = true;
  // NUOVO 3 — terzo interruttore: se spento la nitidezza della foto non
  // blocca l'uscita anticipata (si misura e si stampa lo stesso)
  bool _usaControlloNitidezza = true;
  // AGGIUNTO ORA — indice (nel catalogo) dell'ultimo libro riconosciuto
  int? _ultimoIndice;
  // NUOVO 2 — libro candidato in attesa di conferma sulla foto successiva
  // (uscita anticipata con un solo libro sopra soglia)
  int? _candidato;

  // Aggiunge foto al catalogo di test (anche scattate al volo, non
  // serve che siano vere copertine: serve solo misurare la velocità)
  Future<void> _aggiungiAlCatalogo() async {
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;

    setState(() => _caricando = true);
    for (final f in files) {
      final bytes = await File(f.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) _catalogo.add(decoded);
    }
    setState(() => _caricando = false);
  }

  void _svuotaCatalogo() {
    // MODIFICATO ORA — azzera anche l'ultimo libro riconosciuto: gli indici
    // non valgono più con un catalogo nuovo (prima era solo:
    // setState(() => _catalogo.clear());)
    setState(() {
      _catalogo.clear();
      _ultimoIndice = null;
      _candidato = null; // NUOVO 2
    });
  }

  // Scatta/scegli la foto "da riconoscere" e la confronta con tutto
  // il catalogo, misurando i tempi tramite il benchmark
  // MODIFICATO — la sorgente della foto è ora un parametro: fotocamera
  // (come prima) oppure galleria, per il test con la stessa identica
  // immagine del catalogo
  Future<void> _misuraRiconoscimento({
    ImageSource sorgente = ImageSource.camera,
  }) async {
    if (_catalogo.isEmpty) {
      setState(() => _risultato = 'Carica prima almeno una foto nel catalogo.');
      return;
    }

    final foto = await _picker.pickImage(source: sorgente);
    if (foto == null) return;

    setState(() {
      _caricando = true;
      _risultato = null;
    });

    final bytes = await File(foto.path).readAsBytes();
    final fotoScattata = img.decodeImage(bytes)!;

    final benchmark = PixelMatchingBenchmark(_catalogo);
    // MODIFICATO ORA — passa al benchmark i due parametri scelti con gli
    // switch (prima: benchmark.misura(fotoScattata))
    final risultato = await benchmark.misura(
      fotoScattata,
      usaEarlyExit: _usaEarlyExit,
      provaPrimaIndice: _provaPrimaUltimo ? _ultimoIndice : null,
      usaControlloNitidezza: _usaControlloNitidezza, // NUOVO 3
    );

    // AGGIUNTO ORA — ricorda l'ultimo libro riconosciuto per il test successivo
    if (risultato['riconosciuto'] as bool) {
      _ultimoIndice = risultato['migliorMatch'] as int;
    }

    // Elenco degli score di tutti i libri, nell'ordine del catalogo
    final punteggi = risultato['punteggi'] as List<double>;
    final elencoPunteggi = StringBuffer();
    for (int i = 0; i < punteggi.length; i++) {
      // MODIFICATO ORA — score negativo = libro non confrontato (uscita
      // anticipata); prima era:
      // elencoPunteggi.writeln('Libro #${i + 1}: ${punteggi[i].toStringAsFixed(3)}');
      final valore =
          punteggi[i] < 0 ? 'saltato' : punteggi[i].toStringAsFixed(3);
      elencoPunteggi.writeln('Libro #${i + 1}: $valore');
    }

    // Distanza tra il miglior score e il secondo: se è grande il
    // riconoscimento è netto, se è piccola il risultato è poco affidabile
    // MODIFICATO ORA — si considerano solo i libri effettivamente confrontati
    String distanzaTraPrimiDue = '';
    final confrontati = punteggi.where((p) => p >= 0).toList();
    if (confrontati.length > 1) {
      final ordinati = List<double>.from(confrontati)..sort((a, b) => b.compareTo(a));
      distanzaTraPrimiDue =
          '\nDistanza 1º-2º: ${(ordinati[0] - ordinati[1]).toStringAsFixed(3)}';
    }

    // NUOVO 2 — conferma su due foto di fila. 'da confermare' = un solo libro
    // sopra soglia (uscita anticipata): è confermato se è lo stesso libro
    // candidato dalla foto precedente. 'riconosciuto' = scansione completa
    // con distanza sufficiente: già sicuro. Altrimenti si azzera il candidato
    final esito = risultato['esito'] as String;
    final migliore = risultato['migliorMatch'] as int;
    String conferma;
    if (esito == 'riconosciuto') {
      conferma = 'libro #${migliore + 1} sicuro (distanza sufficiente su tutta la scansione)';
      _candidato = migliore;
    } else if (esito == 'da confermare') {
      if (_candidato == migliore) {
        conferma = 'CONFERMATO libro #${migliore + 1} (stesso libro su due foto di fila)';
      } else {
        conferma = 'in attesa: scatta una seconda foto per confermare il libro #${migliore + 1}';
        _candidato = migliore;
      }
    } else if (esito == 'incerto') {
      conferma = 'incerto: ripeti la foto';
      _candidato = null;
    } else {
      conferma = 'nessun libro riconosciuto';
      _candidato = null;
    }

    // MODIFICATO ORA — il testo del risultato ora si costruisce prima in una
    // variabile, così lo stesso identico testo va sia a schermo che nel
    // terminale (prima era scritto direttamente dentro setState)
    // Aggiunti tempo di initialize e tempo di similarity
    // AGGIUNTO ORA — righe su libri confrontati, uscita anticipata e nitidezza
    final testoRisultato =
        'Libri nel catalogo: ${risultato['numeroLibri']}\n'
        'Libri confrontati: ${risultato['libriConfrontati']}\n'
        'Uscita anticipata: ${(risultato['uscitaAnticipata'] as bool) ? 'sì' : 'no'}\n'
        'Nitidezza foto: ${(risultato['nitidezza'] as double).toStringAsFixed(1)} '
        '(${(risultato['nitida'] as bool) ? 'nitida' : 'sfocata'}, '
        '${risultato['tempoNitidezzaMs']} ms)\n'
        'Tempo totale: ${risultato['tempoTotaleMs']} ms\n'
        'Tempo medio per libro: ${(risultato['tempoMedioMs'] as double).toStringAsFixed(1)} ms\n'
        'Tempo in initialize: ${risultato['tempoInitMs']} ms\n'
        'Tempo in similarity: ${risultato['tempoSimilarityMs']} ms\n'
        // MODIFICATO 4 — se nessun libro ha un match l'indice è -1: si scrive
        // "nessuno" invece di "libro #0" (prima era:
        // 'Miglior match: libro #${(risultato['migliorMatch'] as int) + 1} (score ${(risultato['miglioreScore'] as double).toStringAsFixed(3)})'
        // )
        'Miglior match: ${(risultato['migliorMatch'] as int) < 0 ? 'nessuno' : 'libro #${(risultato['migliorMatch'] as int) + 1} (score ${(risultato['miglioreScore'] as double).toStringAsFixed(3)})'}'
        '$distanzaTraPrimiDue\n'
        // NUOVO 2 — esito e conferma
        'Esito: $esito\n'
        'Conferma: $conferma\n\n'
        'Score di tutti i libri:\n$elencoPunteggi';

    // AGGIUNTO ORA — stampa del riepilogo nel terminale, una riga per volta
    // con il prefisso [PM] (così si può anche filtrare e copiare facilmente).
    // Sorgente: camera o galleria, e stato dei due switch, utili per
    // ricordare che test era
    debugPrint(
      '[PM] ===== RISULTATO (foto da: ${sorgente.name}, '
      'earlyExit: $_usaEarlyExit, ultimoPrimo: $_provaPrimaUltimo, '
      'controlloNitidezza: $_usaControlloNitidezza) =====', // MODIFICATO 3
    );
    for (final riga in testoRisultato.split('\n')) {
      if (riga.trim().isEmpty) continue;
      debugPrint('[PM] $riga');
    }
    debugPrint('[PM] ===== FINE RISULTATO =====');

    setState(() {
      _caricando = false;
      _risultato = testoRisultato;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test pixel matching')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Copertine nel catalogo: ${_catalogo.length}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _caricando ? null : _aggiungiAlCatalogo,
              child: const Text('Aggiungi copertine al catalogo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _caricando ? null : _svuotaCatalogo,
              child: const Text('Svuota catalogo'),
            ),
            // AGGIUNTO ORA — switch per le due ottimizzazioni
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Uscita anticipata (soglia + nitidezza)'),
              value: _usaEarlyExit,
              onChanged: _caricando
                  ? null
                  : (v) => setState(() => _usaEarlyExit = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Ultimo libro riconosciuto per primo'),
              value: _provaPrimaUltimo,
              onChanged: _caricando
                  ? null
                  : (v) => setState(() => _provaPrimaUltimo = v),
            ),
            // NUOVO 3 — terzo switch: controllo di nitidezza
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Controllo nitidezza (blocca se sfocata)'),
              value: _usaControlloNitidezza,
              onChanged: _caricando
                  ? null
                  : (v) => setState(() => _usaControlloNitidezza = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _caricando ? null : () => _misuraRiconoscimento(),
              child: const Text('Scatta e misura riconoscimento'),
            ),
            // NUOVO — test di controllo: sceglie la foto da riconoscere
            // dalla galleria, così si può usare la stessa identica
            // immagine messa nel catalogo (lo score deve essere alto)
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _caricando
                  ? null
                  : () => _misuraRiconoscimento(sorgente: ImageSource.gallery),
              child: const Text('Misura con foto dalla galleria'),
            ),
            const SizedBox(height: 24),
            if (_caricando) const CircularProgressIndicator(),
            // Il risultato è in un'area scorrevole, perché con 20 o 50
            // libri l'elenco degli score è lungo
            if (_risultato != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_risultato!, style: const TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}