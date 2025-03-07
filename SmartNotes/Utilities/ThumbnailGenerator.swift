//
//  ThumbnailGenerator.swift
//  SmartNotes
//
//  Created on 2/25/25.
//  Updated to integrate with EventStore architecture
//
//  This file generates thumbnail images from note drawing data.
//  Key responsibilities:
//    - Rendering PKDrawing data to UIImage thumbnails
//    - Caching thumbnails for performance
//    - Creating placeholder images for empty notes
//    - Handling drawing data conversion errors
//    - Publishing thumbnail events to EventBus
//
//  These thumbnails are used in the NotePreviewsGrid and NotePreviewCard
//  views to show note content in the UI.
//

import SwiftUI
import PencilKit
import Combine

// Thumbnail-related events
struct ThumbnailGeneratedEvent: Event {
    static var description: String = "Thumbnail was generated for a note"
    let noteID: UUID
    let image: UIImage
}

struct ThumbnailInvalidatedEvent: Event {
    static var description: String = "Thumbnail was invalidated for a note"
    let noteID: UUID
}

// Redefine the caching structures with proper type safety
struct CacheEntry {
    let image: UIImage
    let timestamp: Date
}

struct ThumbnailGenerator { 
    // The event bus for publishing events
    private static let eventBus = EventBus.shared
    
    // Legacy cache - to be phased out in favor of ResourceManager
    // This is kept for backward compatibility during migration
    private static var legacyCache: [String: CacheEntry] = [:]
    private static let minimumGenerationInterval: TimeInterval = 1.0 // 1 second between generations
    
    // Cache management methods
    private static func getCachedThumbnail(for noteID: UUID) -> UIImage? {
        // First try to get from the ResourceManager
        if let cachedImage = ResourceManager.shared.retrieveNoteThumbnail(forNote: noteID) {
            return cachedImage
        }
        
        // Fall back to legacy cache if not found in ResourceManager
        let key = noteID.uuidString
        guard let entry = legacyCache[key] else { return nil }
        
        // Migrate to ResourceManager on access
        ResourceManager.shared.storeNoteThumbnail(entry.image, forNote: noteID)
        
        return entry.image
    }
    
    private static func saveThumbnailToCache(noteID: UUID, image: UIImage) {
        // Save to ResourceManager
        ResourceManager.shared.storeNoteThumbnail(image, forNote: noteID)
        
        // Also save to legacy cache for backwards compatibility
        let key = noteID.uuidString
        let entry = CacheEntry(image: image, timestamp: Date())
        legacyCache[key] = entry
        
        // Publish an event that a thumbnail was generated
        eventBus.publish(ThumbnailGeneratedEvent(noteID: noteID, image: image))
    }
    
    private static func wasRecentlyGenerated(for noteID: UUID) -> Bool {
        let key = noteID.uuidString
        guard let entry = legacyCache[key] else { return false }
        return Date().timeIntervalSince(entry.timestamp) < minimumGenerationInterval
    }
    
    static func clearCache(for noteID: UUID? = nil) {
        if let noteID = noteID {
            legacyCache.removeValue(forKey: noteID.uuidString)
            ResourceManager.shared.removeResource(forKey: noteID.uuidString, type: .noteThumbnail)
            
            // Publish an event that a thumbnail was invalidated
            eventBus.publish(ThumbnailInvalidatedEvent(noteID: noteID))
        } else {
            legacyCache.removeAll()
            ResourceManager.shared.removeAllResources(ofType: .noteThumbnail)
        }
    }
    
    // Invalidate the thumbnail for a specific note
    static func invalidateThumbnail(for noteID: UUID) {
        legacyCache.removeValue(forKey: noteID.uuidString)
        ResourceManager.shared.removeResource(forKey: noteID.uuidString, type: .noteThumbnail)
        print("🖼️ Thumbnail cache invalidated for note: \(noteID)")
        
        // Publish an event that a thumbnail was invalidated
        eventBus.publish(ThumbnailInvalidatedEvent(noteID: noteID))
    }
    
    // Clears all cached thumbnails - use sparingly
    static func clearAllCaches() {
        legacyCache.removeAll()
        ResourceManager.shared.removeAllResources(ofType: .noteThumbnail)
        print("🧹 All thumbnail caches cleared")
    }
    
