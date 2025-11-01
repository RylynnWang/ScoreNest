import Foundation
import SwiftData

// MARK: - App Data JSON Schema

struct AppDataPackage: Codable {
    var version: Int
    var exportedAt: Date
    var scores: [ScoreExport]
}

struct ScoreExport: Codable {
    var id: UUID
    var title: String
    var createdAt: Date
    var pages: [ScorePageExport]
    var timeline: TimelineExport?
}

struct ScorePageExport: Codable {
    var id: UUID
    // Only store the last path component; importer will resolve to Application Support/ScoreNestImages
    var imageName: String
    var pageNumber: Int
    var note: String?
}

struct TimelineExport: Codable {
    var id: UUID
    var title: String
    var baseScoreDurationSec: Double
    var defaultWidthRatio: Double
    var createdAt: Date
    var segments: [SegmentExport]
}

struct SegmentExport: Codable {
    var id: UUID
    var sourcePageId: UUID?
    var cropRectNormalized: RectSpec?
    var speedFactor: Double
    var order: Int
}

// MARK: - IO Helpers

enum AppDataIOError: Error {
    case documentDirNotFound
    case appSupportDirNotFound
    case manifestMissing
    case imagesDirMissing
    case decodeFailed
}

enum AppDataImportResult {
    case success(importedScores: Int, importedPages: Int, importedSegments: Int)
}

enum AppDataExportResult {
    case success(packageURL: URL)
}

enum AppDataIO {
    // Centralized images subdirectory name
    static let imagesSubdirectory = "ScoreNestImages"

    // MARK: Export
    static func exportAll(toDocumentsWithName name: String, modelContext: ModelContext) throws -> AppDataExportResult {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AppDataIOError.documentDirNotFound
        }

        let packageURL = documents.appendingPathComponent(name, isDirectory: true)

        // Remove existing package if any
        if fm.fileExists(atPath: packageURL.path) {
            try fm.removeItem(at: packageURL)
        }

        // Create package directories
        try fm.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let imagesOut = packageURL.appendingPathComponent("images", isDirectory: true)
        try fm.createDirectory(at: imagesOut, withIntermediateDirectories: true)

        // Build JSON manifest from current store
        let manifest = try buildManifest(modelContext: modelContext)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        let manifestURL = packageURL.appendingPathComponent("manifest.json", isDirectory: false)
        try data.write(to: manifestURL, options: [.atomic])

