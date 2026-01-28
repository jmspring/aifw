//
// PolicyView.swift
// AIFWDashboard
//

import SwiftUI

struct PolicyView: View {
    @State private var policyText: String = ""

    var body: some View {
        VStack {
            Text("Policy Configuration")
                .font(.title)
                .bold()
                .padding()

            TextEditor(text: $policyText)
                .font(.system(.body, design: .monospaced))
                .padding()

            HStack {
                Button("Load Policy") {
                    loadPolicy()
                }

                Button("Save Policy") {
                    savePolicy()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            loadPolicy()
        }
    }

    private func loadPolicy() {
        let path = NSHomeDirectory() + "/.config/aifw/policy.json"
        if let content = try? String(contentsOfFile: path) {
            policyText = content
        }
    }

    private func savePolicy() {
        let path = NSHomeDirectory() + "/.config/aifw/policy.json"
        try? policyText.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
