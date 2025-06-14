import Foundation
import CoreData

// MARK: - 支出记录模型
@objc(Expense)
public class Expense: NSManagedObject {
    
    // MARK: - 便利初始化
    convenience init(context: NSManagedObjectContext, amount: Double, category: Category, account: Account, note: String? = nil, date: Date = Date()) {
        self.init(context: context)
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.account = account
        self.note = note
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - 格式化金额
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
    
    // MARK: - 格式化日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date ?? Date())
    }
    
    // MARK: - 显示名称
    var displayName: String {
        return note?.isEmpty == false ? note! : (category?.name ?? "未分类")
    }
}

// MARK: - Core Data属性
extension Expense {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Expense> {
        return NSFetchRequest<Expense>(entityName: "Expense")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var note: String?
    @NSManaged public var date: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var imageData: Data? // 存储OCR识别的原始图片
    @NSManaged public var ocrText: String? // 存储OCR识别的原始文本
    @NSManaged public var category: Category?
    @NSManaged public var account: Account?
}

// MARK: - Identifiable协议
extension Expense: Identifiable {
    
} 