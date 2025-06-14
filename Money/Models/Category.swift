import Foundation
import CoreData

// MARK: - 支出分类模型
@objc(Category)
public class Category: NSManagedObject {
    
    // MARK: - 便利初始化
    convenience init(context: NSManagedObjectContext, name: String, icon: String, color: String) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.isActive = true
        self.createdAt = Date()
    }
    
    // MARK: - 预设分类
    static let defaultCategories = [
        ("餐饮", "fork.knife", "orange"),
        ("交通", "car.fill", "blue"),
        ("购物", "bag.fill", "pink"),
        ("娱乐", "gamecontroller.fill", "purple"),
        ("医疗", "cross.case.fill", "red"),
        ("教育", "book.fill", "green"),
        ("住房", "house.fill", "brown"),
        ("服饰", "tshirt.fill", "cyan"),
        ("数码", "iphone", "gray"),
        ("其他", "ellipsis.circle.fill", "secondary")
    ]
    
    // MARK: - 创建默认分类
    static func createDefaultCategories(in context: NSManagedObjectContext) {
        for (name, icon, color) in defaultCategories {
            let category = Category(context: context, name: name, icon: icon, color: color)
            context.insert(category)
        }
        
        try? context.save()
    }
    
    // MARK: - 统计方法
    var totalExpenses: Double {
        return expenses?.compactMap { ($0 as? Expense)?.amount }.reduce(0, +) ?? 0
    }
    
    var expenseCount: Int {
        return expenses?.count ?? 0
    }
}

// MARK: - Core Data属性
extension Category {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var icon: String? // SF Symbols图标名称
    @NSManaged public var color: String? // 颜色名称
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var expenses: NSSet?
}

// MARK: - 关系操作
extension Category {
    
    @objc(addExpensesObject:)
    @NSManaged public func addToExpenses(_ value: Expense)
    
    @objc(removeExpensesObject:)
    @NSManaged public func removeFromExpenses(_ value: Expense)
    
    @objc(addExpenses:)
    @NSManaged public func addToExpenses(_ values: NSSet)
    
    @objc(removeExpenses:)
    @NSManaged public func removeFromExpenses(_ values: NSSet)
}

// MARK: - Identifiable协议
extension Category: Identifiable {
    
} 