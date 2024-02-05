// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import PhotosUI
import CoreTransferable

public class MediaPickerViewModel: ObservableObject {
    private var configuration = MediaPickerConfiguration()
    @Published public var arrayPickedAssets: [PickerSelection] = []
    @Published public var imageSelection: [PhotosPickerItem] = [] {
        didSet {
            if !imageSelection.isEmpty {
                loadTransferable(from: self.imageSelection)
            } else {
                arrayPickedAssets = []
            }
        }
    }
    struct Movie: Transferable {
        let url: URL
        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(contentType: .movie) { movie in
                SentTransferredFile(movie.url)
            } importing: { received in
                var videoName = "\(Date().timeIntervalSince1970)-"
                videoName += received.file.lastPathComponent
                let copy = FileManager.default.temporaryDirectory.appending(path: videoName)
                try FileManager.default.copyItem(at: received.file, to: copy)
                return Self.init(url: copy)
            }
        }
    }
    struct Photo: Transferable {
        let url: URL
        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(contentType: .image) { image in
                SentTransferredFile(image.url)
            } importing: { received in
                var imageName = "\(Date().timeIntervalSince1970)-"
                imageName += received.file.lastPathComponent
                let copy = FileManager.default.temporaryDirectory.appending(path: imageName)
                try FileManager.default.copyItem(at: received.file, to: copy)
                return Self.init(url: copy)
            }
        }
    }
    
    // MARK: - PUBLIC APIs
    public init() { }
    public func openImagePicker(selection: Binding<[PhotosPickerItem]>,
                                maxSelection: Int = 1,
                                supportedFormat: [String] = [],
                                maxImageSizeInKB: Int64 = .max,
                                @ViewBuilder label: () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxSelection = maxSelection
        configuration.supportedFormat = supportedFormat
        configuration.maxImageSizeInKB = maxImageSizeInKB
        configuration.filters = .images
        return openMediaPicker(selection: selection, configuration: configuration) {
            label()
        }
    }
    public func openVideoPicker(selection: Binding<[PhotosPickerItem]>,
                                maxSelection: Int = 1,
                                supportedFormat: [String] = [],
                                videoCompressionQuality: VideoCompressionQuality = .none,
                                maxVideoSizeInKB: Int64 = .max,
                                preCompressionSizeValidation: Bool = false,
                                @ViewBuilder label: () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxSelection = maxSelection
        configuration.supportedFormat = supportedFormat
        configuration.maxVideoSizeInKB = maxVideoSizeInKB
        configuration.preCompressionSizeValidation = preCompressionSizeValidation
        configuration.filters = .videos
        return openMediaPicker(selection: selection, configuration: configuration) {
            label()
        }
    }
    public func openMediaPicker(selection: Binding<[PhotosPickerItem]>,
                                filters: PHPickerFilter = .any(of: [.images, .videos]),
                                maxSelection: Int = 5,
                                supportedFormat: [String] = [],
                                maxImageSizeInKB: Int64 = .max,
                                videoCompressionQuality: VideoCompressionQuality = .none,
                                maxVideoSizeInKB: Int64 = .max,
                                preCompressionSizeValidation: Bool = false,
                                @ViewBuilder label: () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxSelection = maxSelection
        configuration.supportedFormat = supportedFormat
        configuration.filters = filters
        configuration.maxImageSizeInKB = maxImageSizeInKB
        configuration.maxVideoSizeInKB = maxVideoSizeInKB
        configuration.videoCompressionQuality = videoCompressionQuality
        configuration.preCompressionSizeValidation = preCompressionSizeValidation
        return openMediaPicker(selection: selection, configuration: configuration) {
            label()
        }
    }
    public func openMediaPicker(selection: Binding<[PhotosPickerItem]>, configuration: MediaPickerConfiguration, @ViewBuilder label: () -> some View) -> some View {
        self.configuration = configuration
        return PhotosPicker(selection: selection,
                            maxSelectionCount: configuration.maxSelection,
                            matching: configuration.filters,
                            photoLibrary: .shared()) {
            label()
        }
    }
    
    // MARK: - Private Methods
    @discardableResult
    private func loadTransferable(from imageSelection: [PhotosPickerItem]) -> Progress {
        let group = DispatchGroup()
        var arrayAssets: [PickerSelection] = []
        var progress = Progress()
        for selection in imageSelection {
            let supportedFormat = configuration.supportedFormat.map({$0.lowercased()})
            group.enter()
            if let utType = selection.supportedContentTypes.first(where: {$0.conforms(to: .image)}) {
                progress = selection.loadTransferable(type: Photo.self) { result in
                    switch result {
                    case .success(let photo?):
                        let fileEx = utType.preferredFilenameExtension?.lowercased() ?? "-none"
                        if supportedFormat.isEmpty || supportedFormat.contains(fileEx) {
                            let size = FileManager.default.sizeOfFile(atPath: photo.url.path())
                            if size <= self.configuration.maxImageSizeInKB {
                                arrayAssets.append(PickerSelection(url: photo.url, mediaType: .image, mimeType: utType.preferredMIMEType))
                            } else {
                                let asset = PickerSelection(mediaType: .error, error: MediaPickerError.sizeExceeds(size: size))
                                arrayAssets.append(asset)
                            }
                        } else {
                            let asset = PickerSelection(mediaType: .error, error: MediaPickerError.unsupportedFormat)
                            arrayAssets.append(asset)
                        }
                    case .success(nil):
                        let asset = PickerSelection(mediaType: .error, error: MediaPickerError.tranferFailed)
                        arrayAssets.append(asset)
                    case .failure(let error):
                        let asset = PickerSelection(mediaType: .error, error: error)
                        arrayAssets.append(asset)
                    }
                    group.leave()
                }
            } else if let utType = selection.supportedContentTypes.first(where: {$0.conforms(to: .movie)}) {
                progress = selection.loadTransferable(type: Movie.self) { result in
                    switch result {
                    case .success(let movie?):
                        let fileEx = utType.preferredFilenameExtension?.lowercased() ?? "-none"
                        if supportedFormat.isEmpty || supportedFormat.contains(fileEx) {
                            let compression = self.configuration.videoCompressionQuality
                            if self.configuration.preCompressionSizeValidation {
                                let asset = self.checkSize(at: movie.url, mediaType: .video, utType: utType)
                                if asset.mediaType == .error {
                                    arrayAssets.append(asset)
                                    group.leave()
                                    break
                                }
                            }
                            if compression == .none {
                                let asset = self.checkSize(at: movie.url, mediaType: .video, utType: utType)
                                arrayAssets.append(asset)
                                group.leave()
                            } else {
                                self.compressVideo(sourceURL: movie.url) { compressedVideoURL in
                                    var asset: PickerSelection
                                    if !self.configuration.preCompressionSizeValidation {
                                        asset = self.checkSize(at: compressedVideoURL, mediaType: .video, utType: utType)
                                    } else {
                                        asset = PickerSelection(url: compressedVideoURL,
                                                                mediaType: .video,
                                                                mimeType: utType.preferredMIMEType)
                                    }
                                    arrayAssets.append(asset)
                                    group.leave()
                                }
                            }
                        } else {
                            let asset = PickerSelection(mediaType: .error, error: MediaPickerError.unsupportedFormat)
                            arrayAssets.append(asset)
                            group.leave()
                        }
                    case .success(nil):
                        let asset = PickerSelection(mediaType: .error, error: MediaPickerError.tranferFailed)
                        arrayAssets.append(asset)
                        group.leave()
                    case .failure(let error):
                        let asset = PickerSelection(mediaType: .error, error: error)
                        arrayAssets.append(asset)
                        group.leave()
                    }
                }
            } else {
                let asset = PickerSelection(mediaType: .error, error: MediaPickerError.undeterminedMedia)
                arrayAssets.append(asset)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.arrayPickedAssets = arrayAssets
        }
        return progress
    }
    private func checkSize(at sourceURL: URL, mediaType: PickerSelectionType, utType: UTType) -> PickerSelection {
        let url = sourceURL.path(percentEncoded: false)
        let size = FileManager.default.sizeOfFile(atPath: url)
        let maxSize = mediaType == .image ? configuration.maxImageSizeInKB : configuration.maxVideoSizeInKB
        if size <= maxSize {
            return PickerSelection(url: sourceURL,
                                   mediaType: mediaType,
                                   mimeType: utType.preferredMIMEType)
        } else {
            let asset = PickerSelection(mediaType: .error, error: MediaPickerError.sizeExceeds(size: size))
            return asset
        }
    }
    public func compressVideo(sourceURL: URL, completion: @escaping ((URL) -> Void)) {
        let asset = AVAsset(url: sourceURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: configuration.videoCompressionQuality.value)
        var videoName = "Compressed-\(Date().timeIntervalSince1970)-"
        videoName += sourceURL.lastPathComponent
        let destinationURL = FileManager.default.temporaryDirectory.appending(path: videoName)
        exportSession?.outputURL = destinationURL
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true
        exportSession?.exportAsynchronously(completionHandler: {
            completion(destinationURL)
            try? FileManager.default.removeItem(at: sourceURL)
        })
    }
}
