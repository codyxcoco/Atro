import Foundation
import XCTest
@testable import Atro

@MainActor
final class AtroAppTests: XCTestCase {
    func testEnsurePersistentStoreDirectoryCreatesMissingParentFolders() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = rootURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Atro.store", isDirectory: false)
        let directoryURL = storeURL.deletingLastPathComponent()

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.path))

        try AtroApp.ensurePersistentStoreDirectory(for: storeURL)

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)

        XCTAssertNoThrow(try AtroApp.ensurePersistentStoreDirectory(for: storeURL))
    }

    func testResolvedPersistentStoreURLPrefersCurrentStoreWhenItExists() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let currentStoreURL = rootURL.appendingPathComponent("Atro.store", isDirectory: false)
        let legacyStoreURL = rootURL.appendingPathComponent("default.store", isDirectory: false)

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("current".utf8).write(to: currentStoreURL)
        try Data("legacy".utf8).write(to: legacyStoreURL)

        let resolvedURL = AtroApp.resolvedPersistentStoreURL(for: currentStoreURL)

        XCTAssertEqual(resolvedURL, currentStoreURL)
    }

    func testResolvedPersistentStoreURLFallsBackToLegacyStore() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let currentStoreURL = rootURL.appendingPathComponent("Atro.store", isDirectory: false)
        let legacyStoreURL = rootURL.appendingPathComponent("default.store", isDirectory: false)

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: legacyStoreURL)

        let resolvedURL = AtroApp.resolvedPersistentStoreURL(for: currentStoreURL)

        XCTAssertEqual(resolvedURL, legacyStoreURL)
    }
}
