//
//  Attachment.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import Foundation
import UIKit
import PhotosUI
import SwiftUI
import BaseStyle
import FirebaseFirestore

public struct Feedback: Codable {

    @DocumentID public var id: String? // Automatically generated ID by Firestore

    var title: String
    var description: String
    var userId: String
    var attachmentUrls: [String]?
    var appVersion: String
    var deviceName: String
    var deviceOsVersion: String
    var createdAt: Timestamp

    public init(title: String, description: String, userId: String, attachmentUrls: [String]? = nil,
                appVersion: String, deviceName: String, deviceOsVersion: String, createdAt: Timestamp = Timestamp()) {
        self.title = title
        self.description = description
        self.userId = userId
        self.attachmentUrls = attachmentUrls
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.deviceOsVersion = deviceOsVersion
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case userId = "user_id"
        case attachmentUrls = "attachment_urls"
        case appVersion = "app_version"
        case deviceName = "device_name"
        case deviceOsVersion = "device_os_version"
        case createdAt = "created_at"
    }
}

public struct Attachment {
    public var id = UUID().uuidString
    public var image: UIImage?
    public var videoData: Data?
    public var video: URL?
    public var name: String

    public init(id: String = UUID().uuidString, image: UIImage? = nil, videoData: Data? = nil, video: URL? = nil, name: String) {
        self.id = id
        self.image = image
        self.videoData = videoData
        self.video = video
        self.name = name
    }
}

public struct AttachmentData {
    public var data: Data
    public var attachment: Attachment

    public init(data: Data, attachment: Attachment) {
        self.data = data
        self.attachment = attachment
    }
}

public struct AttachmentInfo {
    public var id = UUID().uuidString
    public var url: String

    public init(id: String = UUID().uuidString, url: String) {
        self.id = id
        self.url = url
    }
}

public struct MultipleImageSelectionPickerView: UIViewControllerRepresentable {
    let onDismiss: ([Attachment]) -> Void

    @Binding var isPresented: Bool

    public init(onDismiss: @escaping ([Attachment]) -> Void, isPresented: Binding<Bool>) {
        self.onDismiss = onDismiss
        self._isPresented = isPresented
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 10
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // Nothing to update here
    }

    public func makeCoordinator() -> MultipleImageSelectionPickerViewCoordinator {
        MultipleImageSelectionPickerViewCoordinator(onDismiss: onDismiss, isPresented: $isPresented)
    }

    public class MultipleImageSelectionPickerViewCoordinator: NSObject, PHPickerViewControllerDelegate {
        let onDismiss: ([Attachment]) -> Void
        @Binding var isPresented: Bool

        let imageManager = PHImageManager.default()
        let imageRequestOptions = PHImageRequestOptions()

        public init(onDismiss: @escaping ([Attachment]) -> Void, isPresented: Binding<Bool>) {
            self.onDismiss = onDismiss
            self._isPresented = isPresented
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            imageRequestOptions.isSynchronous = true
            var attachments: [Attachment] = []

            let dispatchGroup = DispatchGroup()

            for attachment in results {
                if attachment.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    dispatchGroup.enter()

                    attachment.itemProvider.loadObject(ofClass: UIImage.self) { newImage, error in
                        if let selectedImage = newImage as? UIImage, let fileName = attachment.itemProvider.suggestedName {
                            let imageObject = Attachment(image: selectedImage.resizeImageIfNeededWhilePreservingAspectRatio(), name: fileName)
                            attachments.append(imageObject)
                        } else if let error = error {
                            LogE("Error in loading image \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                } else if attachment.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    dispatchGroup.enter()

                    attachment.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in // it will return the temporary file address, so immediately retrieving video as data from the temporary url.
                        if let url = url, let fileName = attachment.itemProvider.suggestedName {
                            do {
                                let data = try Data(contentsOf: url)
                                let videoObject = Attachment(videoData: data, video: url, name: fileName)
                                attachments.append(videoObject)
                            } catch {
                                LogE("Error loading data from URL: \(error.localizedDescription)")
                            }
                        } else if let error = error {
                            LogE("Error in loading video: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.isPresented = false
                self.onDismiss(attachments)
            }
        }
    }
}
