// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import PhotosUI
import CoreTransferable

public class MediaPickerViewModel: ObservableObject {
    private var configuration = MediaPickerConfiguration()
    private var filePickerConfiguration = FilePickerConfiguration()
    @Published public var openFile = false
    @Published public var openCamera = false
    @Published public var arrayPickedAssets: [PickerSelection] = []
    @Published private var capturedAssetURL: URL? {
        didSet {
            loadCapturedMedia()
        }
    }
    @Published private var imageSelection: [PhotosPickerItem] = [] {
        didSet {
            if !imageSelection.isEmpty {
                loadTransferable(from: self.imageSelection)
            } else {
                arrayPickedAssets = []
            }
        }
    }
    public init() { }
    // MARK: - Photo Libs
    public func openImagePicker(maxSelection: Int = 1,
                                supportedFormat: [String] = [],
                                maxImageSizeInKB: Int64 = .max,
                                @ViewBuilder label: () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxSelection = maxSelection
        configuration.supportedFormat = supportedFormat
        configuration.maxImageSizeInKB = maxImageSizeInKB
        configuration.filters = .images
        return openMediaPicker(configuration: configuration) {
            label()
        }
    }
    public func openVideoPicker(maxSelection: Int = 1,
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
        return openMediaPicker(configuration: configuration) {
            label()
        }
    }
    public func openMediaPicker(filters: PHPickerFilter = .any(of: [.images, .videos]),
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
        return openMediaPicker(configuration: configuration) {
            label()
        }
    }
    public func openMediaPicker(configuration: MediaPickerConfiguration,
                                @ViewBuilder label: () -> some View) -> some View {
        self.configuration = configuration
        @ObservedObject var viewModel = self
        return PhotosPicker(selection: $viewModel.imageSelection,
                            maxSelectionCount: configuration.maxSelection,
                            matching: configuration.filters,
                            photoLibrary: .shared()) {
            label()
        }
    }
    
