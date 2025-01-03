//
//  FeedbackViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import SwiftUI
import Data
import BaseStyle

class FeedbackViewModel: BaseViewModel, ObservableObject {
    private let TITLE_CHARACTER_MIN_LIMIT = 3
    private let VIDEO_SIZE_LIMIT_IN_BYTES = 5000000 // 5 MB

    @Inject private var preference: SplitoPreference
    @Inject private var feedbackRepository: FeedbackRepository

    @Published var description: String = ""
    @Published private(set) var currentState: ViewState = .initial
    @Published private var uploadedAttachmentIDs: Set<String> = Set<String>()

    @Published var failedAttachments: [Attachment] = []
    @Published var attachmentsUrls: [(id: String, url: String)] = []
    @Published var selectedAttachments: [Attachment] = []
    @Published var uploadingAttachments: [Attachment] = []

    @Published var showImagePicker: Bool = false
    @Published var showImagePickerOption: Bool = false
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var isValidTitle: Bool = false
    @Published private(set) var shouldShowValidationMessage: Bool = false

    @Published var title: String = "" {
        didSet {
            isValidTitle = title.count >= TITLE_CHARACTER_MIN_LIMIT
        }
    }

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
        guard isValidTitle else {
            shouldShowValidationMessage = true
            return
        }

        let feedback = Feedback(title: title, description: description, userId: userId,
                                attachmentUrls: attachmentsUrls.map { $0.url }, appVersion: DeviceInfo.appVersionName,
                                deviceName: UIDevice.current.name, deviceOsVersion: UIDevice.current.systemVersion)
        sendFeedback(feedback: feedback)
    }

    private func sendFeedback(feedback: Feedback) {
        Task { [weak self] in
            do {
                self?.showLoader = true
                try await self?.feedbackRepository.addFeedback(feedback: feedback)
                self?.showLoader = false
                self?.showAlert = true
                self?.alert = .init(message: "Thanks! your feedback has been recorded.",
                                    positiveBtnTitle: "Ok",
                                    positiveBtnAction: { [weak self] in self?.router.pop() })
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
        guard let index = selectedAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }

        if let urlIndex = attachmentsUrls.firstIndex(where: { $0.id == attachment.id }) {
            deleteAttachment(urlIndex: urlIndex, attachment: attachment, index: index)
        }
    }

    private func deleteAttachment(urlIndex: Int, attachment: Attachment, index: Int) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.feedbackRepository.deleteAttachment(attachmentUrl: attachmentsUrls[urlIndex].url)
                withAnimation {
                    self.attachmentsUrls.remove(at: urlIndex)
                    self.selectedAttachments.remove(at: index)
                    self.uploadingAttachments.removeAll { $0.id == self.selectedAttachments[index].id }
                }
                LogD("FeedbackViewModel: \(#function) Attachment deleted successfully.")
            } catch {
                LogE("FeedbackViewModel: \(#function) Failed to delete attachment: \(error)")
                self.showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Failed to remove attachment."))
            }
        }
    }

    func onRetryAttachment(_ attachment: Attachment) {
        guard let index = selectedAttachments.firstIndex(where: { $0.id == attachment.id }) else { return }

        let retryAttachment = selectedAttachments[index]
        if let failedIndex = failedAttachments.firstIndex(where: { $0.id == retryAttachment.id }) {
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
            removeAllAttachments()
        case .camera, .remove:
            break
        }
    }

    private func removeAllAttachments() {
        Task { [weak self] in
            guard let self else { return }
            for attachment in self.attachmentsUrls {
                do {
                    try await self.feedbackRepository.deleteAttachment(attachmentUrl: attachment.url)
                    LogD("FeedbackViewModel: \(#function) Attachment deleted successfully.")
                } catch {
                    LogE("FeedbackViewModel: \(#function) Failed to delete attachment: \(error)")
                    self.showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Failed to remove attachment."))
                }
            }

            withAnimation {
                self.selectedAttachments.removeAll()
                self.uploadingAttachments.removeAll()
                self.attachmentsUrls.removeAll()
                self.failedAttachments.removeAll()
                self.uploadedAttachmentIDs.removeAll()
            }
        }
    }

    private func upload(attachment: Attachment) {
        if uploadedAttachmentIDs.contains(attachment.id) { return }

        if let imageData = attachment.image?.jpegRepresentationData {
            upload(data: imageData, attachment: attachment, type: .image)
        } else if let data = attachment.videoData {
            if data.count <= VIDEO_SIZE_LIMIT_IN_BYTES {
                upload(data: data, attachment: attachment, type: .video)
            } else {
                selectedAttachments.removeAll { $0.id == attachment.id }
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "The video size exceeds the maximum allowed limit. Please select a smaller video."))
            }
        }
    }

    private func upload(data: Data, attachment: Attachment, type: StorageManager.AttachmentType) {
        uploadingAttachments.append(attachment)

        Task { [weak self] in
            do {
                let attachmentId = attachment.id
                let attachmentUrl = try await self?.feedbackRepository.uploadAttachment(attachmentId: attachmentId, attachmentData: data, attachmentType: type)

                // Update attachment URLs with the uploaded URL
                if let attachmentUrl {
                    self?.attachmentsUrls.append((id: attachmentId, url: attachmentUrl))
                    self?.uploadingAttachments.removeAll { $0.id == attachmentId }
                }
            } catch {
                self?.failedAttachments.append(attachment)
                self?.uploadingAttachments.removeAll { $0.id == attachment.id }
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
    enum FocusedField {
        case title, description
    }
}