    // Listen for note changes from EventStore and invalidate thumbnails accordingly
    static func setupEventListeners(eventStore: EventStore) {
        // Listen for note updates
        eventStore.events
            .compactMap { $0 as? NoteAction }
            .sink { action in
                switch action {
                case .updateNote(let note, _), .addNote(let note, _):
                    invalidateThumbnail(for: note.id)
                case .deleteNote(let noteID, _):
                    invalidateThumbnail(for: noteID)
                default:
                    break
                }
            }
            .store(in: &ResourceManager.shared.cancellables)
        
        // Listen for page updates
        eventStore.events
            .compactMap { $0 as? PageAction }
            .sink { action in
                switch action {
                case .updatePage(_, let noteID, _), 
                     .addPage(_, let noteID, _),
                     .deletePage(_, let noteID, _),
                     .updateDrawingData(_, _, let noteID, _),
                     .clearPage(_, let noteID, _):
                    invalidateThumbnail(for: noteID)
                default:
                    break
                }
            }
            .store(in: &ResourceManager.shared.cancellables)
    }
    
    static func generateThumbnail(
        from note: Note,
        size: CGSize = CGSize(width: 300, height: 200),
        highQuality: Bool = true
    ) -> UIImage {
        // Check if we've recently generated this thumbnail - anti-loop protection
        if wasRecentlyGenerated(for: note.id) {
            // Too soon to regenerate, return cached version if available
            if let cachedImage = getCachedThumbnail(for: note.id) {
                print("🖼️ Using cached thumbnail (throttled)")
                return cachedImage
            }
        }
        
        print("🖼️ Generating thumbnail for note: \(note.id)")
        
        // Check if we have a cached thumbnail
        if let cachedImage = getCachedThumbnail(for: note.id) {
            print("🖼️ Using cached thumbnail")
            return cachedImage
        }
        
        // Create placeholder image for empty notes
        let createPlaceholder = {
            print("🖼️ Creating placeholder image")
            let placeholder = createPlaceholderImage(size: size, title: note.title)
            saveThumbnailToCache(noteID: note.id, image: placeholder)
            return placeholder
        }
        
        // Check if there's any drawing data in the note
        let hasLegacyContent = !note.drawingData.isEmpty
        let pageCount = note.pages.count
        
        print("🖼️ Note has legacy content: \(hasLegacyContent)")
        print("🖼️ Note pages count: \(pageCount)")
        
        // Determine if the first page has content
        var hasPageContent = false
        if pageCount > 0, let firstPage = note.pages.first {
            hasPageContent = !firstPage.drawingData.isEmpty
            print("🖼️ Note has page content: \(hasPageContent)")
        } else {
            print("🖼️ Note has no valid pages")
        }
        
        let hasContent = hasLegacyContent || hasPageContent
        if !hasContent {
            return createPlaceholder()
        }
        
        // Get drawing data from the note
        var drawingData: Data?
        if hasPageContent, let firstPage = note.pages.first {
            drawingData = firstPage.drawingData
            print("🖼️ Using drawing data from first page: \(drawingData?.count ?? 0) bytes")
        } else if hasLegacyContent {
            drawingData = note.drawingData
            print("🖼️ Using legacy drawing data: \(drawingData?.count ?? 0) bytes")
        }
        
        // Check if we have valid drawing data
        guard let validDrawingData = drawingData, !validDrawingData.isEmpty else {
            return createPlaceholder()
        }
        
        // Generate the actual thumbnail
        do {
            // Decode the PKDrawing
            let drawing = try PKDrawing(data: validDrawingData)
            let strokeCount = drawing.strokes.count
            print("🖼️ Stroke count: \(strokeCount)")
            
            // If no strokes, return a placeholder
            if strokeCount == 0 {
                return createPlaceholder()
            }
            
            // Set up rendering parameters
            let standardPageRect = CGRect(
                origin: .zero,
                size: GlobalSettings.standardPageSize
            )
            
            let resolutionFactor = ResolutionManager.shared.resolutionScaleFactor
            let qualityMultiplier = highQuality ? resolutionFactor : min(1.5, resolutionFactor)
            
            let targetSize = CGSize(
                width: size.width * qualityMultiplier,
                height: size.height * qualityMultiplier
            )
            
            // Calculate scale based on aspect ratio
            let scale = min(
                targetSize.width / standardPageRect.width,
                targetSize.height / standardPageRect.height
            )
            
            let renderScale: CGFloat = max(scale, 0.4 * resolutionFactor)
            
            // Render the drawing
            UIGraphicsBeginImageContextWithOptions(
                targetSize,
                true,
                UIScreen.main.scale * resolutionFactor
            )
            
            // Fill background with white
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate centered position
            let drawingSize = CGSize(
                width: standardPageRect.width * renderScale,
                height: standardPageRect.height * renderScale
            )
            
            let xOffset = (targetSize.width - drawingSize.width) / 2
            let yOffset = (targetSize.height - drawingSize.height) / 2
            
            // Render to image
            let drawingImage = drawing.image(from: standardPageRect, scale: renderScale)
            drawingImage.draw(in: CGRect(origin: CGPoint(x: xOffset, y: yOffset), size: drawingSize))
            
            guard let result = UIGraphicsGetImageFromCurrentImageContext() else {
                UIGraphicsEndImageContext()
                return createPlaceholder()
            }
            
            UIGraphicsEndImageContext()
            
            // Cache the result
            saveThumbnailToCache(noteID: note.id, image: result)
            return result
            
        } catch {
            print("🖼️ Error converting drawing data: \(error)")
            return createPlaceholder()
        }
    }
    
