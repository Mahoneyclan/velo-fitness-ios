import Foundation
import Compression

/// Parses punch metrics out of a boxing activity's FIT file, reading the f3b Connect IQ
/// app's developer fields directly — no server-side step, no Python. Field names/base
/// types were verified byte-for-byte against a real f3b export before being hardcoded
/// here (see project history — cross-checked against `fitparse`'s decode of the same file).
///
/// This is a minimal, targeted FIT reader (definition + data messages, developer field
/// resolution, compressed-timestamp headers) — not a general FIT SDK. It only decodes
/// the message types boxing needs (session + record).
enum FITBoxingParser {

    struct ParsedBoxingMetrics {
        var avgHR: Double?
        var maxHR: Double?
        var calories: Double?
        var durationS: Double?
        var punchRateAvg: Double?
        var totalPunches: Double?
        var totalJab: Double?
        var totalHook: Double?
        var totalCross: Double?
        var punchForceMax: Double?          // session-level whole-activity max ("mForce")
        var punchForceMaxRecord: Double?     // fallback: max across the per-record "Force" stream
        var punchForceAvg1s: Double?         // avg across the per-record "vForce" stream
        var stepRateAvg: Double?
        var energyExpenditure: Double?
        var totalSteps: Double?
        var batteryUsedPct: Double?
    }

    /// `raw` is the bytes downloaded from Garmin's ORIGINAL download endpoint — a zip
    /// containing one .fit file.
    static func parse(zippedFIT raw: Data) -> ParsedBoxingMetrics? {
        guard let fitData = ZipReader.unzipFirstEntry(raw) ?? Optional(raw) else { return nil }
        let parser = _FITParser(data: fitData)
        parser.parse()

        var m = ParsedBoxingMetrics()
        m.avgHR             = parser.sessionValues["avg_heart_rate"]
        m.maxHR              = parser.sessionValues["max_heart_rate"]
        m.calories           = parser.sessionValues["total_calories"]
        m.durationS          = parser.sessionValues["total_elapsed_time"]
        m.punchRateAvg       = parser.sessionValues["pRate"]
        m.totalPunches       = parser.sessionValues["tPunch"]
        m.totalJab           = parser.sessionValues["tJabs"]
        m.totalHook          = parser.sessionValues["tHooks"]
        m.totalCross         = parser.sessionValues["tCross"]
        m.punchForceMax      = parser.sessionValues["mForce"]
        m.totalSteps         = parser.sessionValues["tStps"]
        if let bat = parser.sessionValues["%bat"] { m.batteryUsedPct = abs(bat) }  // observed as a negative delta

        if let force = parser.recordStreams["Force"], !force.isEmpty {
            m.punchForceMaxRecord = force.max()
        }
        if let vforce = parser.recordStreams["vForce"] {
            let nz = vforce.filter { $0 != 0 }
            if !nz.isEmpty { m.punchForceAvg1s = nz.reduce(0, +) / Double(nz.count) }
        }
        if let ee = parser.recordStreams["eE"] {
            let nz = ee.filter { $0 != 0 }
            if !nz.isEmpty { m.energyExpenditure = nz.reduce(0, +) / Double(nz.count) }
        }
        if let stprate = parser.recordStreams["StpRate"] {
            let nz = stprate.filter { $0 != 0 }
            if !nz.isEmpty { m.stepRateAvg = nz.reduce(0, +) / Double(nz.count) }
        }
        return m
    }
}

// MARK: - Minimal ZIP reader (deflate/stored only — all Garmin's downloads use)

enum ZipReader {
    static func unzipFirstEntry(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 22 else { return nil }

        func u16(_ off: Int) -> Int { Int(bytes[off]) | (Int(bytes[off+1]) << 8) }
        func u32(_ off: Int) -> Int { Int(bytes[off]) | (Int(bytes[off+1])<<8) | (Int(bytes[off+2])<<16) | (Int(bytes[off+3])<<24) }

        // Find End Of Central Directory record (PK\x05\x06), scanning back from EOF
        // to allow for a trailing comment.
        var eocd = -1
        let searchFloor = max(0, bytes.count - 22 - 65536)
        var i = bytes.count - 22
        while i >= searchFloor {
            if bytes[i] == 0x50, bytes[i+1] == 0x4B, bytes[i+2] == 0x05, bytes[i+3] == 0x06 {
                eocd = i; break
            }
            i -= 1
        }
        guard eocd >= 0 else { return nil }

        let cdOffset = u32(eocd + 16)
        guard cdOffset + 4 <= bytes.count,
              bytes[cdOffset] == 0x50, bytes[cdOffset+1] == 0x4B, bytes[cdOffset+2] == 0x01, bytes[cdOffset+3] == 0x02
        else { return nil }

        let method = u16(cdOffset + 10)
        let compSize = u32(cdOffset + 20)
        let localHeaderOffset = u32(cdOffset + 42)

        // The local file header's own size fields are unreliable when Garmin's zip
        // used a streaming data descriptor (sizes only exist in the central directory,
        // read above) — only its name/extra lengths are used, to locate the data start.
        guard bytes[localHeaderOffset] == 0x50, bytes[localHeaderOffset+1] == 0x4B,
              bytes[localHeaderOffset+2] == 0x03, bytes[localHeaderOffset+3] == 0x04
        else { return nil }
        let localNameLen = u16(localHeaderOffset + 26)
        let localExtraLen = u16(localHeaderOffset + 28)
        let dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen

        guard dataStart + compSize <= bytes.count else { return nil }
        let compData = Data(bytes[dataStart..<(dataStart+compSize)])

        switch method {
        case 0: return compData // stored, no compression
        case 8: return inflate(compData)
        default: return nil
        }
    }

