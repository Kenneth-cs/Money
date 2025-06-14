import Foundation
import CoreData

// MARK: - 数据管理器
class DataManager: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = DataManager()
    
    // MARK: - Core Data栈
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Money")
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data加载失败: \(error.localizedDescription)")
                fatalError("Core Data加载失败: \(error)")
            }
        }
        
        // 自动合并来自父上下文的更改
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    // MARK: - 主上下文
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - 私有初始化
    private init() {
        // 在应用首次启动时创建默认数据
        createDefaultDataIfNeeded()
    }
    
    // MARK: - 保存上下文
    func save() {
        let context = viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("数据保存成功")
            } catch {
                print("数据保存失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 创建默认数据
    private func createDefaultDataIfNeeded() {
        let context = viewContext
        
        // 检查是否已经有分类数据
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categoryCount = try? context.count(for: categoryRequest)
        
        if categoryCount == 0 {
            Category.createDefaultCategories(in: context)
            print("创建默认分类完成")
        }
        
        // 检查是否已经有账户数据
        let accountRequest: NSFetchRequest<Account> = Account.fetchRequest()
        let accountCount = try? context.count(for: accountRequest)
        
        if accountCount == 0 {
            Account.createDefaultAccounts(in: context)
            print("创建默认账户完成")
        }
        
        save()
    }
    
    // MARK: - 获取所有分类
    func fetchCategories() -> [Category] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取分类失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 获取所有账户
    func fetchAccounts() -> [Account] {
        let request: NSFetchRequest<Account> = Account.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Account.name, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取账户失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 获取支出记录
    func fetchExpenses(limit: Int? = nil) -> [Expense] {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取支出记录失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 添加支出记录
    func addExpense(amount: Double, category: Category, account: Account, note: String? = nil, date: Date = Date()) -> Expense {
        let expense = Expense(context: viewContext, amount: amount, category: category, account: account, note: note, date: date)
        save()
        return expense
    }
    
    // MARK: - 删除支出记录
    func deleteExpense(_ expense: Expense) {
        viewContext.delete(expense)
        save()
    }
    
    // MARK: - 今日支出统计
    func todayExpenses() -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let expenses = try viewContext.fetch(request)
            return expenses.reduce(0) { $0 + $1.amount }
        } catch {
            print("获取今日支出失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - 本月支出统计
    func monthExpenses() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfMonth as NSDate, endOfMonth as NSDate)
        
        do {
            let expenses = try viewContext.fetch(request)
            return expenses.reduce(0) { $0 + $1.amount }
        } catch {
            print("获取本月支出失败: \(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - 扩展工具方法
extension DataManager {
    
    // MARK: - 根据名称查找分类
    func findCategory(byName name: String) -> Category? {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND isActive == YES", name)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("查找分类失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 根据名称查找账户
    func findAccount(byName name: String) -> Account? {
        let request: NSFetchRequest<Account> = Account.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND isActive == YES", name)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("查找账户失败: \(error.localizedDescription)")
            return nil
        }
    }
} 