import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pixelmatching/flutter_pixelmatching.dart';
import 'package:image/image.dart' as img;

// Harness isolato per misurare i tempi di flutter_pixelmatching contro
// un catalogo di copertine di riferimento. Non ha nessun legame con
// RecognitionService: serve solo per il test di valutazione
// prima di decidere se integrarlo per davvero.

// Larghezza massima a cui si riducono le foto prima del confronto:
// le foto della fotocamera sono enormi e rallentano SIFT/KAZE
const int _larghezzaMassima = 640;

// Se true usa una sola istanza di PixelMatching per tutto il
// catalogo (ri-chiamando initialize per ogni libro); se false ne crea
// una nuova per ogni libro come prima. Serve a capire dove va il tempo
// NOTA — il marker nativo è unico e globale: initialize funziona solo se
// prima è stato fatto dispose(), per questo dopo ogni libro si chiama
// dispose() (vedi sotto), qualunque sia il valore di questo flag
const bool _riusaIstanza = false;

// Se true passa al plugin i byte JPEG (Uint8List), se false
// passa l'immagine ridotta come img.Image. Con i byte gli score erano
// tutti 0.000, con img.Image erano tutti 0.925: serve a capire se il
// formato in ingresso cambia il risultato
const bool _usaBytesJpeg = false;

// NUOVO — pausa dopo ogni dispose(): dispose() non si può attendere,
// quindi si lascia il tempo al plugin di liberare il marker nativo
const int _pausaDopoDisposeMs = 100;

// AGGIUNTO ORA — soglia di uscita anticipata: se un libro raggiunge questo
// score (e la foto è nitida) si smette di scorrere il catalogo.
// Con foto reali il libro giusto è uscito a 0.79-0.82; 0.9 non scatterebbe
// quasi mai (solo l'immagine identica fa 1.0). Il caso da evitare è la foto
// sfocata che fa arrivare un libro sbagliato della stessa collana a ~0.76
const double _sogliaEarlyExit = 0.78;

// AGGIUNTO ORA — soglia di nitidezza (varianza del Laplaciano): sotto questo
// valore la foto è considerata sfocata e l'uscita anticipata viene
// disattivata (scansione completa). DA CALIBRARE sul telefono: il valore
// misurato viene stampato nei log e a schermo, confronta una foto nitida
// con una sfocata e sposta la soglia in mezzo
// MODIFICATO 2 — valore alzato da 100.0 a 3500.0. PROVVISORIO e debole:
// misure fatte finora, tutte con foto scattate al monitor tranne una:
// sfocatissima 2551; nitide 4166, 5149, 6071, 8389, 8938, 11990, 12475.
// 3500 sta in mezzo tra la sfocata e la nitida più bassa, ma c'è una sola
// foto sfocata e il valore dipende anche dalla copertina: da ricalibrare
const double _sogliaNitidezza = 3500.0;

// AGGIUNTO ORA — larghezza a cui si riduce la foto per calcolare la nitidezza
// (più piccola = più veloce, il calcolo resta sufficiente)
const int _larghezzaNitidezza = 320;

// NUOVO 2 — distanza minima tra il miglior score e il secondo. Dati delle
// prove: libro giusto con foto nitida 0.136-0.144 (e 0.848-0.944 quando
// gli altri sono tutti 0); foto sfocata col libro giusto 0.064; foto di
// una cosa non in catalogo 0.000 (0.765 contro 0.765). Sotto questa
// distanza il risultato è "incerto" e non si fida
const double _distanzaMinima = 0.10;

class PixelMatchingBenchmark {
  final List<img.Image> copertineCatalogo;

  PixelMatchingBenchmark(this.copertineCatalogo);

  // Riduce l'immagine e la restituisce nel formato scelto
  // da _usaBytesJpeg: byte JPEG oppure img.Image ridotta
  dynamic _preparaImmagine(img.Image originale) {
    final ridotta = originale.width > _larghezzaMassima
        ? img.copyResize(originale, width: _larghezzaMassima)
        : originale;
    // Forza 3 canali (RGB): le copertine scaricate possono avere
    // un canale alfa (trasparenza) che il plugin potrebbe non gestire
    final rgb = ridotta.numChannels == 3 ? ridotta : ridotta.convert(numChannels: 3);
    if (_usaBytesJpeg) {
      return Uint8List.fromList(img.encodeJpg(rgb, quality: 90));
    }
    return rgb;
  }

