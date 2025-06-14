import Foundation
import CoreData

// MARK: - 账户类型枚举
enum AccountType: String, CaseIterable {
    case cash = "现金"
    case bankCard = "银行卡"
    case creditCard = "信用卡"
    case alipay = "支付宝"
    case wechat = "微信"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .cash:
            return "banknote.fill"
        case .bankCard:
            return "creditcard.fill"
        case .creditCard:
            return "creditcard.trianglebadge.exclamationmark"
        case .alipay:
            return "a.circle.fill"
        case .wechat:
            return "w.circle.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .cash:
            return "green"
        case .bankCard:
            return "blue"
        case .creditCard:
            return "orange"
        case .alipay:
            return "blue"
        case .wechat:
            return "green"
        case .other:
            return "gray"
        }
    }
}

// MARK: - 账户模型
@objc(Account)
public class Account: NSManagedObject {
    
    // MARK: - 便利初始化
    convenience init(context: NSManagedObjectContext, name: String, type: AccountType, balance: Double = 0) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.type = type.rawValue
        self.balance = balance
        self.isActive = true
        self.createdAt = Date()
    }
    
    // MARK: - 账户类型
    var accountType: AccountType {
        get {
            return AccountType(rawValue: type ?? "") ?? .other
        }
        set {
            type = newValue.rawValue
        }
    }
    
    // MARK: - 预设账户
    static let defaultAccounts = [
        ("现金", AccountType.cash),
        ("银行卡", AccountType.bankCard),
        ("信用卡", AccountType.creditCard),
        ("支付宝", AccountType.alipay),
        ("微信", AccountType.wechat)
    ]
    
    // MARK: - 创建默认账户
    static func createDefaultAccounts(in context: NSManagedObjectContext) {
        for (name, type) in defaultAccounts {
            let account = Account(context: context, name: name, type: type)
            context.insert(account)
        }
        
        try? context.save()
    }
    
    // MARK: - 格式化余额
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: balance)) ?? "¥0.00"
    }
    
    // MARK: - 统计方法
    var totalExpenses: Double {
        return expenses?.compactMap { ($0 as? Expense)?.amount }.reduce(0, +) ?? 0
    }
    
    var expenseCount: Int {
        return expenses?.count ?? 0
    }
    
    // MARK: - 更新余额
    func updateBalance() {
        // 这里可以实现余额更新逻辑
        // 对于现金和银行卡，可以减去支出
        // 对于信用卡，可能需要不同的处理方式
    }
}

// MARK: - Core Data属性
extension Account {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Account> {
        return NSFetchRequest<Account>(entityName: "Account")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var type: String? // AccountType的rawValue
    @NSManaged public var balance: Double
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var expenses: NSSet?
}

// MARK: - 关系操作
extension Account {
    
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
extension Account: Identifiable {
    
} 