//
//  ContentView.swift
//  STIGCKLUpdater
//
//  Created by Abhinav K Roy on 2025-06-12.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var csvURL: URL?
    @State private var cklURL: URL?
    @State private var outputURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("STIG Comment Merger")
                .font(.title)
                .padding()

            Button("Select CSV File (exported from Excel)") {
                selectFile(ofType: ["csv"]) { url in
                    csvURL = url
                }
            }
            Text(csvURL?.lastPathComponent ?? "No file selected")
                .font(.caption)

            Button("Select CKL (.ckl) File") {
                selectFile(ofType: ["ckl"]) { url in
                    cklURL = url
                }
            }
            Text(cklURL?.lastPathComponent ?? "No file selected")
                .font(.caption)

            Button("Merge and Export") {
                guard let csvURL = csvURL, let cklURL = cklURL else {
                    alertMessage = "Please select both input files."
                    showAlert = true
                    return
                }
                let panel = NSSavePanel()
                panel.allowedFileTypes = ["ckl"]
                panel.nameFieldStringValue = "Updated_MacOS_Checklist.ckl"
                panel.begin { response in
                    if response == .OK, let saveURL = panel.url {
                        do {
                            let exporter = STIGMerger()
                            try exporter.merge(csv: csvURL, ckl: cklURL, saveTo: saveURL)
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
            .disabled(csvURL == nil || cklURL == nil)

            if let output = outputURL {
                Link("Open Exported File", destination: output)
            }
        }
        .frame(width: 500)
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Merge Result"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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

class STIGMerger {
    func merge(csv: URL, ckl: URL, saveTo outputPath: URL) throws {
        let comments = try readCSV(csv)
        let updatedXML = try updateCKL(with: comments, from: ckl)
        try updatedXML.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    func readCSV(_ fileURL: URL) throws -> [String: String] {
        let content = try String(contentsOf: fileURL)
        var map = [String: String]()
        let lines = content.components(separatedBy: "\n").dropFirst()
        for line in lines where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            if cols.count >= 2 {
                map[cols[0].trimmingCharacters(in: .whitespacesAndNewlines)] =
                    cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return map
    }

    func updateCKL(with comments: [String: String], from fileURL: URL) throws -> String {
        let xml = try String(contentsOf: fileURL)
        var result = xml

        for (vulnID, comment) in comments {
            let escapedVulnID = NSRegularExpression.escapedPattern(for: vulnID)
            let escapedComment = comment.replacingOccurrences(of: "$", with: "\\$")
            let pattern = "(<VULN>[\\s\\S]*?<VULN_ATTRIBUTE>Vuln_Num</VULN_ATTRIBUTE>\\s*<ATTRIBUTE_DATA>\(escapedVulnID)</ATTRIBUTE_DATA>[\\s\\S]*?<COMMENTS>)([\\s\\S]*?)(</COMMENTS>)"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1\(escapedComment)$3")
        }

        return result
    }
}
#Preview {
    ContentView()
}
