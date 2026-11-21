//
//  PrivacyPolicyView.swift
//  Words killer
//

import SwiftUI

struct PrivacyPolicyView: View {
    private var policy: String? {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    var body: some View {
        ScrollView {
            if let policy {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(policy.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                        Text(.init(paragraph))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .textSelection(.enabled)
                .padding()
            } else {
                ContentUnavailableView("隐私政策暂时无法读取", systemImage: "doc.text")
            }
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}