        // Copy images from Application Support/ScoreNestImages to package/images
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppDataIOError.appSupportDirNotFound
        }
        let imagesDir = appSupport.appendingPathComponent(imagesSubdirectory, isDirectory: true)
        if fm.fileExists(atPath: imagesDir.path) {
            let urls = try fm.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for url in urls {
                let dst = imagesOut.appendingPathComponent(url.lastPathComponent)
                // Overwrite if exists
                if fm.fileExists(atPath: dst.path) {
                    try fm.removeItem(at: dst)
                }
                try fm.copyItem(at: url, to: dst)
            }
        }

        return .success(packageURL: packageURL)
    }

    private static func buildManifest(modelContext: ModelContext) throws -> AppDataPackage {
        let fd = FetchDescriptor<MusicScore>()
        let scores = try modelContext.fetch(fd)

        let scoreExports: [ScoreExport] = scores.map { score in
            let pages: [ScorePageExport] = score.pages.map { p in
                let comps = p.imageFileName.split(separator: "/")
                let imageName = comps.last.map(String.init) ?? p.imageFileName
                return ScorePageExport(id: p.id, imageName: imageName, pageNumber: p.pageNumber, note: p.note)
            }

            let timelineExport: TimelineExport? = {
                guard let tl = score.autoPlayTimeline else { return nil }
                let segments: [SegmentExport] = tl.segments.map { s in
                    SegmentExport(id: s.id, sourcePageId: s.sourcePage?.id, cropRectNormalized: s.cropRectNormalized, speedFactor: s.speedFactor, order: s.order)
                }
                return TimelineExport(id: tl.id, title: tl.title, baseScoreDurationSec: tl.baseScoreDurationSec, defaultWidthRatio: tl.defaultWidthRatio, createdAt: tl.createdAt, segments: segments)
            }()

            return ScoreExport(id: score.id, title: score.title, createdAt: score.createdAt, pages: pages, timeline: timelineExport)
        }

        return AppDataPackage(version: 1, exportedAt: Date(), scores: scoreExports)
    }

    // MARK: Import
    static func importFromPackage(at packageURL: URL, modelContext: ModelContext) throws -> AppDataImportResult {
        let fm = FileManager.default
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else { throw AppDataIOError.manifestMissing }
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(AppDataPackage.self, from: data) else { throw AppDataIOError.decodeFailed }

        // Copy images to Application Support/ScoreNestImages
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppDataIOError.appSupportDirNotFound
        }
        let imagesIn = packageURL.appendingPathComponent("images", isDirectory: true)
        guard fm.fileExists(atPath: imagesIn.path) else { throw AppDataIOError.imagesDirMissing }
        let imagesOut = appSupport.appendingPathComponent(imagesSubdirectory, isDirectory: true)
        if !fm.fileExists(atPath: imagesOut.path) {
            try fm.createDirectory(at: imagesOut, withIntermediateDirectories: true)
        }

        let imageURLs = try fm.contentsOfDirectory(at: imagesIn, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for url in imageURLs {
            let dst = imagesOut.appendingPathComponent(url.lastPathComponent)
            if !fm.fileExists(atPath: dst.path) {
                try fm.copyItem(at: url, to: dst)
            }
        }

        // Upsert models by UUID to avoid duplicates
        var importedScores = 0
        var importedPages = 0
        var importedSegments = 0

        // Preload existing items by id
        let existingScores = try modelContext.fetch(FetchDescriptor<MusicScore>())
        var scoreById = Dictionary(uniqueKeysWithValues: existingScores.map { ($0.id, $0) })
        var pageById = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ScorePage>()).map { ($0.id, $0) })
        var timelineById = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<AutoPlayTimeline>()).map { ($0.id, $0) })
        var segmentById = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<AutoPlaySegment>()).map { ($0.id, $0) })

        for se in manifest.scores {
            let score: MusicScore
            if let existing = scoreById[se.id] {
                score = existing
            } else {
                score = MusicScore(id: se.id, title: se.title, createdAt: se.createdAt, pages: [])
                modelContext.insert(score)
                importedScores += 1
                scoreById[se.id] = score
            }

            // Pages
            for pe in se.pages {
                if pageById[pe.id] == nil {
                    let relPath = NSString.path(withComponents: [imagesSubdirectory, pe.imageName])
                    let page = ScorePage(id: pe.id, imageFileName: relPath, pageNumber: pe.pageNumber, note: pe.note, score: score)
                    score.pages.append(page)
                    modelContext.insert(page)
                    importedPages += 1
                    pageById[pe.id] = page
                }
            }

            // Timeline
            if let te = se.timeline {
                let timeline: AutoPlayTimeline
                if let existingTL = timelineById[te.id] {
                    timeline = existingTL
                } else {
                    timeline = AutoPlayTimeline(id: te.id, title: te.title, baseScoreDurationSec: te.baseScoreDurationSec, defaultWidthRatio: te.defaultWidthRatio, createdAt: te.createdAt, segments: [], score: score)
                    score.autoPlayTimeline = timeline
                    modelContext.insert(timeline)
                    timelineById[te.id] = timeline
                }

                // Segments
                for se in te.segments {
                    if segmentById[se.id] == nil {
                        let seg = AutoPlaySegment(id: se.id, sourcePage: se.sourcePageId.flatMap { pageById[$0] }, cropRectNormalized: se.cropRectNormalized, speedFactor: se.speedFactor, order: se.order, timeline: timeline)
                        timeline.segments.append(seg)
                        modelContext.insert(seg)
                        importedSegments += 1
                        segmentById[se.id] = seg
                    }
                }
            }
        }

        try modelContext.save()
        return .success(importedScores: importedScores, importedPages: importedPages, importedSegments: importedSegments)
    }
}