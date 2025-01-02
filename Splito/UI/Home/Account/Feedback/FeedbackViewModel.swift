//
//  FeedbackViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import SwiftUI
import Combine
import Data
import BaseStyle

class FeedbackViewModel: BaseViewModel, ObservableObject {
    let TITLE_CHARACTER_MIN_LIMIT = 3
    let VIDEO_SIZE_LIMIT_IN_BYTES = 5000000 // 5 MB

    @Inject private var preference: SplitoPreference
    @Inject private var feedbackRepository: FeedbackRepository

    @Published var title: String = "" {
        didSet {
            isValidTitle = title.count >= TITLE_CHARACTER_MIN_LIMIT
        }
    }
    @Published var description: String = ""
    @Published private(set) var currentState: ViewState = .initial

    @Published var selectedAttachments: [Attachment] = []
    @Published var uploadingAttachments: [Attachment] = []
    @Published var attachmentsUrls: [AttachmentInfo] = []

    @Published private var uploadedAttachmentIDs: Set<String> = Set<String>()

    @Published var failedAttachments: [Attachment] = []
    @Published var showImagePicker = false
    @Published var showImagePickerOption = false
    @Published var isValidTitle: Bool = false
    @Published var shouldShowValidationMessage: Bool = false
    @Published private(set) var showLoader: Bool = false

    private var cancellable: [String: AnyCancellable] = [:]
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }
}

// MARK: - Action Items
extension FeedbackViewModel {
    func submitFeedback() {
        guard let userId = preference.user?.id else { return }

        shouldShowValidationMessage = true
        guard isValidTitle else { return }

        showLoader = true
        let attachmentUrl = attachmentsUrls.map { $0.url }
        let feedbackInfo = Feedback(title: title, description: description, userId: userId,
                                    attachmentUrls: attachmentUrl, appVersion: DeviceInfo.appVersionName,
                                    deviceName: UIDevice.current.name, deviceOsVersion: UIDevice.current.systemVersion)
        sendFeedback(feedbackInfo: feedbackInfo)
    }

    func sendFeedback(feedbackInfo: Feedback) {
        Task { [weak self] in
            do {
                self?.showLoader = true
                try await self?.feedbackRepository.addFeedback(feedback: feedbackInfo)
                self?.showLoader = false
                self?.showAlertFor(alert: .init(
                    message: "Thanks! your feedback has been recorded.",
                    positiveBtnTitle: "Ok",
                    positiveBtnAction: {
                        self?.showAlert = false
                        self?.router.pop()
                    }))
                LogD("FeedbackViewModel: \(#function) Feedback submitted successfully.")
            } catch {
                self?.showLoader = false
                self?.showToastForError()
                LogE("FeedbackViewModel: \(#function) Failed to submit feedback: \(error).")
            }
        }
    }

    func onImagePickerSheetDismiss(attachments: [Attachment]) {
        for attachment in attachments {
            selectedAttachments.append(attachment)
            upload(attachment: attachment)
        }
    }

    func handleAttachmentTap() {
        if selectedAttachments.isEmpty {
            showImagePicker = true
        } else {
            showImagePickerOption = true
        }
    }

    func onRemoveAttachment(_ attachment: Attachment) {
        guard let index = selectedAttachments.firstIndex(where: { $0.id == attachment.id }) else {
            return
        }

        if let token = cancellable.removeValue(forKey: attachment.id) {
            token.cancel()
        }

        if let urlIndex = attachmentsUrls.firstIndex(where: { $0.id == attachment.id }) {
            let attachmentUrl = attachmentsUrls[urlIndex].url
            attachmentsUrls.remove(at: urlIndex)
            deleteAttachment(attachmentUrl: attachmentUrl)
        }

        selectedAttachments.remove(at: index)
        uploadingAttachments.removeAll(where: { $0.id == attachment.id })
    }

    func deleteAttachment(attachmentUrl: String) {
        Task {
            do {
                try await feedbackRepository.deleteAttachment(attachmentUrl: attachmentUrl)
                LogD("FeedbackViewModel: \(#function) Attachment deleted successfully.")
            } catch {
                LogE("FeedbackViewModel: \(#function) Failed to delete attachment: \(error)")
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Failed to remove attachment."))
            }
        }
    }

    func onRetryAttachment(_ attachment: Attachment) {
        guard let index = selectedAttachments.firstIndex(where: { $0.id == attachment.id }) else {
            return
        }

        let retryAttachment = selectedAttachments[index]

        if let failedIndex = failedAttachments.firstIndex(where: { $0.id == retryAttachment.id }) { // Check if the attachment exists in the failedAttachments array
            failedAttachments.remove(at: failedIndex)
        }

        upload(attachment: retryAttachment)
        uploadedAttachmentIDs.insert(retryAttachment.id)
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .gallery:
            showImagePicker = true
        case .removeAll:
            selectedAttachments.removeAll()
        }
    }

    func upload(attachment: Attachment) {
        if uploadedAttachmentIDs.contains(attachment.id) {
            return
        }

        if let imageData = attachment.image?.jpegRepresentationData {
            let attachmentData = AttachmentData(data: imageData, attachment: attachment)
            upload(attachmentData: attachmentData, attachmentType: .image)
        } else if let data = attachment.videoData {
            if data.count <= VIDEO_SIZE_LIMIT_IN_BYTES {
                let attachmentData = AttachmentData(data: data, attachment: attachment)
                upload(attachmentData: attachmentData, attachmentType: .video)
            } else {
                selectedAttachments.removeAll { $0.id == attachment.id }
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "The video size exceeds the maximum allowed limit. Please select a smaller video."))
            }
        }
    }

    public func upload(attachmentData: AttachmentData, attachmentType: StorageManager.AttachmentType) {
        uploadingAttachments.append(attachmentData.attachment)

        Task {
            do {
                let attachmentId = attachmentData.attachment.id
                let attachmentUrl = try await feedbackRepository.uploadAttachment(attachmentId: attachmentId, attachmentData: attachmentData.data, attachmentType: attachmentType)

                // Update attachment URLs with the uploaded URL
                if let attachmentUrl {
                    self.attachmentsUrls.append(AttachmentInfo(id: attachmentId, url: attachmentUrl))
                    self.uploadingAttachments.removeAll { $0.id == attachmentId }
                }
            } catch {
                self.failedAttachments.append(attachmentData.attachment)
                self.uploadingAttachments.removeAll { $0.id == attachmentData.attachment.id }
                LogE("FeedbackViewModel: \(#function) Failed to upload attachment: \(error)")
            }
        }
    }
}

// MARK: - View's State
extension FeedbackViewModel {
    enum ViewState {
        case initial
        case loading
    }
}

extension FeedbackViewModel {
    enum ActionsOfSheet {
        case gallery
        case removeAll
    }
}

extension FeedbackViewModel {
    enum FocusedField {
        case title, description
    }
}
