import Foundation

// MARK: - Validación de identificadores de modelo (P-03 / H-03)

/// Valida identificadores `owner/repo` antes de interpolarlos en un script de shell.
///
/// `startServer()` construía `splash serve --model "\(model)"` dentro de un fichero
/// `.command` que después ejecutaba `/bin/bash`. Un modelo con comillas cerraba el
/// entrecomillado y permitía ejecutar comandos arbitrarios (verificado: un payload
/// `incoai/x" ; touch /tmp/testigo ; echo "` creó el fichero testigo).
///
/// Las reglas replican las restricciones que el propio motor impone a los alias de
/// modelo (`DEVELOPMENT.md` §API model aliases): sin espacios, sin caracteres de
/// control, sin `\`, `%`, `?`, `#`, y sin segmentos vacíos, `.` o `..`.
/// `nonisolated` (§7): lógica pura, invocable desde el escaneo fuera del actor principal.
nonisolated enum ModelIDValidator {
	static let maxOwnerLength = 64
	static let maxRepositoryLength = 96
	static let maxVariantLength = 64

	private static let forbiddenCharacters = CharacterSet(charactersIn: " \t\n\r\\%?#\"'`;&|$<>(){}[]*!~^=")
		.union(.controlCharacters)
		.union(.illegalCharacters)

	static func isValid(_ raw: String) -> Bool {
		let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !value.isEmpty,
			  value.rangeOfCharacter(from: forbiddenCharacters) == nil else { return false }

		let segments = value.split(separator: "/", omittingEmptySubsequences: false)
		guard segments.count == 2 else { return false }

		let owner = String(segments[0])
		let repoSegment = String(segments[1])
		guard !owner.isEmpty, !repoSegment.isEmpty,
			  owner.count <= maxOwnerLength,
			  owner != ".", owner != ".." else { return false }

		let allowed = CharacterSet(charactersIn:
									"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
		guard owner.unicodeScalars.allSatisfy(allowed.contains) else { return false }

		// Soporte de variantes oficiales de Splash: OWNER/REPO[:VARIANT] (ej. :UD-Q4_K_XL, :Q4_K_M)
		let repoParts = repoSegment.split(separator: ":", omittingEmptySubsequences: false)
		guard repoParts.count <= 2 else { return false }

		let repository = String(repoParts[0])
		guard !repository.isEmpty,
			  repository.count <= maxRepositoryLength,
			  repository != ".", repository != "..",
			  repository.unicodeScalars.allSatisfy(allowed.contains) else { return false }

		if repoParts.count == 2 {
			let variant = String(repoParts[1])
			guard !variant.isEmpty,
				  variant.count <= maxVariantLength,
				  variant != ".", variant != "..",
				  variant.unicodeScalars.allSatisfy(allowed.contains) else { return false }
		}

		return true
	}

	/// Recorta espacios y devuelve `nil` si el identificador no es válido.
	static func normalized(_ raw: String) -> String? {
		let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		return isValid(value) ? value : nil
	}

	/// Desglosa el identificador en sus componentes (owner, repository, variant opcional).
	static func components(from raw: String) -> (owner: String, repository: String, variant: String?)? {
		guard let valid = normalized(raw) else { return nil }
		let segments = valid.split(separator: "/")
		let owner = String(segments[0])
		let repoParts = segments[1].split(separator: ":")
		let repository = String(repoParts[0])
		let variant = repoParts.count > 1 ? String(repoParts[1]) : nil
		return (owner, repository, variant)
	}

	/// Devuelve el identificador base `owner/repository` sin el sufijo `:variante`.
	static func baseModelId(_ raw: String) -> String? {
		guard let comp = components(from: raw) else { return nil }
		return "\(comp.owner)/\(comp.repository)"
	}

	/// Indica si el identificador incluye una variante `:VARIANTE`.
	static func hasVariant(_ raw: String) -> Bool {
		return components(from: raw)?.variant != nil
	}

	/// Motivo legible para mostrar al usuario en la interfaz.
	static func rejectionReason(_ raw: String) -> LocalizedStringResource? {
		let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if value.isEmpty {
			return "The model identifier is empty."
		}
		if isValid(value) { return nil }
		// §9: el mensaje de caracteres prohibidos primero — antes, un valor con
		// ambos problemas recibía el mensaje (menos útil) del separador.
		if value.rangeOfCharacter(from: forbiddenCharacters) != nil {
			return "Contains forbidden characters (spaces, quotes, ; | & $ ` \\ % ? # …)."
		}
		if !value.contains("/") {
			return "Missing separator: use format owner/model or owner/model:variant."
		}
		let segments = value.split(separator: "/", omittingEmptySubsequences: false)
		if segments.count != 2 {
			return "Format must be owner/model[:variant] (exactly one '/' separator)."
		}
		let repoSegment = String(segments[1])
		let repoParts = repoSegment.split(separator: ":", omittingEmptySubsequences: false)
		if repoParts.count > 2 {
			return "Too many variant ':' separators (maximum one allowed)."
		}
		if repoParts.count == 2 && repoParts[1].isEmpty {
			return "Variant following ':' cannot be empty."
		}
		return "Only letters, digits, dots, hyphens, and underscores are allowed (and ':' for variants)."
	}
}
