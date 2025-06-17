import Foundation
import SwiftUI

// MARK: - URL状态管理器
class URLStateManager: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = URLStateManager()
    
    // MARK: - 状态变量
    @Published var shouldShowAddExpense = false
    @Published var prefilledData: PrefilledExpenseData?
    
    private init() {}
    
    // MARK: - 预填充数据结构
    struct PrefilledExpenseData {
        let amount: String
        let category: String?
        let account: String?
        let note: String
        let ocrText: String?
        
        init(amount: Double? = nil, category: String? = nil, account: String? = nil, note: String? = nil, ocrText: String? = nil) {
            self.amount = amount != nil ? String(format: "%.2f", amount!) : ""
            self.category = category
            self.account = account
            self.note = note ?? ""
            self.ocrText = ocrText
        }
    }
    
    // MARK: - 触发显示添加支出界面
    func showAddExpenseWithData(amount: Double? = nil, category: String? = nil, account: String? = nil, note: String? = nil, ocrText: String? = nil) {
        DispatchQueue.main.async {
            self.prefilledData = PrefilledExpenseData(
                amount: amount,
                category: category,
                account: account,
                note: note,
                ocrText: ocrText
            )
            self.shouldShowAddExpense = true
        }
    }
    
    // MARK: - 重置状态
    func reset() {
        DispatchQueue.main.async {
            self.shouldShowAddExpense = false
            self.prefilledData = nil
        }
    }
} 