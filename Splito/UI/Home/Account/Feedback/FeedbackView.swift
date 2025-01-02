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
                            height: UIScreen.main.bounds.height/4,
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
                                      //                                  isEventEnabled: true,
                                      showLoader: viewModel.showLoader,
                                      onClick: viewModel.submitFeedback)
                        .padding(.top, 12)
                    }
                    .padding([.horizontal, .bottom], 16)
                }
            }
        }
        .background(surfaceColor)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .onAppear {
            UIScrollView.appearance().keyboardDismissMode = .interactive
            focusField = .title
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            MultipleImageSelectionPickerView(onDismiss: { attachments in
                viewModel.onImagePickerSheetDismiss(attachments: attachments)
            }, isPresented: $viewModel.showImagePicker)
        }
        .toolbarRole(.editor)
        .navigationBarTitle("Contact support", displayMode: .inline)
    }

    func getActionSheet(withRemoveAllOption: Bool,
                        selection: @escaping ((FeedbackViewModel.ActionsOfSheet) -> Void)) -> ActionSheet {
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
    var isDisabled: Bool = false
    var title: String = "Title"
    var errorMessage: String = "Minimum %@ characters are required"
    var minCharacterLimit: Int = 3
    var shouldShowValidationMessage: Bool = false
    var isValidText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.body2())
                .foregroundColor(disableText)
                .tracking(-0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            VSpacer(10)

            TextField("", text: $titleText)
                .font(.subTitle1())
                .foregroundColor(primaryText)
                .disabled(isDisabled)
                .tint(primaryColor)
                .lineLimit(1)
                .disableAutocorrection(true)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(getDividerColor(), lineWidth: 1)
                )

            VSpacer(3)

            Text(shouldShowValidationMessage ? (isValidText ? " " : String(format: errorMessage, "\(minCharacterLimit)")) : " ")
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

    var title: String = "Description"
    var height: CGFloat
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var isValidText: Bool = false
    var shouldShowValidationMessage: Bool = false
    var errorMessage: String = ""
    var minCharacterLimit: Int = 3

    @Binding var titleText: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
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
                .disabled(isDisabled)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? primaryColor : outlineColor, lineWidth: 1)
                )

            Text(shouldShowValidationMessage ? (isValidText ? " " :  String(format: errorMessage, "\(minCharacterLimit)")) : " ")
                .foregroundColor(errorColor)
                .font(.body1(12))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
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
            AttachmentThumbnailView(attachment: attachment, isUploading: isUploading, shouldShowRetryButton: shouldShowRetryButton, onRetryButtonTap: onRetryButtonTap)

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
            } else if let video = attachment.video {
                VideoPlayer(player: AVPlayer(url: video))
                    .frame(width: 50, height: 50)
            }

            Rectangle()
                .frame(width: 50, height: 50, alignment: .leading)
                .foregroundColor(isUploading || shouldShowRetryButton ? secondaryText : .clear)

            if (attachment.video != nil) && !isUploading {
                ZStack {
                    Rectangle()
                        .frame(width: 50, height: 50, alignment: .leading)
                        .foregroundColor(secondaryText)

                    Image(systemName: "play.circle")
                        .frame(width: 20, height: 20)
                        .foregroundColor(surfaceColor)
                }
            }

            if isUploading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: secondaryText))
            }

            if shouldShowRetryButton {
                Button {
                    onRetryButtonTap(attachment)
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .frame(width: 20, height: 20)
                        .foregroundColor(surfaceColor)
                }
            }
        }
    }
}
