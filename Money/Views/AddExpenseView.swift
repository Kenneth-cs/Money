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
    
    // MARK: - 计算属性
    private var isValidInput: Bool {
        !amount.isEmpty && 
        Double(amount) != nil && 
        Double(amount)! > 0 && 
        selectedCategory != nil && 
        selectedAccount != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 金额输入
                    amountSection
                    
                    // 分类选择
                    categorySection
                    
                    // 账户选择
                    accountSection
                    
                    // 日期选择
                    dateSection
                    
                    // 备注输入
                    noteSection
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
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 金额输入区域
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 分类选择区域
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("分类")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 15) {
                ForEach(categories, id: \.self) { category in
                    CategorySelectionItem(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 账户选择区域
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("账户")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(accounts, id: \.self) { account in
                    AccountSelectionItem(
                        account: account,
                        isSelected: selectedAccount == account
                    ) {
                        selectedAccount = account
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 日期选择区域
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("日期")
                .font(.headline)
                .fontWeight(.semibold)
            
            DatePicker("选择日期", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }
    
    // MARK: - 备注输入区域
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("备注")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("添加备注...", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }
    
    // MARK: - 加载数据
    private func loadData() {
        categories = dataManager.fetchCategories()
        accounts = dataManager.fetchAccounts()
        
        // 默认选择第一个分类和账户
        if selectedCategory == nil {
            selectedCategory = categories.first
        }
        if selectedAccount == nil {
            selectedAccount = accounts.first
        }
    }
    
    // MARK: - 保存支出记录
    private func saveExpense() {
        guard let amountValue = Double(amount),
              let category = selectedCategory,
              let account = selectedAccount else {
            errorMessage = "请填写完整信息"
            showingError = true
            return
        }
        
        let expense = dataManager.addExpense(
            amount: amountValue,
            category: category,
            account: account,
            note: note.isEmpty ? nil : note,
            date: selectedDate
        )
        
        if expense != nil {
            dismiss()
        } else {
            errorMessage = "保存失败，请重试"
            showingError = true
        }
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