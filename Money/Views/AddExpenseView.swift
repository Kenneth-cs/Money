import SwiftUI
import CoreData

// MARK: - 添加支出视图
struct AddExpenseView: View {
    
    // MARK: - 环境对象
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 状态变量
    @State private var amount = ""
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var note = ""
    @State private var selectedDate = Date()
    @State private var categories: [Category] = []
    @State private var accounts: [Account] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // MARK: - 金额输入区域
                    amountInputSection
                    
                    // MARK: - 分类选择区域
                    categorySelectionSection
                    
                    // MARK: - 账户选择区域
                    accountSelectionSection
                    
                    // MARK: - 备注和日期
                    noteAndDateSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("添加支出")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidInput)
                }
            }
            .onAppear {
                loadData()
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 金额输入区域
    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("金额")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("¥")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                TextField("0.00", text: $amount)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(15)
        }
    }
    
    // MARK: - 分类选择区域
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("分类")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                ForEach(categories) { category in
                    CategorySelectionItem(
                        category: category,
                        isSelected: selectedCategory?.id == category.id
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    // MARK: - 账户选择区域
    private var accountSelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("支付方式")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(accounts) { account in
                    AccountSelectionItem(
                        account: account,
                        isSelected: selectedAccount?.id == account.id
                    ) {
                        selectedAccount = account
                    }
                }
            }
        }
    }
    
    // MARK: - 备注和日期区域
    private var noteAndDateSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("备注和时间")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 备注输入
                TextField("添加备注（可选）", text: $note)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                
                // 日期选择
                DatePicker("时间", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
            }
        }
    }
    
    // MARK: - 验证输入
    private var isValidInput: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        guard selectedCategory != nil else { return false }
        guard selectedAccount != nil else { return false }
        return true
    }
    
    // MARK: - 加载数据
    private func loadData() {
        categories = dataManager.fetchCategories()
        accounts = dataManager.fetchAccounts()
        
        // 设置默认选择
        selectedCategory = categories.first
        selectedAccount = accounts.first
    }
    
    // MARK: - 保存支出
    private func saveExpense() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "请输入有效的金额"
            showingError = true
            return
        }
        
        guard let category = selectedCategory else {
            errorMessage = "请选择支出分类"
            showingError = true
            return
        }
        
        guard let account = selectedAccount else {
            errorMessage = "请选择支付方式"
            showingError = true
            return
        }
        
        // 创建支出记录
        let _ = dataManager.addExpense(
            amount: amountValue,
            category: category,
            account: account,
            note: note.isEmpty ? nil : note,
            date: selectedDate
        )
        
        dismiss()
    }
}

// MARK: - 分类选择项
struct CategorySelectionItem: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: category.icon ?? "questionmark.circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : colorFromString(category.color ?? "gray"))
                    .frame(width: 50, height: 50)
                    .background(
                        isSelected ?
                        colorFromString(category.color ?? "gray") :
                        colorFromString(category.color ?? "gray").opacity(0.1)
                    )
                    .clipShape(Circle())
                
                Text(category.name ?? "未知")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? colorFromString(category.color ?? "gray") : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "brown": return .brown
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - 账户选择项
struct AccountSelectionItem: View {
    let account: Account
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: account.accountType.icon)
                    .foregroundColor(isSelected ? .white : colorFromString(account.accountType.color))
                    .font(.title3)
                
                Text(account.name ?? "未知")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ?
                colorFromString(account.accountType.color) :
                Color(.secondarySystemGroupedBackground)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? colorFromString(account.accountType.color) : Color.clear,
                        lineWidth: isSelected ? 0 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "brown": return .brown
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - 预览
#Preview {
    AddExpenseView()
        .environment(\.managedObjectContext, DataManager.shared.viewContext)
        .environmentObject(DataManager.shared)
} 