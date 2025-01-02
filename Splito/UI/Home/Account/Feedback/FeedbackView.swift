//
//  FeedbackView.swift
//  Splito
//
//  Created by Nirali Sonani on 02/01/25.
//

import SwiftUI
import BaseStyle
import AVKit
import Data
import PhotosUI

struct FeedbackView: View {

    @ObservedObject var viewModel: FeedbackViewModel

    @FocusState private var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.currentState {
                LoaderView()
            } else {
                ScrollView(showsIndicators: false) {
                    VSpacer(24)

                    VStack(spacing: 24) {
                        FeedbackTitleFieldView(
                            titleText: $viewModel.title,
                            isSelected: focusField == .title,
                            shouldShowValidationMessage: viewModel.shouldShowValidationMessage,
                            isValidText: viewModel.isValidTitle)
                        .focused($focusField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            if focusField == .title {
                                focusField = .description
                            } else if focusField == .description {
                                focusField = nil
                            }
                        }
                        .onTapGestureForced {
                            focusField = .title
                        }

                        FeedbackDescriptionView(
                            isSelected: focusField == .description,
                            titleText: $viewModel.description)
                        .focused($focusField, equals: .description)
                        .onTapGestureForced {
                            focusField = .description
                        }

                        FeedbackAttachImageView(attachedImages: $viewModel.selectedAttachments,
                                                uploadingAttachments: $viewModel.uploadingAttachments,
                                                failedAttachments: $viewModel.failedAttachments,
                                                handleAttachmentTap: viewModel.handleAttachmentTap,
                                                onRemoveAttachmentTap: viewModel.onRemoveAttachment,
                                                onRetryButtonTap: viewModel.onRetryAttachment(_:),
                                                focusField: _focusField)
                        .actionSheet(isPresented: $viewModel.showImagePickerOption, content: {
                            getActionSheet(withRemoveAllOption: $viewModel.selectedAttachments.count >= 1,
                                           selection: viewModel.handleActionSelection(_:))
                        })

                        PrimaryButton(text: "Submit",
                                      isEnabled: viewModel.isValidTitle && viewModel.uploadingAttachments.isEmpty,
                                      showLoader: viewModel.showLoader, onClick: viewModel.submitFeedback)
                    }
                    .padding([.horizontal, .bottom], 16)
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Contact support")
            }
        }
        .onAppear {
            UIScrollView.appearance().keyboardDismissMode = .interactive
            focusField = .title
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            MultipleImageSelectionPickerView(onDismiss: viewModel.onImagePickerSheetDismiss(attachments:),
                                             isPresented: $viewModel.showImagePicker)
        }
    }

    func getActionSheet(withRemoveAllOption: Bool, selection: @escaping ((FeedbackViewModel.ActionsOfSheet) -> Void)) -> ActionSheet {
        let gallery: ActionSheet.Button = .default(
            Text("Gallery")) {
                selection(.gallery)
            }
        let removeAll: ActionSheet.Button = .destructive(
            Text("Remove All")) {
                selection(.removeAll)
            }
        let btn_cancel: ActionSheet.Button = .cancel(Text("Cancel"))

        return ActionSheet(title: Text("Choose mode"),
                           message: Text("Please choose your preferred mode to attach image with feedback"),
                           buttons: withRemoveAllOption ? [gallery, removeAll, btn_cancel] : [gallery, btn_cancel])
    }
}

struct FeedbackTitleFieldView: View {

    @Binding var titleText: String

    var isSelected: Bool = false
    var errorMessage: String = "Minimum 3 characters are required"
    var shouldShowValidationMessage: Bool = false
    var isValidText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Title")
                .font(.body2())
                .foregroundColor(disableText)
                .tracking(-0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            VSpacer(10)

            TextField("", text: $titleText)
                .font(.subTitle1())
                .foregroundColor(primaryText)
                .tint(primaryColor)
                .lineLimit(1)
                .disableAutocorrection(true)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(getDividerColor(), lineWidth: 1)
                )

            VSpacer(3)

            Text(shouldShowValidationMessage ? (isValidText ? " " : errorMessage) : " ")
                .foregroundColor(errorColor)
                .font(.body1(12))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    func getDividerColor() -> Color {
        if shouldShowValidationMessage && !isValidText {
            return errorColor
        } else {
            return isSelected ? primaryColor : outlineColor
        }
    }
}

