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
        print("📱 URL绝对字符串: \(url.absoluteString)")
        print("📱 URL方案: \(url.scheme ?? "nil")")
        print("📱 URL主机: \(url.host ?? "nil")")
        
        // 解析URL参数
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ 无法解析URL组件")
            return
        }
        
        print("📱 URL组件: \(components)")
        
        guard let queryItems = components.queryItems else {
            print("❌ 没有查询参数")
            return
        }
        
        print("📱 查询参数: \(queryItems)")
        
        // 处理不同的URL scheme
        switch components.host {
        case "add-expense":
            print("✅ 处理add-expense请求")
            handleAddExpenseURL(queryItems)
        case "screenshot-ocr":
            print("✅ 处理screenshot-ocr请求")
            handleScreenshotOCRURL(queryItems)
        default:
            print("❌ 未知的URL scheme: \(components.host ?? "nil")")
        }
    }
    
    // MARK: - 处理添加支出URL
    private func handleAddExpenseURL(_ queryItems: [URLQueryItem]) {
        print("🔍 开始处理添加支出URL，参数数量: \(queryItems.count)")
        
        var amount: Double?
        var category: String?
        var account: String?
        var note: String?
        var ocrText: String?
        
        // 解析URL参数
        for (index, item) in queryItems.enumerated() {
            print("📝 参数[\(index)]: \(item.name) = '\(item.value ?? "nil")' (长度: \(item.value?.count ?? 0))")
            switch item.name {
            case "amount":
                amount = Double(item.value ?? "")
                print("💰 解析金额: \(amount ?? 0)")
            case "category":
                category = item.value
                print("🏷️ 设置分类: \(category ?? "nil")")
            case "account":
                account = item.value
                print("💳 设置账户: \(account ?? "nil")")
            case "note":
                note = item.value
                print("📄 设置备注: \(note ?? "nil")")
            case "text":
                ocrText = item.value
                print("📝 设置OCR文本: '\(ocrText ?? "nil")' (长度: \(ocrText?.count ?? 0))")
            default:
                print("❓ 未知参数: \(item.name)")
                break
            }
        }
        
        // 如果有OCR文本，尝试解析
        if let text = ocrText {
            print("📝 OCR文本去空格后: '\(text.trimmingCharacters(in: .whitespacesAndNewlines))' (长度: \(text.trimmingCharacters(in: .whitespacesAndNewlines).count))")
            print("📝 收到OCR文本: \(text)")
            
            // 使用TextParsingService解析文本
            let parsedInfo = TextParsingService.shared.parseExpenseInfo(from: text)
            
            print("🔍 解析结果详情:")
            print("  - 金额: \(parsedInfo.amount ?? 0)")
            print("  - 商家: \(parsedInfo.merchantName ?? "无")")
            print("  - 分类: \(parsedInfo.categoryName ?? "无")")
            print("  - 置信度: \(parsedInfo.confidence)")
            
            // 只有当置信度足够高时才使用解析结果
            if parsedInfo.confidence > 0.3 {
                // 如果解析出了金额，使用解析的结果
                if let parsedAmount = parsedInfo.amount {
                    amount = parsedAmount
                    print("✅ 使用解析的金额: \(parsedAmount)")
                }
                if let parsedCategory = parsedInfo.categoryName {
                    category = parsedCategory
                    print("✅ 使用解析的分类: \(parsedCategory)")
                }
                if let parsedMerchant = parsedInfo.merchantName {
                    note = "截图识别: \(parsedMerchant)"
                    print("✅ 使用解析的商家: \(parsedMerchant)")
                } else {
                    note = "截图识别: \(text.prefix(50))"
                    print("✅ 使用原始文本作为备注")
                }
            } else {
                // 置信度太低，只保留原始文本作为备注
                note = "截图识别: \(text.prefix(50))"
                print("⚠️ 解析置信度太低(\(parsedInfo.confidence))，仅保留原始文本")
            }
            
            print("💡 最终数据 - 金额: \(amount ?? 0), 分类: \(category ?? "未知"), 备注: \(note ?? "")")
        }
        
        // 使用URLStateManager显示添加支出界面，而不是直接保存
        URLStateManager.shared.showAddExpenseWithData(
            amount: amount,
            category: category,
            account: account,
            note: note,
            ocrText: ocrText
        )
        
        print("✅ URL处理完成，准备显示添加支出界面")
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
