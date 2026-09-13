//
//  GameHTTPTransportTests.swift
//  NathanielTests
//
//  Tests HTTP framing against an isolated server with no game actions.
//

@testable import Nathaniel
import Network
import XCTest

@MainActor
final class GameHTTPTransportTests: XCTestCase {
    private var server: GameCommandServer!
    private var delegate: RecordingCommandDelegate!
    private var port: UInt16 = 0

    override func setUp() async throws {
        try await super.setUp()
        self.port = UInt16.random(in: 20_000 ... 60_000)
        self.delegate = RecordingCommandDelegate()
        self.server = GameCommandServer(port: self.port)
        self.server.delegate = self.delegate
        self.server.start()
        let ready = expectation(for: NSPredicate { [weak self] _, _ in
            self?.server.isRunning == true
        }, evaluatedWith: nil)
        await fulfillment(of: [ready], timeout: 3)
    }

    override func tearDown() {
        self.server.stop()
        self.server = nil
        self.delegate = nil
        super.tearDown()
    }

    func testWaitsForFragmentedHeadersAndBody() async throws {
        let body = try actionBody(value: "fragmented 🚀")
        let header = "POST /action HTTP/1.1\r\nContent-Length: \(body.count)\r\n\r\n"
        let headerData = Data(header.utf8)
        let response = await exchange([
            Data(headerData.prefix(12)),
            Data(headerData.dropFirst(12)),
            Data(body.prefix(body.count - 2)),
            Data(body.suffix(2)),
        ])
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200"), response)
        XCTAssertEqual(self.delegate.values, ["fragmented 🚀"])
    }

    func testAcceptsBodyLargerThanOneReceiveBuffer() async throws {
        let value = String(repeating: "a", count: 200_000)
        let response = try await exchange([request(value: value)])
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200"), response)
        XCTAssertEqual(self.delegate.values, [value])
    }

    func testRejectsOversizedDeclaredBodyBeforeReadingIt() async {
        let response = await exchange([Data("POST /action HTTP/1.1\r\nContent-Length: 999999999\r\n\r\n".utf8)])
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 413"), response)
        XCTAssertTrue(self.delegate.values.isEmpty)
    }

    func testBoundsIncompleteHeaders() async {
        let response = await exchange([Data(("GET /health HTTP/1.1\r\nX-Padding: " + String(
            repeating: "x",
            count: 20_000
        )).utf8)])
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 413"), response)
        XCTAssertTrue(self.delegate.values.isEmpty)
    }

    func testRejectsInvalidContentLengthWithoutDispatching() async throws {
        var data = Data("POST /action HTTP/1.1\r\nContent-Length: -1\r\n\r\n".utf8)
        try data.append(self.actionBody(value: "invalid length"))
        let response = await exchange([data])
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 400"), response)
        XCTAssertTrue(self.delegate.values.isEmpty)
    }

    func testDispatchesOnlyFirstRequestOnConnection() async throws {
        var data = try request(value: "first")
        try data.append(self.request(value: "second"))
        let response = await exchange([data])
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200"), response)
        XCTAssertEqual(self.delegate.values, ["first"])
    }

    private func actionBody(value: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["name": "record", "params": ["value": value]])
    }

    private func request(value: String) throws -> Data {
        let body = try actionBody(value: value)
        var data = Data("POST /action HTTP/1.1\r\nContent-Length: \(body.count)\r\n\r\n".utf8)
        data.append(body)
        return data
    }

    private func exchange(_ fragments: [Data]) async -> String {
        let finished = expectation(description: "HTTP response closes the connection")
        let client = HTTPTestClient(port: port, fragments: fragments, finished: finished)
        client.start()
        await fulfillment(of: [finished], timeout: 5)
        client.connection.cancel()
        return String(data: client.response, encoding: .utf8) ?? "Invalid UTF-8 response"
    }
}

private final class HTTPTestClient {
    let connection: NWConnection
    private let queue = DispatchQueue(label: "GameHTTPTransportTests.client")
    private let fragments: [Data]
    private let finished: XCTestExpectation
    private(set) var response = Data()

    init(port: UInt16, fragments: [Data], finished: XCTestExpectation) {
        self.connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
        self.fragments = fragments
        self.finished = finished
    }

    func start() {
        self.connection.stateUpdateHandler = { [weak self] state in
            guard let self, case .ready = state else { return }
            self.receive()
            self.sendFragment(at: 0)
        }
        self.connection.start(queue: self.queue)
    }

    private func sendFragment(at index: Int) {
        guard index < self.fragments.count else { return }
        self.connection.send(content: self.fragments[index], completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else { return }
            self.queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.sendFragment(at: index + 1)
            }
        })
    }

    private func receive() {
        self.connection
            .receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
                guard let self else { return }
                if let data {
                    self.response.append(data)
                }
                if complete || error != nil {
                    self.finished.fulfill()
                } else {
                    self.receive()
                }
            }
    }
}

private final class RecordingCommandDelegate: GameCommandDelegate {
    private(set) var values: [String] = []

    func getCurrentGameState() -> GameCommandServer.GameState {
        .init(
            scene: "TestScene",
            score: 0,
            lives: 1,
            resources: 0,
            elapsedTime: 0,
            gameStatus: "playing",
            isPaused: false,
            playerPosition: nil,
            hermesPosition: nil,
            enemyCount: 0
        )
    }

    func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
        []
    }

    func captureScreenshot() -> Data? {
        nil
    }

    func injectTap(at point: CGPoint) -> Bool {
        false
    }

    func executeAction(name: String, params: [String: String]?) -> ActionResult {
        self.values.append(params?["value"] ?? "")
        return .success()
    }
}