    private static func inflate(_ data: Data) -> Data? {
        let bufferSize = 10 * 1024 * 1024
        var dst = [UInt8](repeating: 0, count: bufferSize)
        let srcBytes = [UInt8](data)
        let decodedSize = srcBytes.withUnsafeBufferPointer { srcPtr -> Int in
            compression_decode_buffer(&dst, bufferSize, srcPtr.baseAddress!, srcBytes.count, nil, COMPRESSION_ZLIB)
        }
        guard decodedSize > 0 else { return nil }
        return Data(dst[0..<decodedSize])
    }
}

// MARK: - Minimal FIT binary parser (session + record messages, developer fields only)

private struct _FITField {
    var doubleValues: [Double] = []
    var isString = false
    var stringValue = ""
}

private struct _FieldDef {
    let defNum: UInt8
    let size: UInt8
    let baseType: UInt8
}

private struct _DevFieldDef {
    let fieldNum: UInt8
    let size: UInt8
    let devDataIndex: UInt8
}

private struct _MessageDef {
    let globalMessageNumber: UInt16
    let bigEndian: Bool
    let fields: [_FieldDef]
    let devFields: [_DevFieldDef]
}

private final class _FITParser {
    private let bytes: [UInt8]
    private var offset: Int
    private var localDefs: [UInt8: _MessageDef] = [:]
    private var devFieldNames: [UInt8: [UInt8: String]] = [:]
    private var devFieldBaseTypes: [UInt8: [UInt8: UInt8]] = [:]

    var sessionValues: [String: Double] = [:]
    var recordStreams: [String: [Double]] = [:]

    init(data: Data) {
        self.bytes = [UInt8](data)
        self.offset = bytes.isEmpty ? 0 : Int(bytes[0])
    }

    private func baseTypeSize(_ bt: UInt8) -> Int {
        switch bt & 0x1F {
        case 0x00, 0x01, 0x02, 0x0A, 0x0D: return 1
        case 0x03, 0x04, 0x0B: return 2
        case 0x05, 0x06, 0x08, 0x0C: return 4
        case 0x07: return 1
        case 0x09, 0x0E, 0x0F, 0x10: return 8
        default: return 1
        }
    }

    private func isInvalid(_ bt: UInt8, _ raw: UInt64) -> Bool {
        switch bt & 0x1F {
        case 0x00: return raw == 0xFF
        case 0x01: return raw == 0x7F
        case 0x02: return raw == 0xFF
        case 0x03: return raw == 0x7FFF
        case 0x04: return raw == 0xFFFF
        case 0x05: return raw == 0x7FFFFFFF
        case 0x06: return raw == 0xFFFFFFFF
        case 0x08: return raw == 0xFFFFFFFF
        case 0x0A, 0x0B, 0x0C: return raw == 0
        case 0x0D: return raw == 0xFF
        default: return false
        }
    }

    private func readUInt(_ n: Int, bigEndian: Bool) -> UInt64 {
        guard offset + n <= bytes.count else { offset = bytes.count; return 0 }
        var v: UInt64 = 0
        if bigEndian {
            for i in 0..<n { v = (v << 8) | UInt64(bytes[offset + i]) }
        } else {
            for i in (0..<n).reversed() { v = (v << 8) | UInt64(bytes[offset + i]) }
        }
        offset += n
        return v
    }

    private func readField(size: Int, baseType: UInt8, bigEndian: Bool) -> _FITField {
        var field = _FITField()
        if (baseType & 0x1F) == 0x07 {
            var s = ""
            let end = min(offset + size, bytes.count)
            for i in offset..<end {
                let c = bytes[i]
                if c == 0 { break }
                s.append(Character(UnicodeScalar(c)))
            }
            offset = end
            field.isString = true
            field.stringValue = s
            return field
        }
        let compSize = baseTypeSize(baseType)
        let count = max(1, size / max(compSize, 1))
        for _ in 0..<count {
            guard offset + compSize <= bytes.count else { break }
            let raw = readUInt(compSize, bigEndian: bigEndian)
            if isInvalid(baseType, raw) { continue }
            let resolved: Double
            switch baseType & 0x1F {
            case 0x01: resolved = Double(Int8(bitPattern: UInt8(truncatingIfNeeded: raw)))
            case 0x03: resolved = Double(Int16(bitPattern: UInt16(truncatingIfNeeded: raw)))
            case 0x05: resolved = Double(Int32(bitPattern: UInt32(truncatingIfNeeded: raw)))
            case 0x08: resolved = Double(Float(bitPattern: UInt32(truncatingIfNeeded: raw)))
            case 0x09: resolved = Double(bitPattern: raw)
            default:   resolved = Double(raw)
            }
            field.doubleValues.append(resolved)
        }
        return field
    }