struct FeedbackDescriptionView: View {

    var isSelected: Bool = false

    @Binding var titleText: String

    var body: some View {
        VStack(spacing: 0) {
            Text("Description")
                .font(.body2())
                .foregroundColor(disableText)
                .tracking(-0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            VSpacer(8)

            TextEditor(text: $titleText)
                .frame(height: UIScreen.main.bounds.height/4, alignment: .center)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.sentences)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? primaryColor : outlineColor, lineWidth: 1)
                )
        }
    }
}

struct FeedbackAttachImageView: View {

    @Binding var attachedImages: [Attachment]
    @Binding var uploadingAttachments: [Attachment]
    @Binding var failedAttachments: [Attachment]

    let handleAttachmentTap: () -> Void
    let onRemoveAttachmentTap: (Attachment) -> Void
    let onRetryButtonTap: (Attachment) -> Void

    @FocusState var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(attachedImages, id: \.id) { attachment in
                AttachmentCellView(
                    attachment: attachment,
                    isUploading: uploadingAttachments.contains(where: { $0.id == attachment.id }),
                    shouldShowRetryButton: failedAttachments.contains(where: { $0.id == attachment.id }),
                    onRetryButtonTap: {_ in
                        onRetryButtonTap(attachment)
                    },
                    onRemoveAttachmentTap: {_ in
                        onRemoveAttachmentTap(attachment)
                    }
                )
            }

            Button {
                focusField = nil
                handleAttachmentTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                    Text("Add attachment")
                        .font(.body1())
                }
                .foregroundColor(uploadingAttachments.isEmpty ? disableText : primaryText)
            }
            .buttonStyle(.scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AttachmentCellView: View {

    let attachment: Attachment
    let isUploading: Bool
    let shouldShowRetryButton: Bool

    let onRetryButtonTap: (Attachment) -> Void
    let onRemoveAttachmentTap: (Attachment) -> Void

    @FocusState private var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        HStack(spacing: 0) {
            AttachmentThumbnailView(attachment: attachment, isUploading: isUploading,
                                    shouldShowRetryButton: shouldShowRetryButton, onRetryButtonTap: onRetryButtonTap)

            Text(attachment.name)
                .font(.body1())
                .foregroundColor(secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            DismissButton(iconSize: (20, .regular), onDismissAction: {
                focusField = nil
                onRemoveAttachmentTap(attachment)
            })
            .padding([.vertical, .leading])
            .background(.linearGradient(.init(colors: [surfaceColor, surfaceColor, surfaceColor, surfaceColor, surfaceColor.opacity(0)]), startPoint: .trailing, endPoint: .leading))
        }
    }
}

struct AttachmentThumbnailView: View {

    let attachment: Attachment
    let isUploading: Bool
    let shouldShowRetryButton: Bool

    let onRetryButtonTap: (Attachment) -> Void

    var body: some View {
        ZStack {
            if let image = attachment.image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 50, height: 50, alignment: .leading)
                    .scaledToFit()
                    .cornerRadius(12)
            } else if let video = attachment.video {
                VideoPlayer(player: AVPlayer(url: video))
                    .frame(width: 50, height: 50)
                    .cornerRadius(12)
            }

            Rectangle()
                .frame(width: 50, height: 50, alignment: .leading)
                .foregroundColor(isUploading || shouldShowRetryButton ? disableText : .clear)
                .cornerRadius(12)

            if (attachment.video != nil) && !isUploading {
                ZStack {
                    Rectangle()
                        .frame(width: 50, height: 50, alignment: .leading)
                        .foregroundColor(secondaryText)
                        .cornerRadius(12)

                    Image(systemName: "play.circle")
                        .frame(width: 20, height: 20)
                        .foregroundColor(primaryColor)
                }
            }

            if isUploading {
                ImageLoaderView(tintColor: primaryColor)
            }

            if shouldShowRetryButton {
                Button {
                    onRetryButtonTap(attachment)
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .frame(width: 20, height: 20)
                        .foregroundColor(primaryColor)
                }
            }
        }
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
