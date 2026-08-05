//
//  F1LoginWebView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/13/26.
//

import SwiftUI
import SafariServices
import Combine
import WebKit

struct F1LoginWebView: UIViewRepresentable {
    var onTokenFound: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://account.formula1.com/#/en/login")!))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onTokenFound: onTokenFound) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onTokenFound: (String) -> Void
        init(onTokenFound: @escaping (String) -> Void) { self.onTokenFound = onTokenFound }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                guard let cookie = cookies.first(where: { $0.name == "login-session" }),
                      let decoded = cookie.value.removingPercentEncoding ?? cookie.value as String?,
                      let data = decoded.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let inner = json["data"] as? [String: Any],
                      let token = inner["subscriptionToken"] as? String
                else {
                    let raw = cookies.first(where: { $0.name == "login-session" })?.value ?? "missing"
                    print("⏳ format: \(raw.prefix(10))...")
                    return
                }
                print("✅ got token")
                DispatchQueue.main.async { self.onTokenFound(token) }
            }
        }
    }
}
