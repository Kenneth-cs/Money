//
//  MoneyApp.swift
//  Money
//
//  Created by zhangshaocong6 on 2025/6/14.
//

import SwiftUI
import CoreData

@main
struct MoneyApp: App {
    
    // MARK: - 数据管理器
    let dataManager = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataManager.viewContext)
                .environmentObject(dataManager)
                .onAppear {
                    setupApp()
                }
                .onContinueUserActivity("AddExpenseIntent") { userActivity in
                    handleShortcut(userActivity)
                }
                .onOpenURL(perform: handleURL)
        }
    }
    
    // MARK: - 应用初始化
    private func setupApp() {
        // 初始化默认数据（如果需要）
        // dataManager会在init时自动加载数据
        
        // 注册快捷指令
        ShortcutsService.shared.registerShortcuts()
        ShortcutsService.shared.requestNotificationPermission()
        
        print("✅ Money应用初始化完成")
    }
    
    // MARK: - 处理快捷指令调用
    private func handleShortcut(_ userActivity: NSUserActivity) {
        let handled = ShortcutsService.shared.handleShortcut(with: userActivity)
        if handled {
            print("✅ 快捷指令处理成功")
        } else {
            print("❌ 快捷指令处理失败")
        }
    }
    
    // MARK: - 处理URL调用
    private func handleURL(_ url: URL) {
        print("📱 接收到URL调用: \(url)")
        
        // 解析URL参数
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        // 处理不同的URL scheme
        switch components.host {
        case "add-expense":
            handleAddExpenseURL(queryItems)
        case "screenshot-ocr":
            handleScreenshotOCRURL(queryItems)
        default:
            print("❌ 未知的URL scheme: \(components.host ?? "nil")")
        }
    }
    
    // MARK: - 处理添加支出URL
    private func handleAddExpenseURL(_ queryItems: [URLQueryItem]) {
        var amount: Double?
        var category: String?
        var account: String?
        var note: String?
        
        for item in queryItems {
            switch item.name {
            case "amount":
                amount = Double(item.value ?? "")
            case "category":
                category = item.value
            case "account":
                account = item.value
            case "note":
                note = item.value
            default:
                break
            }
        }
        
        // 使用ShortcutsService处理URL快捷指令
        ShortcutsService.shared.handleURLShortcut(
            amount: amount,
            category: category,
            account: account,
            note: note
        )
    }
    
    // MARK: - 处理截图OCR URL
    private func handleScreenshotOCRURL(_ queryItems: [URLQueryItem]) {
        // 获取最新的截图（简化实现）
        print("📷 执行截图OCR功能")
        
        // 这里可以实现获取最新截图的逻辑
        // 由于iOS限制，应用无法直接获取系统截图
        // 需要用户手动选择图片或通过快捷指令传递
        
        let intent = AddExpenseIntentData.addExpenseFromScreenshot()
        
        let handler = AddExpenseIntentHandler()
        handler.handle(intent: intent) { response in
            DispatchQueue.main.async {
                print("📱 截图OCR处理完成: \(response.success ? "成功" : "失败")")
            }
        }
    }
}
