import Foundation

// MARK: - /api/v1/tools/large_scale

/// Large-scale situation: Großwetterlage of the DWD, ensemble regimes, polar vortex, AO and NAO.
struct LargeScaleResponse: Decodable {
    struct Gwl: Decodable {
        let code: String?
        let name: String?
        let grosswettertyp: String?
        let zirkulationsform: String?
        let zyklonal: Bool?
        let zusatz: String?
        let bericht: String?
        let ausgegebenLokal: String?
        @Lenient var alterH: Double?
    }

    struct Cluster: Decodable {
        let zeitraum: String?
        @Lenient var cluster: Int?
        let regimeGenannt: [String]?
    }

    struct Consistency: Decodable {
        let zeitraum: String?
        let aussage: String?
    }

    struct Regime: Decodable {
        let bericht: String?
        let ausgegebenLokal: String?
        let schlagzeile: String?
        let genannteRegime: [String]?
        let bedeutung: [String: String]?
        let cluster: [Cluster]?
        let clusteranalyse: String?
        let grosswetterlageEnsemble: String?
        let konsistenz: [Consistency]?
    }

    struct VortexNow: Decodable {
        let zeit: String?
        @Lenient var u10Ms: Double?
    }

    struct VortexTrend: Decodable {
        @Lenient var aenderungU10Ms: Double?
        let einordnung: String?
    }

    struct Reversal: Decodable {
        let erwartet: Bool?
        let bereitsOst: Bool?
        let ersterTag: String?
        @Lenient var tageMitOst: Int?
        let wiederWestAb: String?
        @Lenient var minimumU10Ms: Double?
        let minimumTag: String?
    }

    struct VortexGfs: Decodable {
        let modell: String?
        let time: [String]?
        let u10Ms: Series<Double>?
    }

    struct VortexEnsemble: Decodable {
        let modell: String?
        @Lenient var anteilLaeufeMitUmkehrPct: Double?
        let time: [String]?
        let anteilOstPct: Series<Double>?
        let medianU10Ms: Series<Double>?
        let p10U10Ms: Series<Double>?
        let p90U10Ms: Series<Double>?
    }

    struct Vortex: Decodable {
        let kennwert: String?
        let saison: String?
        let aktuell: VortexNow?
        let trend7d: VortexTrend?
        let umkehrAufOst: Reversal?
        let gfs: VortexGfs?
        let ensembleEcmwf: VortexEnsemble?
    }

    struct IndexTrend: Decodable {
        @Lenient var proWoche: Double?
        let einordnung: String?
    }

    struct IndexForecast: Decodable {
        let lauf: String?
        let time: [String]?
        let wert: Series<Double>?
    }

    struct Oscillation: Decodable {
        let index: String?
        @Lenient var letzterWert: Double?
        let datum: String?
        let phase: String?
        let trend14d: IndexTrend?
        let prognoseGfs: IndexForecast?
    }

    let generatedAt: String?
    let grosswetterlage: Gwl?
    let regime: Regime?
    let polarwirbel: Vortex?
    let ao: Oscillation?
    let nao: Oscillation?
    let sourceErrors: [SourceProblem]?
}

// MARK: - /api/v1/grosswetterlage/katalog

struct GwlCatalogResponse: Decodable {
    struct Entry: Decodable {
        let code: String
        let name: String?
        let grosswettertyp: String?
        let zirkulationsform: String?
        let zyklonal: Bool?
    }

    struct TypeInfo: Decodable {
        let grosswettertyp: String
        @Lenient var herkunftGrad: Double?
        let winterhalbjahr: String?
        let sommerhalbjahr: String?
    }

    struct Ensemble: Decodable {
        let bericht: String?
        let ausgegebenLokal: String?
        let codes: [String]?
    }

    let katalog: [Entry]?
    let typen: [TypeInfo]?
    let zirkulationsformen: [String: String]?
    let klimatologieHinweis: String?
    let quelleKatalog: String?
    let ensemble: Ensemble?
}

// MARK: - /api/v1/profil/sonde

/// Latest radiosonde ascent of the nearest DWD station.
struct SoundingResponse: Decodable {
    struct Station: Decodable {
        let name: String?
        let text: String?
        @Lenient var entfernungKm: Double?
    }

    struct Level: Decodable {
        @Lenient var pHpa: Double?
        @Lenient var zM: Double?
        @Lenient var zMslM: Double?
        @Lenient var tC: Double?
        @Lenient var tdC: Double?
        @Lenient var rhPct: Double?
        @Lenient var windKmh: Double?
        @Lenient var windDirDeg: Double?
    }

    struct Parcel: Decodable {
        let name: String?
        @Lenient var lclM: Double?
        @Lenient var lfcM: Double?
        @Lenient var elM: Double?
        @Lenient var capeJKg: Double?
        @Lenient var cinJKg: Double?
    }

    struct Indices: Decodable {
        @Lenient var liftedIndexK: Double?
        @Lenient var showalterK: Double?
        @Lenient var kIndex: Double?
        @Lenient var totalTotals: Double?
        @Lenient var niederschlagswasserMm: Double?
    }

    struct Inversion: Decodable {
        let type: String?
        @Lenient var baseM: Double?
        @Lenient var topM: Double?
        @Lenient var strengthK: Double?
    }

    struct Comparison: Decodable {
        let note: String?
        @Lenient var meanAbsDtK: Double?
        let assessment: String?
    }

    let generatedAt: String?
    let station: Station?
    let nominalUtc: String?
    let launchUtc: String?
    let quelle: String?
    let ebenen: [Level]?
    let pakete: [Parcel]?
    let indizes: Indices?
    @Lenient var nullgradMslM: Double?
    @Lenient var feuchtkugelNullMslM: Double?
    let inversionen: [Inversion]?
    let vsIconD2: Comparison?
    let sourceErrors: [SourceProblem]?
}
