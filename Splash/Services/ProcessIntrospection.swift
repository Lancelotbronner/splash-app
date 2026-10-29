import Foundation

// MARK: - Introspección de procesos: parsers puros y política de señales

/// Una conexión TCP activa observada con `lsof`, ya interpretada.
/// `nonisolated` (§7): la construye el parser puro `ListerOutput` en segundo plano.
nonisolated struct EstablishedConnection: Equatable {
	let pid: Int32
	let command: String
	let remoteAddress: String

	init(pid: Int32, command: String, remoteAddress: String) {
		self.pid = pid
		self.command = command
		self.remoteAddress = remoteAddress
	}
}

/// Interpreta la salida de `lsof` sin depender del entorno.
/// `nonisolated` (§7): parser puro, invocable desde trabajo en segundo plano.
nonisolated enum ListerOutput {
	/// Columnas de `lsof -n -P`: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME.
	static let minimumColumns = 9

	/// PIDs de `lsof -tiTCP:<puerto> -sTCP:LISTEN` (una columna, un PID por línea).
	static func listeningPIDs(_ output: String) -> [Int32] {
		output
			.components(separatedBy: .newlines)
			.compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
			.filter { $0 > 0 }
	}

	/// Conexiones establecidas de `lsof -iTCP:<puerto> -sTCP:ESTABLISHED -n -P`.
	///
	/// El parser anterior estaba escrito en línea dentro de `scanConnectedClients()`
	/// y descartaba filas con menos de 9 columnas sin dejar rastro; ahora es una
	/// función pura y comprobable.
	static func establishedConnections(_ output: String) -> [EstablishedConnection] {
		var connections: [EstablishedConnection] = []
		for line in output.components(separatedBy: .newlines).dropFirst() {
			let columns = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
			guard columns.count >= minimumColumns,
				  let pid = Int32(columns[1]), pid > 0 else { continue }
			connections.append(EstablishedConnection(
				pid: pid,
				command: columns[0],
				remoteAddress: columns[8]
			))
		}
		return connections
	}
}

/// Decide si un proceso pertenece al motor Splash y, por tanto, si es lícito señalizarlo.
/// `nonisolated` (§7): comprobación pura, invocable desde trabajo en segundo plano.
nonisolated enum SplashEngineIdentity {
	/// Marcadores del motor según su instalación de Homebrew (`libexec/server/server.py`,
	/// `libexec/engine/splash serve-native`, `bin/splash`).
	/// §4: el marcador "splash" sin separador desapareció — coincidía con la ruta de
	/// este mismo app (`SplashMonitor.app/Contents/MacOS/Splash`); solo quedan
	/// marcadores con separador de ruta o nombres específicos del motor.
	static let engineMarkers = ["server.py", "serve-native", "/splash"]

	static func isEngineCommand(_ command: String) -> Bool {
		let value = command.lowercased()
		guard !value.isEmpty else { return false }
		return engineMarkers.contains { value.contains($0) }
	}
}

/// Resuelve a qué PIDs es lícito enviar una señal al liberar un puerto.
///
/// Regla corregida: **solo escuchas** (`-sTCP:LISTEN`) **y** solo del motor.
/// El código anterior usaba `lsof -ti :<puerto>`, que devuelve también a los
/// clientes conectados (IDERs, agentes, navegadores) y a continuación aplicaba
/// `SIGKILL` a todos ellos. Medido: con un servidor y un cliente en procesos
/// distintos, `lsof -ti :18097` devuelve los dos PIDs, mientras que
/// `lsof -tiTCP:18097 -sTCP:LISTEN` devuelve solo el servidor.
/// `nonisolated` (§7): resolución pura, invocable desde trabajo en segundo plano.
nonisolated enum KillTargetResolver {
	/// - Parameters:
	///   - lsofOutput: salida de `lsof -tiTCP:<puerto> -sTCP:LISTEN`.
	///   - commandFor: resolutor del comando de cada PID (`ps -p <pid> -o command=`).
	/// - Returns: PIDs del motor que escuchan en el puerto.
	static func enginePIDsToStop(lsofOutput: String,
										commandFor: (Int32) -> String?) -> [Int32] {
		ListerOutput.listeningPIDs(lsofOutput).filter { pid in
			guard let command = commandFor(pid), !command.isEmpty else { return false }
			return SplashEngineIdentity.isEngineCommand(command)
		}
	}

	/// Escalada de señales verificada: nunca SIGKILL directo.
	enum Signal: String, Sendable {
		case interrupt = "-INT"
		case terminate = "-TERM"
		case forceKill = "-KILL"
	}

	/// Plan de escalada. El primer paso siempre es cortés; `SIGKILL` solo llega
	/// tras dos esperas fallidas y con la identidad ya verificada.
	static let escalation: [Signal] = [.interrupt, .terminate, .forceKill]
}
