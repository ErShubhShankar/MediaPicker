//
//  SwiftUIView.swift
//  
//
//  Created by Shubham Joshi on 16/02/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct CameraView: UIViewControllerRepresentable {
    @Binding var mediaURL: URL?
    @Environment(\.presentationMode) var isPresented
    var mediaTypes: [UTType]
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
        let types: [String] = mediaTypes.compactMap({$0.identifier})
        imagePicker.mediaTypes = types
        imagePicker.allowsEditing = false
        imagePicker.delegate = context.coordinator
        imagePicker.modalPresentationStyle = .fullScreen
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(picker: self)
    }
}

// Coordinator will help to preview the selected image in the View.
class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var picker: CameraView
    
    init(picker: CameraView) {
        self.picker = picker
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let imageKey: UIImagePickerController.InfoKey = picker.allowsEditing ? .editedImage : .originalImage
        if let selectedImage = info[imageKey] as? UIImage {
            let imageName = "Photo-\(Date().timeIntervalSince1970).jpeg"
            let filePath = FileManager.default.temporaryDirectory.appending(path: imageName)
            FileManager.default.createFile(atPath: filePath.path(), contents: selectedImage.pngData())
            self.picker.mediaURL = filePath
        } else if info[.mediaType] as? String == UTType.movie.identifier,
                  let url = info[.mediaURL] as? URL {
            self.picker.mediaURL = url
        }
        self.picker.isPresented.wrappedValue.dismiss()
    }
}
