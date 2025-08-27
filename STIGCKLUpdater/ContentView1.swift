//
//  ContentView1.swift
//  STIGCKLUpdater
//
//  Created by Abhinav K Roy on 2025-06-17.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var cklURL: URL?
    @State private var outputURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("STIG Open Status Commenter")
                .font(.title)
                .padding()

            Button("Select CKL (.ckl) File") {
                selectFile(ofType: ["ckl"]) { url in
                    cklURL = url
                }
            }
            Text(cklURL?.lastPathComponent ?? "No file selected")
                .font(.caption)

            Button("Apply Comment to Open Findings") {
                guard let cklURL = cklURL else {
                    alertMessage = "Please select a CKL file."
                    showAlert = true
                    return
                }
                let panel = NSSavePanel()
                panel.allowedFileTypes = ["ckl"]
                panel.nameFieldStringValue = "Updated_MacOS_Checklist.ckl"
                panel.begin { response in
                    if response == .OK, let saveURL = panel.url {
                        do {
                            let updater = STIGOpenCommenter()
                            try updater.updateOpenComments(from: cklURL, saveTo: saveURL)
                            outputURL = saveURL
                            alertMessage = "Checklist updated successfully. File saved to: \(saveURL.path)"
                            showAlert = true
                        } catch {
                            alertMessage = "Error: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                }
            }
            .disabled(cklURL == nil)

            if let output = outputURL {
                Link("Open Exported File", destination: output)
            }
        }
        .frame(width: 500)
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Result"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func selectFile(ofType types: [String], completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = types
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(url)
            }
        }
    }
}

class STIGOpenCommenter {
    func updateOpenComments(from fileURL: URL, saveTo outputPath: URL) throws {
        let xml = try String(contentsOf: fileURL)
        var result = xml

        let fixedComment = "The  macbook is not controlled via any device management software  and hence the rule cannot be enforced remotely via a Government controlled remote configuration."

        let pattern = "(<VULN>[\\s\\S]*?<STATUS>Open</STATUS>[\\s\\S]*?<COMMENTS>)([\\s\\S]*?)(</COMMENTS>)"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(result.startIndex..., in: result)

        result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1\(fixedComment)$3")

        try result.write(to: outputPath, atomically: true, encoding: .utf8)
    }
}
