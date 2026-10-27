import Foundation

struct ICCProfile {
    private(set) var data: Data
    private var tags: [String: (offset: Int, size: Int)] = [:]

    init(data: Data) throws {
        guard data.count >= 132, String(data: data[36..<40], encoding: .ascii) == "acsp" else { throw DisplayError.unsupportedProfile }
        self.data = data
        let count = Int(u32(128))
        guard 132 + count * 12 <= data.count else { throw DisplayError.unsupportedProfile }
        for i in 0..<count {
            let p = 132 + i * 12
            let sig = String(data: data[p..<p+4], encoding: .ascii) ?? ""
            tags[sig] = (Int(u32(p + 4)), Int(u32(p + 8)))
        }
    }

    mutating func contractColorants(by amount: Double) throws {
        let white = try xyz("wtpt")
        for signature in ["rXYZ", "gXYZ", "bXYZ"] {
            let value = try xyz(signature)
            // Equal-energy share of the white point is neutral. Moving each colorant
            // toward it contracts declared gamut while retaining the profile white.
            let neutral = white.map { $0 / 3 }
            try setXYZ(signature, zip(value, neutral).map { $1 + ($0 - $1) * amount })
        }
        // Profile ID is invalid after editing; zero requests recalculation by consumers.
        if data.count >= 100 { data.replaceSubrange(84..<100, with: repeatElement(UInt8(0), count: 16)) }
    }

    mutating func rename(_ name: String) {
        // Keep binary layout stable; replace an existing ASCII description only when it fits.
        guard let tag = tags["desc"], tag.size > 16, ascii(tag.offset, 4) == "desc" else { return }
        let maxLength = tag.size - 12
        let bytes = Array(name.utf8.prefix(maxLength - 1)) + [0]
        putU32(UInt32(bytes.count), at: tag.offset + 8)
        data.replaceSubrange(tag.offset + 12..<tag.offset + 12 + bytes.count, with: bytes)
    }

    private func xyz(_ signature: String) throws -> [Double] {
        guard let tag = tags[signature], tag.size >= 20, ascii(tag.offset, 4) == "XYZ " else { throw DisplayError.unsupportedProfile }
        return [s15(tag.offset + 8), s15(tag.offset + 12), s15(tag.offset + 16)]
    }

    private mutating func setXYZ(_ signature: String, _ values: [Double]) throws {
        guard let tag = tags[signature] else { throw DisplayError.unsupportedProfile }
        for (i, value) in values.enumerated() { putS15(value, at: tag.offset + 8 + i * 4) }
    }

    private func u32(_ offset: Int) -> UInt32 { data[offset..<offset+4].reduce(0) { ($0 << 8) | UInt32($1) } }
    private func s15(_ offset: Int) -> Double { Double(Int32(bitPattern: u32(offset))) / 65536 }
    private func ascii(_ offset: Int, _ length: Int) -> String { String(data: data[offset..<offset+length], encoding: .ascii) ?? "" }
    private mutating func putU32(_ value: UInt32, at offset: Int) {
        let b = [UInt8(value >> 24), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)]
        data.replaceSubrange(offset..<offset+4, with: b)
    }
    private mutating func putS15(_ value: Double, at offset: Int) { putU32(UInt32(bitPattern: Int32((value * 65536).rounded())), at: offset) }
}
