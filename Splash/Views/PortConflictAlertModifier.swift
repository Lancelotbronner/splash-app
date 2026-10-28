import SwiftUI

/// Alerta de conflicto de puerto compartida por las pestañas (revisión §5.2 /
/// F-SC-1 / F-MM-1).
///
/// Antes, Server y Models llevaban copias casi idénticas de
/// `.alert(item:)` que devuelve `Alert` — ese overload (y el struct `Alert`)
/// están en la lista de soft-deprecation de SDK-27. Aquí vive una sola copia
/// con doble camino: en macOS 27 usa `alert(_:item:)` y la forma anterior se
/// mantiene como fallback para 26.x. `PortConflictInfo` es `Identifiable +
/// Equatable`, por lo que ambos caminos funcionan con el mismo binding.
/// Cuando el deployment target se mueva a 27, borrar el gate y el fallback.
struct PortConflictAlertModifier: ViewModifier {
	/// Hook opcional que se invoca al aceptar el puerto sugerido
	/// (`ServerControlView` lo usa para sincronizar su `portString` local).
	var onUseSuggestedPort: ((Int) -> Void)? = nil

	private func useSuggestedPort(_ conflict: PortConflictInfo) {
		onUseSuggestedPort?(conflict.suggestedPort)
		SplashService.shared.useSuggestedPort(conflict.suggestedPort)
	}

	private func freePort(_ conflict: PortConflictInfo) {
		SplashService.shared.resolvePortConflict(killProcess: true)
	}

	private var messageText: (PortConflictInfo) -> String {
		{ conflict in
			"Process '\(conflict.processName)' (PID \(conflict.pid)) is currently using port \(conflict.port).\n\nWould you like to switch to suggested free port \(conflict.suggestedPort) or free port \(conflict.port)?"
		}
	}

	func body(content: Content) -> some View {
		Group {
			if #available(macOS 27, *) {
				content.alert("Port in use", item: SplashService.$shared.portConflict) { conflict in
					Button("Use port \(conflict.suggestedPort)") { useSuggestedPort(conflict) }
						.keyboardShortcut(.defaultAction)
					Button("Free port \(conflict.port)", role: .destructive) { freePort(conflict) }
				} message: { conflict in
					Text(messageText(conflict))
				}
			} else {
				content.alert(item: SplashService.$shared.portConflict) { conflict in
					Alert(
						title: Text("⚠️ Port \(conflict.port) In Use"),
						message: Text(messageText(conflict)),
						primaryButton: .default(Text("Use port \(conflict.suggestedPort)")) {
							useSuggestedPort(conflict)
						},
						secondaryButton: .destructive(Text("Free port \(conflict.port)")) {
							freePort(conflict)
						}
					)
				}
			}
		}
	}
}

extension View {
	/// Alerta de conflicto de puerto compartida entre las pestañas Server y
	/// Models (revisión §5.2).
	func portConflictAlert(onUseSuggestedPort: ((Int) -> Void)? = nil) -> some View {
		modifier(PortConflictAlertModifier(onUseSuggestedPort: onUseSuggestedPort))
	}
}