    private func fieldStandardName(globalMsg: UInt16, defNum: UInt8) -> String {
        if globalMsg == 18 { // session
            switch defNum {
            case 16: return "avg_heart_rate"
            case 17: return "max_heart_rate"
            case 11: return "total_calories"
            case 7:  return "total_elapsed_time"
            default: return "__raw_\(defNum)"
            }
        }
        return "__raw_\(defNum)"
    }

    private func parseDefinitionMessage(localType: UInt8, hasDevFields: Bool) {
        offset += 1 // reserved
        guard offset < bytes.count else { return }
        let arch = bytes[offset]; offset += 1
        let bigEndian = arch != 0
        let globalNum = UInt16(readUInt(2, bigEndian: bigEndian))
        guard offset < bytes.count else { return }
        let numFields = Int(bytes[offset]); offset += 1
        var fields: [_FieldDef] = []
        for _ in 0..<numFields {
            guard offset + 3 <= bytes.count else { break }
            fields.append(_FieldDef(defNum: bytes[offset], size: bytes[offset+1], baseType: bytes[offset+2]))
            offset += 3
        }
        var devFields: [_DevFieldDef] = []
        if hasDevFields, offset < bytes.count {
            let numDev = Int(bytes[offset]); offset += 1
            for _ in 0..<numDev {
                guard offset + 3 <= bytes.count else { break }
                devFields.append(_DevFieldDef(fieldNum: bytes[offset], size: bytes[offset+1], devDataIndex: bytes[offset+2]))
                offset += 3
            }
        }
        localDefs[localType] = _MessageDef(globalMessageNumber: globalNum, bigEndian: bigEndian, fields: fields, devFields: devFields)
    }

    private func parseDataMessage(localType: UInt8) {
        guard let def = localDefs[localType] else { return }
        var named: [String: _FITField] = [:]
        var devNamed: [String: _FITField] = [:]

        for fd in def.fields {
            let field = readField(size: Int(fd.size), baseType: fd.baseType, bigEndian: def.bigEndian)
            named[fieldStandardName(globalMsg: def.globalMessageNumber, defNum: fd.defNum)] = field
        }
        for dfd in def.devFields {
            let bt = devFieldBaseTypes[dfd.devDataIndex]?[dfd.fieldNum] ?? 0x88
            let field = readField(size: Int(dfd.size), baseType: bt, bigEndian: def.bigEndian)
            let name = devFieldNames[dfd.devDataIndex]?[dfd.fieldNum] ?? "dev_\(dfd.fieldNum)"
            devNamed[name] = field
        }

        // field_description (global 206): 0=devDataIndex, 1=fieldDefNum, 2=baseType, 3=name, 8=units
        if def.globalMessageNumber == 206 {
            let idx = UInt8(named["__raw_0"]?.doubleValues.first ?? 0)
            let defNum = UInt8(named["__raw_1"]?.doubleValues.first ?? 0)
            let baseType = UInt8(named["__raw_2"]?.doubleValues.first ?? 0x88)
            let name = named["__raw_3"]?.stringValue ?? ""
            devFieldNames[idx, default: [:]][defNum] = name
            devFieldBaseTypes[idx, default: [:]][defNum] = baseType
        }

        if def.globalMessageNumber == 18 { // session
            for (k, v) in named where !v.doubleValues.isEmpty {
                if ["avg_heart_rate", "max_heart_rate", "total_calories"].contains(k) {
                    sessionValues[k] = v.doubleValues[0]
                }
                if k == "total_elapsed_time" { sessionValues[k] = v.doubleValues[0] / 1000.0 }
            }
            for (name, v) in devNamed where !v.doubleValues.isEmpty {
                sessionValues[name] = v.doubleValues[0]
            }
        }

        if def.globalMessageNumber == 20 { // record
            for (name, v) in devNamed where !v.doubleValues.isEmpty {
                recordStreams[name, default: []].append(v.doubleValues[0])
            }
        }
    }

    func parse() {
        guard bytes.count > 12 else { return }
        let dataSize = Int(bytes[4]) | (Int(bytes[5]) << 8) | (Int(bytes[6]) << 16) | (Int(bytes[7]) << 24)
        let headerSize = Int(bytes[0])
        let dataEnd = min(headerSize + dataSize, bytes.count)

        while offset < dataEnd {
            let recordHeader = bytes[offset]; offset += 1
            if recordHeader & 0x80 != 0 {
                let localType = (recordHeader & 0x60) >> 5
                parseDataMessage(localType: localType)
            } else if recordHeader & 0x40 != 0 {
                let localType = recordHeader & 0x0F
                let hasDev = (recordHeader & 0x20) != 0
                parseDefinitionMessage(localType: localType, hasDevFields: hasDev)
            } else {
                parseDataMessage(localType: recordHeader & 0x0F)
            }
        }
    }
}
