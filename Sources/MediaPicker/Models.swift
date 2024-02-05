//
//  File.swift
//  
//
//  Created by Shubham Joshi on 03/02/24.
//


import PhotosUI

public typealias KiloByte = Int64
public struct MediaPickerConfiguration {
    public var maxSelection: Int = 1
    public var videoCompressionQuality: VideoCompressionQuality = .none
    public var maxImageSizeInKB: Int64 = .max
    public var maxVideoSizeInKB: Int64 = .max
    public var filters: PHPickerFilter = .any(of: [.images])
    public var preCompressionSizeValidation = false
    public var supportedFormated: [String] = []
    public init() {}
}
public struct PickerSelection: Identifiable {
    public var id = UUID().uuidString
    public var url: URL?
    public var mediaType: PickerSelectionType
    public var mimeType: String?
    public var error: Error?
}
public enum PickerSelectionType {
    case video
    case image
    case error
}
public enum MediaPickerError: Error {
    case importFailed
    case emptyMediaSelection
    case tranferFailed
    case undeterminedMedia
    case unsupportedFormat
    case sizeExceeds(size: Int64)
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

