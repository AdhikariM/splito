//
//  FeedbackRepository.swift
//  Data
//
//  Created by Nirali Sonani on 02/01/25.
//

import Foundation

public class FeedbackRepository: ObservableObject {

    @Inject private var store: FeedbackStore

    public func addFeedback(feedback: Feedback) async throws {
        try await store.addFeedback(feedback: feedback)
    }
}
