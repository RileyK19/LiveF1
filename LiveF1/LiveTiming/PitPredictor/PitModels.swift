//
//  PitModels.swift
//  LiveF1
//
//  Runs the five Core ML models. Input names come from the models themselves,
//  so there is no hard-coded feature list here. Add the five .mlpackage files
//  to the app target (Xcode compiles them to .mlmodelc in the bundle).
//

import Foundation
import CoreML

struct PitOutputs {
    var willStop: Double      // P(driver pits again)
    var within5: Double       // P(stop within 5 laps)
    var lapsMedian: Double
    var lapsLow: Double       // 10th percentile
    var lapsHigh: Double      // 90th percentile
}

final class PitModels {
    private let willStop: MLModel
    private let within5: MLModel
    private let lapsMedian: MLModel
    private let lapsLow: MLModel
    private let lapsHigh: MLModel

    /// Feature name -> input type, read from the model description.
    let inputTypes: [String: MLFeatureType]
    private var warnedMissing = false

    init?() {
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuOnly   // tree models; keeps results consistent with the parity check

        func load(_ name: String) -> MLModel? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                print("❌ \(name).mlmodelc not in bundle"); return nil
            }
            do { return try MLModel(contentsOf: url, configuration: cfg) }
            catch { print("❌ \(name) failed to load: \(error)"); return nil }
        }
        guard let a = load("PitWillStop"), let b = load("PitWithin5"),
              let c = load("PitLapsUntil"), let d = load("PitLapsLow"), let e = load("PitLapsHigh")
        else { return nil }
        willStop = a; within5 = b; lapsMedian = c; lapsLow = d; lapsHigh = e

        let desc = a.modelDescription.inputDescriptionsByName
        inputTypes = desc.mapValues { $0.type }

        // All five should take the same inputs.
        let ref = Set(desc.keys)
        for (n, m) in [("PitWithin5", b), ("PitLapsUntil", c), ("PitLapsLow", d), ("PitLapsHigh", e)] {
            if Set(m.modelDescription.inputDescriptionsByName.keys) != ref {
                print("⚠️ \(n) inputs differ from PitWillStop")
            }
        }
        print("🧠 pit models loaded, \(ref.count) features: \(ref.sorted())")
    }

    func predict(_ features: [String: Double]) -> PitOutputs? {
        let missing = inputTypes.keys.filter { features[$0] == nil }
        if !missing.isEmpty {
            print("⚠️ missing features: \(missing.sorted())")
            if !warnedMissing {
                warnedMissing = true
                print("⚠️ pit features not built yet: \(missing.sorted())")
            }
            return nil
        }

        var dict: [String: MLFeatureValue] = [:]
        for (name, type) in inputTypes {
            // Core ML trees need the value rounded through Float or ~5-45% of predictions drift.
            let v = Double(Float(features[name]!))
            dict[name] = (type == .int64) ? MLFeatureValue(int64: Int64(v)) : MLFeatureValue(double: v)
        }
        guard let input = try? MLDictionaryFeatureProvider(dictionary: dict) else { return nil }

        guard let ws = run(willStop, input, probability: true),
              let w5 = run(within5, input, probability: true),
              let med = run(lapsMedian, input, probability: false),
              let lo = run(lapsLow, input, probability: false),
              let hi = run(lapsHigh, input, probability: false)
        else { return nil }
        return PitOutputs(willStop: ws, within5: w5, lapsMedian: med, lapsLow: lo, lapsHigh: hi)
    }

    private func run(_ model: MLModel, _ input: MLFeatureProvider, probability: Bool) -> Double? {
        guard let out = try? model.prediction(from: input) else { return nil }

        // Classifier with a probability dictionary: take P(class 1).
        if probability, let probs = out.featureValue(for: "classProbability")?.dictionaryValue {
            for key: AnyHashable in [Int64(1), Int(1), "1", "True", true] {
                if let n = probs[key] { return n.doubleValue }
            }
        }
        // Regressor (or a classifier exported as a plain probability): first numeric output.
        for name in out.featureNames {
            guard let fv = out.featureValue(for: name) else { continue }
            switch fv.type {
            case .double: return fv.doubleValue
            case .int64: return Double(fv.int64Value)
            case .multiArray: if let a = fv.multiArrayValue, a.count > 0 { return a[0].doubleValue }
            default: continue
            }
        }
        return nil
    }
}
