//
//  File.swift
//  
//
//  Created by Shubham Joshi on 03/02/24.
//


import PhotosUI

public typealias KiloByte = Int64
public struct FilePickerConfiguration {
    public var maxSelection: Int = 1
    public var supportedFormat: [UTType] = [.pdf]
    public var maxSizeInKB: Int64 = .max
}
public struct MediaPickerConfiguration {
    public var maxSelection: Int = 1
    public var supportedFormat: [String] = []
    public var videoCompressionQuality: VideoCompressionQuality = .none
    public var maxImageSizeInKB: Int64 = .max
    public var maxVideoSizeInKB: Int64 = .max
    public var filters: PHPickerFilter = .any(of: [.images])
    public var preCompressionSizeValidation = false
    public init() {}
}
public struct PickerSelection: Identifiable {
    public var id = UUID().uuidString
    public var url: URL?
    public var mediaType: PickerSelectionType
    public var mimeType: String?
    public var error: Error?
    // Return nil in case of image and file
    public func getThumbnail() -> UIImage? {
        if mediaType == .video, let url = self.url {
            let asset: AVAsset = AVAsset(url: url)
            return asset.generateThumbnail()
        } else {
            return nil
        }
    }
}
public enum PickerSelectionType {
    case video
    case image
    case file
    case error
}
public enum MediaPickerError: Error {
    case importFailed
    case emptyMediaSelection
    case tranferFailed
    case undeterminedMedia
    case sizeExceeds(size: KiloByte)
    case maxSelectionExceeds(selectedCount: Int)
    case unsupportedFormat
}

public enum VideoCompressionQuality {
    case none
    case low
    case medium
    case high
    case hevcHigh
    
    var value: String {
        switch self {
        case .hevcHigh: return AVAssetExportPresetHEVCHighestQuality
        case .high: return AVAssetExportPresetHighestQuality
        case .low: return AVAssetExportPresetLowQuality
        case .medium: return AVAssetExportPresetMediumQuality
        case .none: return "none"
        }
    }
}

extension AVAsset {
    func generateThumbnail() -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true
        do {
            let thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 60), actualTime: nil)
            let uiImage = UIImage(cgImage: thumbnailImage)
            return uiImage
        } catch let error {
            print(error)
        }
        return nil
    }
}
