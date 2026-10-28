import SwiftUI
import AppKit

/// Estado del mensaje «copiado» que parpadea durante 2 s (F-SC-9 / F-CA-7).
///
/// Cada copia produce un `id` nuevo, de modo que `.task(id:)` reinicia el
/// temporizador de 2 s y la espera se cancela al desaparecer la vista —
/// antes era un `DispatchQueue.main.asyncAfter` sin gestión que sobrevivía a
/// la vista, y el mensaje se resolvía a la locale en el momento de construir
/// la vista, no de copiar.
struct CopiedFlash: Equatable {
	let id: UUID
	let message: String
}

extension View {
	/// Copia `string` al portapapeles y enciende `copied` con `message`
	/// (resuelto a la locale actual en el momento de la copia).
	/// Acompáñalo de `copiedFlashAutoClear(_:)` para el autolimpieza a los 2 s.
	func copyToClipboard(_ string: String,
						 flash message: LocalizedStringResource,
						 into copied: Binding<CopiedFlash?>) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
		withAnimation {
			copied.wrappedValue = CopiedFlash(id: UUID(), message: String(localized: message))
		}
	}

	/// Limpia `copied` 2 s después de la última copia. Cancelable: `.task(id:)`
	/// se cancela automáticamente al desaparecer la vista (revisión §7).
	func copiedFlashAutoClear(_ copied: Binding<CopiedFlash?>) -> some View {
		task(id: copied.wrappedValue?.id) {
			guard let current = copied.wrappedValue else { return }
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			withAnimation {
				if copied.wrappedValue?.id == current.id {
					copied.wrappedValue = nil
				}
			}
		}
	}
}
