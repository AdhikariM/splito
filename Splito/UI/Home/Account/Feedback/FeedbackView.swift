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
                        FeedbackTitleView(titleText: $viewModel.title, focusField: $focusField,
                                          isSelected: focusField == .title, isValidTitle: viewModel.isValidTitle,
                                          shouldShowValidationMessage: viewModel.shouldShowValidationMessage)

                        FeedbackDescriptionView(titleText: $viewModel.description, focusField: $focusField,
                                                isSelected: focusField == .description)

                        FeedbackAddAttachmentView(
                            attachedImages: $viewModel.selectedAttachments, uploadingAttachments: $viewModel.uploadingAttachments,
                            failedAttachments: $viewModel.failedAttachments, selectedAttachments: $viewModel.selectedAttachments, showImagePickerOption: $viewModel.showImagePickerOption, handleAttachmentTap: viewModel.handleAttachmentTap,
                            onRemoveAttachmentTap: viewModel.onRemoveAttachment, onRetryButtonTap: viewModel.onRetryAttachment(_:),
                            handleActionSelection: viewModel.handleActionSelection(_:), focusField: _focusField
                        )

                        PrimaryButton(
                            text: "Submit", isEnabled: viewModel.uploadingAttachments.isEmpty,
                            showLoader: viewModel.showLoader, onClick: viewModel.submitFeedback
                        )
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
        .onAppear {
            focusField = .title
            UIScrollView.appearance().keyboardDismissMode = .interactive
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: "Contact support")
            }
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            MultipleImageSelectionPickerView(onDismiss: viewModel.onImagePickerSheetDismiss(attachments:),
                                             isPresented: $viewModel.showImagePicker)
        }
    }
}

private struct FeedbackTitleView: View {

    @Binding var titleText: String
    var focusField: FocusState<FeedbackViewModel.FocusedField?>.Binding

    let isSelected: Bool
    let isValidTitle: Bool
    let shouldShowValidationMessage: Bool

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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(shouldShowValidationMessage && !isValidTitle ? errorColor : isSelected ? primaryColor : outlineColor, lineWidth: 1)
                )
                .focused(focusField, equals: .title)
                .submitLabel(.next)
                .onSubmit {
                    if focusField.wrappedValue == .title {
                        focusField.wrappedValue = .description
                    } else if focusField.wrappedValue == .description {
                        focusField.wrappedValue = nil
                    }
                }
                .onTapGestureForced {
                    focusField.wrappedValue = .title
                }

            VSpacer(3)

            Text(shouldShowValidationMessage ? (isValidTitle ? " " : "Minimum 3 characters are required") : " ")
                .foregroundColor(errorColor)
                .font(.body1(12))
                .foregroundColor(errorColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

private struct FeedbackDescriptionView: View {

    @Binding var titleText: String
    var focusField: FocusState<FeedbackViewModel.FocusedField?>.Binding

    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Description")
                .font(.body2())
                .foregroundColor(disableText)
                .tracking(-0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $titleText)
                .frame(height: UIScreen.main.bounds.height/4, alignment: .center)
                .font(.subTitle2())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? primaryColor : outlineColor, lineWidth: 1)
                )
                .focused(focusField, equals: .description)
                .onTapGestureForced {
                    focusField.wrappedValue = .description
                }
        }
    }
}

private struct FeedbackAddAttachmentView: View {

    @Binding var attachedImages: [Attachment]
    @Binding var uploadingAttachments: [Attachment]
    @Binding var failedAttachments: [Attachment]
    @Binding var selectedAttachments: [Attachment]
    @Binding var showImagePickerOption: Bool

    let handleAttachmentTap: () -> Void
    let onRemoveAttachmentTap: (Attachment) -> Void
    let onRetryButtonTap: (Attachment) -> Void
    let handleActionSelection: (ActionsOfSheet) -> Void

    @FocusState var focusField: FeedbackViewModel.FocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(attachedImages, id: \.id) { attachment in
                FeedbackAttachmentCellView(
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
        .confirmationDialog("Choose mode\n Please choose your preferred mode to includes attachment with feedback",
                            isPresented: $showImagePickerOption, titleVisibility: .visible) {
            MediaPickerOptionsView(withRemoveAllOption: $selectedAttachments.count >= 1,
                                   handleActionSelection: handleActionSelection)
        }
    }
}

private struct FeedbackAttachmentCellView: View {

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

private struct AttachmentThumbnailView: View {

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
