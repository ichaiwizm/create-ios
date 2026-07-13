//
//  JSONValue.swift
//  Create
//
//  Valeur JSON dynamique utilisée pour `options` (requête /api/generate),
//  `extraInput` (constantes de famille) et `rawInput` (outils 1-clic).
//  Nom et cas figés par CONTRACTS §1.3. Encodage/décodage transparents :
//  on encode la valeur brute, sans enveloppe.
//

import Foundation

/// Un seul type portant n'importe quelle valeur JSON.
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    // MARK: Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        // L'ordre importe : bool avant int (Foundation distingue true/false des nombres),
        // int avant double (garde les entiers en .int), puis chaînes et conteneurs.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Valeur JSON non prise en charge"
            )
        }
    }

    // MARK: Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value):    try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value):   try container.encode(value)
        case .array(let value):  try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null:              try container.encodeNil()
        }
    }
}