  // AGGIUNTO ORA — nitidezza della foto come varianza del Laplaciano: più è
  // alto il valore, più la foto è a fuoco. Si calcola su una versione
  // ridotta in scala di grigi, così costa poco rispetto al confronto
  double _calcolaNitidezza(img.Image originale) {
    final ridotta = originale.width > _larghezzaNitidezza
        ? img.copyResize(originale, width: _larghezzaNitidezza)
        : originale.clone();
    final grigia = img.grayscale(ridotta);
    final w = grigia.width;
    final h = grigia.height;

    final lum = List<double>.filled(w * h, 0);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        lum[y * w + x] = grigia.getPixel(x, y).r.toDouble();
      }
    }

    double somma = 0;
    double sommaQuadrati = 0;
    int n = 0;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final laplaciano =
            lum[i - 1] + lum[i + 1] + lum[i - w] + lum[i + w] - 4 * lum[i];
        somma += laplaciano;
        sommaQuadrati += laplaciano * laplaciano;
        n++;
      }
    }
    if (n == 0) return 0;
    final media = somma / n;
    return sommaQuadrati / n - media * media;
  }

  // Confronta la foto scattata con tutto il catalogo, uno per uno, e
  // misura quanto ci vuole in totale, è il numero che decide se
  // l'approccio scala con una biblioteca vera
  // MODIFICATO ORA — due parametri nuovi: usaEarlyExit (uscita anticipata
  // sopra soglia, solo se la foto è nitida) e provaPrimaIndice (indice
  // del libro da confrontare per primo, di solito l'ultimo riconosciuto)
  // NUOVO 3 — terzo parametro: usaControlloNitidezza. Se false la nitidezza
  // si misura e si stampa ma non blocca l'uscita anticipata (serve per
  // provare se bastano la distanza minima e la conferma su due foto)
  Future<Map<String, dynamic>> misura(
    img.Image fotoScattata, {
    bool usaEarlyExit = false,
    int? provaPrimaIndice,
    bool usaControlloNitidezza = true,
  }) async {
    final stopwatchTotale = Stopwatch()..start();
    final tempiSingoli = <int>[];
    // Score di ogni libro, nello stesso ordine del catalogo:
    // serve per vedere quanto stacca il libro giusto dagli altri e per
    // decidere una soglia sotto cui dire "non è un libro"
    // MODIFICATO ORA — lista a lunghezza fissa, -1 = libro non confrontato
    // (uscita anticipata); prima era <double>[] e si faceva add
    final punteggi = List<double>.filled(copertineCatalogo.length, -1.0);
    double miglioreScore = 0;
    int miglioreIndice = -1;
    // Tempo speso in initialize e in similarity, separati
    int tempoInitMs = 0;
    int tempoSimilarityMs = 0;
    // NUOVO — pause dopo dispose, da togliere dal tempo totale
    int pausaTotaleMs = 0;

    // AGGIUNTO ORA — nitidezza della foto scattata, calcolata una volta sola.
    // Si misura sempre (anche con early exit spento) per poterla calibrare
    final swNitidezza = Stopwatch()..start();
    final nitidezza = _calcolaNitidezza(fotoScattata);
    swNitidezza.stop();
    final nitida = nitidezza >= _sogliaNitidezza;
    debugPrint(
      '[PM] nitidezza foto: ${nitidezza.toStringAsFixed(1)} '
      '(soglia $_sogliaNitidezza) -> ${nitida ? 'nitida' : 'SFOCATA'} '
      '[${swNitidezza.elapsedMilliseconds} ms]',
    );
    // L'uscita anticipata è consentita solo con foto nitida
    // MODIFICATO 3 — con il controllo nitidezza spento la foto sfocata non
    // blocca l'uscita anticipata (prima era: usaEarlyExit && nitida)
    final earlyExitAttivo = usaEarlyExit && (nitida || !usaControlloNitidezza);
    if (usaEarlyExit && !nitida && usaControlloNitidezza) {
      debugPrint('[PM] foto sfocata: uscita anticipata disattivata, scansione completa');
    }
    // NUOVO 3 — avviso quando il controllo è spento e la foto risulterebbe sfocata
    if (usaEarlyExit && !nitida && !usaControlloNitidezza) {
      debugPrint('[PM] foto sfocata ma controllo nitidezza spento: uscita anticipata attiva');
    }

    // AGGIUNTO ORA — ordine dei candidati: prima il libro indicato (ultimo
    // riconosciuto), poi tutti gli altri nell'ordine del catalogo
    final ordine = <int>[];
    if (provaPrimaIndice != null &&
        provaPrimaIndice >= 0 &&
        provaPrimaIndice < copertineCatalogo.length) {
      ordine.add(provaPrimaIndice);
    }
    for (int i = 0; i < copertineCatalogo.length; i++) {
      if (i != provaPrimaIndice) ordine.add(i);
    }
    bool uscitaAnticipata = false;

    // La preparazione (resize) della foto scattata si fa una volta sola
    final fotoPronta = _preparaImmagine(fotoScattata);
    PixelMatching? matchingCondiviso = _riusaIstanza ? PixelMatching() : null;

    // MODIFICATO ORA — si scorre 'ordine' invece di 0..N (prima:
    // for (int i = 0; i < copertineCatalogo.length; i++)): 'i' resta
    // l'indice del libro nel catalogo, quindi log e score sono gli stessi
    for (final i in ordine) {
      final sw = Stopwatch()..start();

      final matching = matchingCondiviso ?? PixelMatching();
      double score = 0;

      try {
        final swInit = Stopwatch()..start();
        // initialize ritorna un bool: lo leggiamo e lo stampiamo,
        // se è false il riferimento non è stato caricato
        final initOk = await matching.initialize(
          image: _preparaImmagine(copertineCatalogo[i]),
        );
        swInit.stop();
        tempoInitMs += swInit.elapsedMilliseconds;
        debugPrint('[PM] libro #${i + 1}: initialize -> $initOk');

        // NOTA — similarity() ritorna Future<double> non nullable (verificato
        // nel codice del plugin), quindi niente "?? 0" qui: sarebbe dead code
        final swSim = Stopwatch()..start();
        score = await matching.similarity(fotoPronta);
        swSim.stop();
        tempoSimilarityMs += swSim.elapsedMilliseconds;
        debugPrint('[PM] libro #${i + 1}: similarity -> $score');
      } finally {
        // NUOVO — libera il marker nativo, altrimenti il libro
        // successivo non può fare initialize (ritornerebbe false)
        matching.dispose();
      }

      sw.stop();
      tempiSingoli.add(sw.elapsedMilliseconds);
      // MODIFICATO ORA — si scrive nella posizione del libro (prima:
      // punteggi.add(score)), perché l'ordine di confronto non è più
      // quello del catalogo
      punteggi[i] = score;

      // NUOVO 2 — miglior score tra i libri confrontati PRIMA di questo:
      // serve per la distanza minima nell'uscita anticipata
      final miglioreAnteriore = miglioreScore;

      if (score > miglioreScore) {
        miglioreScore = score;
        miglioreIndice = i;
      }

      // AGGIUNTO ORA — uscita anticipata: foto nitida e score sopra soglia,
      // non serve confrontare gli altri libri (niente pausa, non c'è
      // un libro successivo che deve fare initialize)
      // MODIFICATO 2 — in più, lo score deve staccare di almeno
      // _distanzaMinima dal miglior score già visto; se non stacca si
      // continua la scansione (esempio: foto sfocata con libri sbagliati
      // a 0.772 e 0.773 prima del libro giusto a 0.836)
      if (earlyExitAttivo &&
          score >= _sogliaEarlyExit &&
          score - miglioreAnteriore < _distanzaMinima) {
        debugPrint(
          '[PM] libro #${i + 1} score $score sopra soglia ma distanza dal '
          'migliore precedente ${(score - miglioreAnteriore).toStringAsFixed(3)} '
          '< $_distanzaMinima: si continua la scansione',
        );
      }
      if (earlyExitAttivo &&
          score >= _sogliaEarlyExit &&
          score - miglioreAnteriore >= _distanzaMinima) {
        uscitaAnticipata = true;
        debugPrint(
          '[PM] uscita anticipata: libro #${i + 1} score $score >= '
          '$_sogliaEarlyExit dopo ${tempiSingoli.length} confronti '
          'su ${copertineCatalogo.length}',
        );
        break;
      }

      // NUOVO — pausa per dare tempo al dispose di completarsi
      await Future.delayed(const Duration(milliseconds: _pausaDopoDisposeMs));
      pausaTotaleMs += _pausaDopoDisposeMs;
    }

    stopwatchTotale.stop();

    // NUOVO 2 — esito del riconoscimento:
    // 'non riconosciuto' = miglior score sotto soglia
    // 'da confermare'    = uscita anticipata, serve una seconda foto
    // 'riconosciuto'     = scansione completa, score sopra soglia e
    //                      distanza dal secondo almeno _distanzaMinima
    // 'incerto'          = scansione completa, score sopra soglia ma
    //                      distanza dal secondo troppo piccola
    String esito;
    if (miglioreScore < _sogliaEarlyExit) {
      esito = 'non riconosciuto';
    } else if (uscitaAnticipata) {
      esito = 'da confermare';
    } else {
      final valori = punteggi.where((p) => p >= 0).toList()
        ..sort((a, b) => b.compareTo(a));
      final secondo = valori.length > 1 ? valori[1] : 0.0;
      esito = (valori[0] - secondo) >= _distanzaMinima ? 'riconosciuto' : 'incerto';
    }
    debugPrint('[PM] esito: $esito');

    return {
      'numeroLibri': copertineCatalogo.length,
      // MODIFICATO — il tempo totale non conta le pause dopo dispose
      'tempoTotaleMs': stopwatchTotale.elapsedMilliseconds - pausaTotaleMs,
      'tempoMedioMs': tempiSingoli.reduce((a, b) => a + b) / tempiSingoli.length,
      'migliorMatch': miglioreIndice,
      'miglioreScore': miglioreScore,
      'punteggi': punteggi,
      'tempoInitMs': tempoInitMs,
      'tempoSimilarityMs': tempoSimilarityMs,
      // AGGIUNTO ORA — dati per capire cosa ha fatto l'ottimizzazione
      'libriConfrontati': tempiSingoli.length,
      'uscitaAnticipata': uscitaAnticipata,
      'nitidezza': nitidezza,
      'nitida': nitida,
      'tempoNitidezzaMs': swNitidezza.elapsedMilliseconds,
      // true se il miglior score supera la soglia: la vista lo usa per
      // ricordare l'ultimo libro riconosciuto
      'riconosciuto': miglioreScore >= _sogliaEarlyExit,
      // NUOVO 2 — vedi sopra: non riconosciuto / da confermare /
      // riconosciuto / incerto
      'esito': esito,
    };
  }
}