    // Create a placeholder image for empty notes
    static private func createPlaceholderImage(size: CGSize, title: String) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        let context = UIGraphicsGetCurrentContext()
        
        // Fill with light gray background
        context?.setFillColor(UIColor.systemGray6.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        // Draw a placeholder text with the note title
        let displayTitle = title.isEmpty ? "Untitled Note" : title
        let font = UIFont.systemFont(ofSize: 16 * min(1.5, ResolutionManager.shared.resolutionScaleFactor))
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let textSize = displayTitle.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        displayTitle.draw(in: textRect, withAttributes: textAttributes)
        
        guard let result = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }
        
        UIGraphicsEndImageContext()
        return result
    }
}

extension Image {
    /// A custom initializer that calls SwiftUI's built-in `init(uiImage:)`.
    /// We rename it slightly to avoid recursion issues.
    init(fromUIImage uiImage: UIImage) {
        self.init(uiImage: uiImage)
    }
}

// Add extension to ResourceManager to store thumbnails
extension ResourceManager {
    // Cancellables for event subscribers
    fileprivate var cancellables: Set<AnyCancellable> {
        get {
            if let existing = getAssociatedObject(self, key: "cancellables") as? Set<AnyCancellable> {
                return existing
            }
            let newSet = Set<AnyCancellable>()
            setAssociatedObject(self, key: "cancellables", value: newSet)
            return newSet
        }
        set {
            setAssociatedObject(self, key: "cancellables", value: newValue)
        }
    }
    
    func retrieveNoteThumbnail(forNote noteID: UUID) -> UIImage? {
        return retrieveResource(forKey: noteID.uuidString, type: .noteThumbnail) as? UIImage
    }
    
    func storeNoteThumbnail(_ image: UIImage, forNote noteID: UUID) {
        storeResource(image, forKey: noteID.uuidString, type: .noteThumbnail)
    }
}

// For associated object handling
private func getAssociatedObject<T>(_ object: Any, key: String) -> T? {
    let address = Unmanaged.passUnretained(object as AnyObject).toOpaque()
    let keyPtr = UnsafeRawPointer(key.utf8CString.withUnsafeBufferPointer { $0.baseAddress! })
    return objc_getAssociatedObject(address, keyPtr) as? T
}

private func setAssociatedObject<T>(_ object: Any, key: String, value: T) {
    let address = Unmanaged.passUnretained(object as AnyObject).toOpaque()
    let keyPtr = UnsafeRawPointer(key.utf8CString.withUnsafeBufferPointer { $0.baseAddress! })
    objc_setAssociatedObject(address, keyPtr, value, .OBJC_ASSOCIATION_RETAIN)
}
