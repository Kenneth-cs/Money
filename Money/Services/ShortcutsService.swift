import Foundation
import UIKit
import SwiftUI
import UserNotifications

// MARK: - 快捷指令服务
class ShortcutsService: NSObject {
    
    // MARK: - 单例模式
    static let shared = ShortcutsService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - 注册快捷指令（简化版本）
    func registerShortcuts() {
        print("✅ 快捷指令服务已初始化")
        // 由于iOS限制，这里使用简化的实现
        // 在实际项目中，需要创建Shortcuts扩展来实现完整功能
    }
    
    // MARK: - 处理快捷指令调用
    func handleShortcut(with userActivity: NSUserActivity) -> Bool {
        // 简化的快捷指令处理
        print("📱 处理快捷指令调用")
        return true
    }
    
    // MARK: - 处理URL调用的快捷指令
    func handleURLShortcut(amount: Double?, category: String?, account: String?, note: String?) {
        let intent = AddExpenseIntentData(
            amount: amount,
            category: category,
            account: account,
            note: note
        )
        
        let handler = AddExpenseIntentHandler()
        handler.handle(intent: intent) { response in
            DispatchQueue.main.async {
                if response.success {
                    self.showSuccessNotification(amount: response.expenseAmount ?? 0)
                } else {
                    self.showErrorNotification(message: response.message ?? "未知错误")
                }
            }
        }
    }
    
    // MARK: - 通知方法
    private func showSuccessNotification(amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "记账成功"
        content.body = String(format: "已添加支出 ¥%.2f", amount)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "expense_added",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送成功通知失败: \(error)")
            }
        }
    }
    
    private func showErrorNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "记账失败"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "expense_error",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送错误通知失败: \(error)")
            }
        }
    }
    
    // MARK: - 请求通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已获取")
            } else {
                print("❌ 通知权限被拒绝")
            }
            
            if let error = error {
                print("❌ 请求通知权限出错: \(error)")
            }
        }
    }
}

// MARK: - 快捷指令相关扩展
extension ShortcutsService {
    
    // MARK: - 批量处理截图
    func handleScreenshots(_ images: [UIImage], completion: @escaping (Bool, String) -> Void) {
        var totalAmount: Double = 0
        var processedCount = 0
        var errors: [String] = []
        
        let dispatchGroup = DispatchGroup()
        
        for image in images {
            dispatchGroup.enter()
            
            OCRService.shared.recognizeText(from: image) { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let ocrResults):
                    let fullText = ocrResults.map { $0.recognizedText }.joined(separator: "\n")
                    let parsedInfo = TextParsingService.shared.parseExpenseInfo(from: fullText)
                    
                    if let amount = parsedInfo.amount, amount > 0 {
                        // 自动添加支出记录
                        let intent = AddExpenseIntentData(
                            amount: amount,
                            category: parsedInfo.categoryName,
                            account: parsedInfo.paymentMethod,
                            note: parsedInfo.note ?? "批量截图识别"
                        )
                        
                        let handler = AddExpenseIntentHandler()
                        handler.handleDirectExpense(intent: intent) { response in
                            if response.success {
                                totalAmount += amount
                                processedCount += 1
                            } else {
                                errors.append(response.message ?? "保存失败")
                            }
                        }
                    } else {
                        errors.append("未识别到有效金额")
                    }
                    
                case .failure(let error):
                    errors.append("OCR识别失败: \(error.localizedDescription)")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let success = processedCount > 0
            let message = success ?
                "成功处理 \(processedCount) 张截图，总金额 ¥\(String(format: "%.2f", totalAmount))" :
                "处理失败: \(errors.joined(separator: ", "))"
            
            completion(success, message)
        }
    }
    
    // MARK: - 获取预设的快捷指令配置
    func getShortcutConfigurations() -> [ShortcutConfiguration] {
        return [
            ShortcutConfiguration(
                id: "quick_add",
                title: "快速记账",
                description: "快速添加一笔支出",
                systemImage: "plus.circle.fill",
                color: .blue
            ),
            ShortcutConfiguration(
                id: "screenshot_ocr",
                title: "截图识别",
                description: "从截图中自动识别支出信息",
                systemImage: "camera.viewfinder",
                color: .green
            ),
            ShortcutConfiguration(
                id: "food_expense",
                title: "用餐支出",
                description: "快速记录餐饮消费",
                systemImage: "fork.knife",
                color: .orange
            ),
            ShortcutConfiguration(
                id: "transport_expense", 
                title: "交通支出",
                description: "快速记录交通费用",
                systemImage: "car.fill",
                color: .cyan
            )
        ]
    }
}

// MARK: - 快捷指令配置
struct ShortcutConfiguration {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    let color: Color
}

// MARK: - 快捷指令错误类型
enum ShortcutError: LocalizedError {
    case invalidIntent
    case missingData
    case ocrFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidIntent:
            return "无效的快捷指令"
        case .missingData:
            return "缺少必要数据"
        case .ocrFailed:
            return "图像识别失败"
        case .saveFailed:
            return "保存记录失败"
        }
    }
} 