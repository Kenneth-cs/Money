import SwiftUI
import CoreData

// MARK: - 支出列表视图
struct ExpenseListView: View {
    
    // MARK: - 环境对象
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - 状态变量
    @State private var expenses: [Expense] = []
    @State private var filteredExpenses: [Expense] = []
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var showingAddExpense = false
    @State private var showingFilterOptions = false
    @State private var selectedDateRange = DateRange.all
    @State private var categories: [Category] = []
    @State private var accounts: [Account] = []
    
    // MARK: - 日期范围枚举
    enum DateRange: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case thisWeek = "本周"
        case thisMonth = "本月"
        case lastMonth = "上月"
        
        var dateInterval: (start: Date, end: Date)? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all:
                return nil
            case .today:
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                return (start, end)
            case .thisWeek:
                let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let end = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
                return (start, end)
            case .thisMonth:
                let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let end = calendar.dateInterval(of: .month, for: now)?.end ?? now
                return (start, end)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                let start = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
                let end = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
                return (start, end)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // MARK: - 搜索栏
                searchSection
                
                // MARK: - 筛选栏
                filterSection
                
                // MARK: - 统计信息
                statisticsSection
                
                // MARK: - 支出列表
                expenseListSection
            }
            .navigationTitle("支出记录")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
                    .onDisappear {
                        loadData()
                    }
            }
            .sheet(isPresented: $showingFilterOptions) {
                FilterOptionsView(
                    categories: categories,
                    accounts: accounts,
                    selectedCategory: $selectedCategory,
                    selectedAccount: $selectedAccount,
                    selectedDateRange: $selectedDateRange
                ) {
                    applyFilters()
                }
            }
        }
    }
    
    // MARK: - 搜索栏
    private var searchSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索支出记录...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { _, newValue in
                        applyFilters()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        applyFilters()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            
            Button {
                showingFilterOptions = true
            } label: {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(hasActiveFilters ? .blue : .secondary)
                    .font(.title2)
            }
        }
        .padding()
    }
    
    // MARK: - 筛选栏
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    FilterChip(
                        title: range.rawValue,
                        isSelected: selectedDateRange == range
                    ) {
                        selectedDateRange = range
                        applyFilters()
                    }
                }
                
                if let category = selectedCategory {
                    FilterChip(
                        title: category.name ?? "未知分类",
                        isSelected: true,
                        isRemovable: true
                    ) {
                        selectedCategory = nil
                        applyFilters()
                    }
                }
                
                if let account = selectedAccount {
                    FilterChip(
                        title: account.name ?? "未知账户",
                        isSelected: true,
                        isRemovable: true
                    ) {
                        selectedAccount = nil
                        applyFilters()
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - 统计信息
    private var statisticsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("总计")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(totalAmount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("共 \(filteredExpenses.count) 笔")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !filteredExpenses.isEmpty {
                    Text("平均 \(formatCurrency(averageAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - 支出列表
    private var expenseListSection: some View {
        List {
            if filteredExpenses.isEmpty {
                EmptyExpenseListView()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(groupedExpenses, id: \.key) { group in
                    Section(header: sectionHeader(for: group.key)) {
                        ForEach(group.value) { expense in
                            ExpenseListRowView(expense: expense) {
                                // 编辑操作
                                // TODO: 实现编辑功能
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteExpense(expense)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                
                                Button {
                                    // TODO: 编辑功能
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            loadData()
        }
    }
    
    // MARK: - 计算属性
    private var hasActiveFilters: Bool {
        return selectedCategory != nil || 
               selectedAccount != nil || 
               selectedDateRange != .all ||
               !searchText.isEmpty
    }
    
    private var totalAmount: Double {
        return filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private var averageAmount: Double {
        guard !filteredExpenses.isEmpty else { return 0 }
        return totalAmount / Double(filteredExpenses.count)
    }
    
    private var groupedExpenses: [(key: String, value: [Expense])] {
        let grouped = Dictionary(grouping: filteredExpenses) { expense -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: expense.date ?? Date())
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    // MARK: - 方法
    private func loadData() {
        expenses = dataManager.fetchExpenses()
        categories = dataManager.fetchCategories()
        accounts = dataManager.fetchAccounts()
        applyFilters()
    }
    
    private func applyFilters() {
        var filtered = expenses
        
        // 文本搜索
        if !searchText.isEmpty {
            filtered = filtered.filter { expense in
                let searchFields = [
                    expense.note,
                    expense.category?.name,
                    expense.account?.name,
                    String(expense.amount)
                ].compactMap { $0 }
                
                return searchFields.contains { field in
                    field.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // 分类筛选
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category?.id == category.id }
        }
        
        // 账户筛选
        if let account = selectedAccount {
            filtered = filtered.filter { $0.account?.id == account.id }
        }
        
        // 日期范围筛选
        if let dateRange = selectedDateRange.dateInterval {
            filtered = filtered.filter { expense in
                guard let date = expense.date else { return false }
                return date >= dateRange.start && date < dateRange.end
            }
        }
        
        filteredExpenses = filtered
    }
    
    private func deleteExpense(_ expense: Expense) {
        dataManager.deleteExpense(expense)
        loadData()
    }
    
    private func sectionHeader(for dateString: String) -> some View {
        Text(formatDateString(dateString))
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
    }
    
    private func formatDateString(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM月dd日 EEEE"
        displayFormatter.locale = Locale(identifier: "zh_CN")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            return displayFormatter.string(from: date)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
}

// MARK: - 筛选条件芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let isRemovable: Bool
    let action: () -> Void
    
    init(title: String, isSelected: Bool, isRemovable: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isRemovable = isRemovable
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if isRemovable {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 支出列表行视图
struct ExpenseListRowView: View {
    let expense: Expense
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            Image(systemName: expense.category?.icon ?? "questionmark.circle")
                .foregroundColor(colorFromString(expense.category?.color ?? "gray"))
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(colorFromString(expense.category?.color ?? "gray").opacity(0.1))
                .clipShape(Circle())
            
            // 内容区域
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(expense.category?.name ?? "未分类")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(expense.account?.name ?? "未知账户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 金额和时间
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(timeString(from: expense.date ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
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
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 空列表视图
struct EmptyExpenseListView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("暂无支出记录")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("点击右上角的 + 号开始记账")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - 筛选选项视图
struct FilterOptionsView: View {
    let categories: [Category]
    let accounts: [Account]
    @Binding var selectedCategory: Category?
    @Binding var selectedAccount: Account?
    @Binding var selectedDateRange: ExpenseListView.DateRange
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("时间范围") {
                    ForEach(ExpenseListView.DateRange.allCases, id: \.self) { range in
                        HStack {
                            Text(range.rawValue)
                            Spacer()
                            if selectedDateRange == range {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDateRange = range
                        }
                    }
                }
                
                Section("支出分类") {
                    HStack {
                        Text("全部分类")
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCategory = nil
                    }
                    
                    ForEach(categories) { category in
                        HStack {
                            Image(systemName: category.icon ?? "questionmark.circle")
                                .foregroundColor(colorFromString(category.color ?? "gray"))
                            Text(category.name ?? "未知")
                            Spacer()
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = category
                        }
                    }
                }
                
                Section("支付方式") {
                    HStack {
                        Text("全部方式")
                        Spacer()
                        if selectedAccount == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAccount = nil
                    }
                    
                    ForEach(accounts) { account in
                        HStack {
                            Image(systemName: account.accountType.icon)
                                .foregroundColor(colorFromString(account.accountType.color))
                            Text(account.name ?? "未知")
                            Spacer()
                            if selectedAccount?.id == account.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAccount = account
                        }
                    }
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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
    ExpenseListView()
        .environment(\.managedObjectContext, DataManager.shared.viewContext)
        .environmentObject(DataManager.shared)
} 