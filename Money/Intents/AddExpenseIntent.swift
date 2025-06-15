import Foundation
import UIKit
import CoreData

// MARK: - 简化的支出Intent
struct AddExpenseIntentData {
    
    // Intent参数
    var amount: Double?
    var category: String?
    var account: String?
    var note: String?
    var imageData: Data?
    
    init(amount: Double? = nil, category: String? = nil, account: String? = nil, note: String? = nil, imageData: Data? = nil) {
        self.amount = amount
        self.category = category
        self.account = account
        self.note = note
        self.imageData = imageData
    }
}

// MARK: - Intent Response
struct AddExpenseIntentResponse {
    
    var success: Bool = false
    var message: String?
    var expenseAmount: Double?
    
    init(success: Bool, message: String? = nil, expenseAmount: Double? = nil) {
        self.success = success
        self.message = message
        self.expenseAmount = expenseAmount
    }
}

// MARK: - Intent Handler
class AddExpenseIntentHandler {
    
    func handle(intent: AddExpenseIntentData, completion: @escaping (AddExpenseIntentResponse) -> Void) {
        
        // 处理OCR识别（如果有图片）
        if let imageData = intent.imageData, let image = UIImage(data: imageData) {
            handleImageRecognition(image: image, intent: intent, completion: completion)
        } else {
            // 直接处理添加支出
            handleDirectExpense(intent: intent, completion: completion)
        }
    }
    
    // 处理图片识别
    private func handleImageRecognition(image: UIImage, intent: AddExpenseIntentData, completion: @escaping (AddExpenseIntentResponse) -> Void) {
        
        OCRService.shared.recognizeText(from: image) { result in
            switch result {
            case .success(let ocrResults):
                let fullText = ocrResults.map { $0.recognizedText }.joined(separator: "\n")
                let parsedInfo = TextParsingService.shared.parseExpenseInfo(from: fullText)
                
                // 使用解析的信息覆盖Intent中的参数
                let finalAmount = intent.amount ?? parsedInfo.amount ?? 0
                let finalCategory = intent.category ?? parsedInfo.categoryName ?? "其他"
                let finalAccount = intent.account ?? parsedInfo.paymentMethod ?? "现金"
                let finalNote = intent.note ?? parsedInfo.note ?? "快捷指令添加"
                
                // 保存支出记录
                self.saveExpense(
                    amount: finalAmount,
                    category: finalCategory,
                    account: finalAccount,
                    note: finalNote,
                    completion: completion
                )
                
            case .failure(let error):
                let response = AddExpenseIntentResponse(
                    success: false,
                    message: "图片识别失败: \(error.localizedDescription)"
                )
                completion(response)
            }
        }
    }
    
    // 处理直接添加支出
    func handleDirectExpense(intent: AddExpenseIntentData, completion: @escaping (AddExpenseIntentResponse) -> Void) {
        
        let amount = intent.amount ?? 0
        let category = intent.category ?? "其他"
        let account = intent.account ?? "现金"
        let note = intent.note ?? "快捷指令添加"
        
        saveExpense(
            amount: amount,
            category: category,
            account: account,
            note: note,
            completion: completion
        )
    }
    
    // 保存支出记录
    private func saveExpense(amount: Double, category: String, account: String, note: String, completion: @escaping (AddExpenseIntentResponse) -> Void) {
        
        guard amount > 0 else {
            let response = AddExpenseIntentResponse(
                success: false,
                message: "金额必须大于0"
            )
            completion(response)
            return
        }
        
        let dataManager = DataManager.shared
        
        // 查找分类和账户
        let categories = dataManager.fetchCategories()
        let accounts = dataManager.fetchAccounts()
        
        let selectedCategory = categories.first { $0.name == category } ?? categories.first
        let selectedAccount = accounts.first { $0.name == account } ?? accounts.first
        
        guard let finalCategory = selectedCategory,
              let finalAccount = selectedAccount else {
            let response = AddExpenseIntentResponse(
                success: false,
                message: "未找到对应的分类或账户"
            )
            completion(response)
            return
        }
        
        // 添加支出记录
        let expense = dataManager.addExpense(
            amount: amount,
            category: finalCategory,
            account: finalAccount,
            note: note,
            date: Date()
        )
        
        // 检查是否创建成功 (简化检查，因为DataManager.addExpense返回非可选类型)
        let response = AddExpenseIntentResponse(
            success: true,
            message: "成功添加支出记录",
            expenseAmount: amount
        )
        completion(response)
    }
}

// MARK: - Intent快捷方法
extension AddExpenseIntentData {
    
    // 预定义的快捷指令
    static func quickAddExpense(amount: Double) -> AddExpenseIntentData {
        return AddExpenseIntentData(
            amount: amount,
            category: "其他",
            account: "现金",
            note: "快速记账"
        )
    }
    
    // 从截图添加支出
    static func addExpenseFromScreenshot() -> AddExpenseIntentData {
        return AddExpenseIntentData(note: "截图识别")
    }
    
    // 自定义支出
    static func customExpense(amount: Double, category: String, account: String, note: String) -> AddExpenseIntentData {
        return AddExpenseIntentData(
            amount: amount,
            category: category,
            account: account,
            note: note
        )
    }
} 