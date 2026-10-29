import Foundation

/// Validador y tokenizador para argumentos y flags CLI arbitrarios proporcionados por el usuario
/// para el comando `splash serve`.
/// Aplica controles estrictos contra inyecciones de shell (P-03 / H-03).
enum ServerCLIValidator {

	/// Caracteres seguros permitidos en los argumentos CLI adicionales.
	/// Cubre banderas (--no-webui), identificadores (incoai/model:variant), valores numéricos (50GB, 0.7),
	/// rutas seguras (/tmp/cache) y pares clave-valor (--opt=val).
	private static let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:=,%")

	/// Metacaracteres de shell estrictamente prohibidos para prevenir inyección de comandos.
	private static let dangerousCharacters = CharacterSet(charactersIn: ";|&$`\"'<>!()\n\r\t{}[]*?^~#")

	/// Valida y descompone la cadena de argumentos en tokens seguros.
	/// - Parameter raw: Cadena de texto introducida por el usuario (ej. `--no-webui --max-cache-disk 50GB`).
	/// - Returns: Tupla con la lista de tokens seguros y un mensaje de error si no es válida.
	static func validateAndTokenize(_ raw: String) -> (tokens: [String], error: LocalizedStringResource?) {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isEmpty {
			return ([], nil)
		}

		// Comprobación de metacaracteres peligrosos
		if trimmed.unicodeScalars.contains(where: { dangerousCharacters.contains($0) }) {
			return ([], "Shell metacharacters detected in the CLI flags.")
		}

		let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
		var validTokens: [String] = []

		for part in parts {
			guard part.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) else {
				return ([], "The argument '\(part)' contains invalid characters.")
			}
			validTokens.append(part)
		}

		return (validTokens, nil)
	}

	/// Devuelve una cadena saneada con los flags válidos separados por espacio, o cadena vacía si hay error.
	static func sanitizedString(_ raw: String) -> String {
		let (tokens, error) = validateAndTokenize(raw)
		guard error == nil else { return "" }
		return tokens.joined(separator: " ")
	}

	/// Valida un valor para el argumento `--idle-release` de Splash (ej: "off", "30s", "2m", "10m", "1h", "600").
	static func validateIdleRelease(_ raw: String) -> String? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if trimmed == "off" { return "off" }
		let regex = try? NSRegularExpression(pattern: "^[0-9]+[smh]?$", options: .caseInsensitive)
		let range = NSRange(location: 0, length: trimmed.utf16.count)
		if let match = regex?.firstMatch(in: trimmed, options: [], range: range), match.range.location != NSNotFound {
			return trimmed
		}
		return nil
	}

	/// Valida un valor para el argumento `--max-memory` de Splash (ej: "auto", "16G", "24G", "28G", "32G", "512M").
	static func validateMaxMemory(_ raw: String) -> String? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.lowercased() == "auto" { return "auto" }
		let regex = try? NSRegularExpression(pattern: "^[0-9]+[kmgtKMGT]?$", options: [])
		let range = NSRange(location: 0, length: trimmed.utf16.count)
		if let match = regex?.firstMatch(in: trimmed, options: [], range: range), match.range.location != NSNotFound {
			return trimmed.uppercased()
		}
		return nil
	}

	/// Valida el formato de estado recurrente GDN (--state-format bf16 | fp32) para Splash 1.3.2+
	static func validateStateFormat(_ raw: String) -> String? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if trimmed == "bf16" || trimmed == "fp32" { return trimmed }
		return nil
	}

	/// Valida el presupuesto de razonamiento (--thinking-token-budget N | -1) para Splash 1.3.2+
	static func validateThinkingBudget(_ raw: String) -> String? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if trimmed == "auto" { return "auto" }
		if trimmed == "-1" || trimmed == "off" || trimmed == "0" { return "-1" }
		// §9: solo un sufijo "k" final (antes `"1k2"` se aceptaba como 10002).
		if trimmed.hasSuffix("k") {
			let digits = trimmed.dropLast()
			guard !digits.isEmpty, digits.allSatisfy({ $0.isNumber }), let val = Int(digits), val > 0 else { return nil }
			return "\(val * 1000)"
		}
		guard trimmed.allSatisfy({ $0.isNumber }), let val = Int(trimmed), val > 0 else { return nil }
		return "\(val)"
	}
}