    // MARK: - File Picker
    public func filePicker(maxSelection: Int = 1,
                               maxSizeInKB: Int64 = .max,
                               supportedFormat: [UTType] = [.pdf, .html],
                               label: () -> some View) -> some View {
        var configuration = FilePickerConfiguration()
        configuration.maxSelection = maxSelection
        configuration.maxSizeInKB = maxSizeInKB
        configuration.supportedFormat = supportedFormat
        return filePicker(configuration: configuration) {
            label()
        }
    }
    public func filePicker(configuration: FilePickerConfiguration? = nil, label: () -> some View) -> some View {
        self.filePickerConfiguration = configuration ?? FilePickerConfiguration()
        @ObservedObject var viewModel = self
        let importerView = label().fileImporter(isPresented: $viewModel.openFile, allowedContentTypes: filePickerConfiguration.supportedFormat,
                                                allowsMultipleSelection: filePickerConfiguration.maxSelection > 1) { result in
            var arrSelection: [PickerSelection] = []
            do {
                let fileURLs = try result.get()
                if fileURLs.count > self.filePickerConfiguration.maxSelection {
                    let pickerSelection = PickerSelection(mediaType: .error, error: MediaPickerError.maxSelectionExceeds(selectedCount: fileURLs.count))
                    arrSelection.append(pickerSelection)
                } else {
                    for url in fileURLs {
                        let _ = url.startAccessingSecurityScopedResource()
                        var fileName = "\(Date().timeIntervalSince1970)-"
                        fileName += url.lastPathComponent
                        let copy = FileManager.default.temporaryDirectory.appending(path: fileName)
                        try? FileManager.default.copyItem(at: url, to: copy)
                        if let mimeType = UTType(filenameExtension: url.pathExtension) {
                            let pickerSelection = self.checkSize(at: copy, mediaType: .file, utType: mimeType)
                            arrSelection.append(pickerSelection)
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                let pickerSelection = PickerSelection(mediaType: .error, error: error)
                arrSelection.append(pickerSelection)
            }
            self.arrayPickedAssets = arrSelection
        }
        return importerView
    }
    
    // MARK: - Camera
    public func captureImage(maxSizeInKB: Int64 = .max, label: @escaping () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxImageSizeInKB = maxSizeInKB
        return captureMedia(for: [.video], configuration: configuration, label: label)
    }
    public func captureVideo(maxSizeInKB: Int64 = .max,
                             videoCompressionQuality: VideoCompressionQuality = .none,
                             preCompressionSizeValidation: Bool = false,
                             label: @escaping () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxVideoSizeInKB = maxSizeInKB
        configuration.preCompressionSizeValidation = preCompressionSizeValidation
        configuration.videoCompressionQuality = videoCompressionQuality
        return captureMedia(for: [.video], configuration: configuration, label: label)
    }
    public func captureMedia(maxImageSizeInKB: Int64 = .max,
                             videoCompressionQuality: VideoCompressionQuality = .none,
                             maxVideoSizeInKB: Int64 = .max,
                             preCompressionSizeValidation: Bool = false,
                             label: @escaping () -> some View) -> some View {
        var configuration = MediaPickerConfiguration()
        configuration.maxImageSizeInKB = maxImageSizeInKB
        configuration.maxVideoSizeInKB = maxVideoSizeInKB
        configuration.preCompressionSizeValidation = preCompressionSizeValidation
        configuration.videoCompressionQuality = videoCompressionQuality
        return captureMedia(for: [.image, .video], configuration: configuration, label: label)
        
    }
    public func captureMedia(for mediaType: [UTType] = [.image, .video],
                             configuration: MediaPickerConfiguration? = nil,
                             label: @escaping () -> some View) -> some View {
        self.configuration = configuration ?? MediaPickerConfiguration()
        @ObservedObject var viewModel = self
        let camView = label().fullScreenCover(isPresented: $viewModel.openCamera, content: {
            CameraView(mediaURL: $viewModel.capturedAssetURL, mediaTypes: [.image, .movie])
                .edgesIgnoringSafeArea(.all)
        })
        return camView
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
            } else if let utType = selection.supportedContentTypes.first(where: {$0.conforms(to: .audiovisualContent)}) {
                progress = selection.loadTransferable(type: Movie.self) { result in
                    switch result {
                    case .success(let movie?):
                        let fileEx = utType.preferredFilenameExtension?.lowercased() ?? "-none"
                        if supportedFormat.isEmpty || supportedFormat.contains(fileEx) {
                            self.getVideo(sourceURL: movie.url, utType: utType) { selection in
                                arrayAssets.append(selection)
                                group.leave()
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
        var maxSize = Int64.max
        if mediaType ==  .image {
            maxSize = configuration.maxImageSizeInKB
        } else if mediaType == .video {
            maxSize = configuration.maxVideoSizeInKB
        } else if mediaType == .file {
            maxSize = filePickerConfiguration.maxSizeInKB
        }
        if size <= maxSize {
            return PickerSelection(url: sourceURL,
                                   mediaType: mediaType,
                                   mimeType: utType.preferredMIMEType)
        } else {
            let asset = PickerSelection(mediaType: .error, error: MediaPickerError.sizeExceeds(size: size))
            return asset
        }
    }
    private func loadCapturedMedia() {
        if let url = capturedAssetURL,
           let utType = UTType(filenameExtension: url.pathExtension ) {
            let mediaType: PickerSelectionType = utType.conforms(to: .image) ? .image : .video
            if mediaType == .video {
                getVideo(sourceURL: url, utType: utType) {video in
                    self.arrayPickedAssets = [video]
                }
            } else {
                let item = self.checkSize(at: url, mediaType: mediaType, utType: utType)
                arrayPickedAssets = [item]
            }
        }
    }
    private func getVideo(sourceURL: URL, utType: UTType, completion: @escaping ((PickerSelection)->())) {
        let compression = configuration.videoCompressionQuality
        if configuration.preCompressionSizeValidation {
            let asset = self.checkSize(at: sourceURL, mediaType: .video, utType: utType)
            completion(asset)
            return
        }
        if compression == .none {
            let asset = self.checkSize(at: sourceURL, mediaType: .video, utType: utType)
            completion(asset)
            return
        } else {
            self.compressVideo(sourceURL: sourceURL) { compressedVideoURL in
                var asset: PickerSelection
                if !self.configuration.preCompressionSizeValidation {
                    asset = self.checkSize(at: compressedVideoURL, mediaType: .video, utType: utType)
                } else {
                    asset = PickerSelection(url: compressedVideoURL,
                                            mediaType: .video,
                                            mimeType: utType.preferredMIMEType)
                }
                completion(asset)
            }
        }
    }
}


extension MediaPickerViewModel {
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
}
