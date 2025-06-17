//
//  ContentView.swift
//  Money
//
//  Created by zhangshaocong6 on 2025/6/14.
//

import SwiftUI
import CoreData

struct ContentView: View {
    
    // MARK: - 环境对象
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - 状态变量
    @State private var showingAddExpense = false
    @State private var todayExpenses: Double = 0
    @State private var monthExpenses: Double = 0
    @State private var recentExpenses: [Expense] = []
    @State private var showingExpenseList = false
    
    // MARK: - URL状态管理器
    @StateObject private var urlStateManager = URLStateManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 统计卡片区域
                    statisticsSection
                    
                    // MARK: - 快速添加按钮
                    addExpenseButton
                    
                    // MARK: - 最近记录
                    recentExpensesSection
                    
                    Spacer(minLength: 100) // 为底部添加按钮留空间
                }
                .padding()
            }
            .navigationTitle("💰 记账本")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
                    .onDisappear {
                        loadData() // 添加记录后刷新数据
                    }
            }
            .sheet(isPresented: $showingExpenseList) {
                ExpenseListView()
                    .onDisappear {
                        loadData() // 从列表返回后刷新数据
                    }
            }
            .sheet(isPresented: $urlStateManager.shouldShowAddExpense) {
                AddExpenseView(prefilledData: urlStateManager.prefilledData)
                    .onDisappear {
                        urlStateManager.reset() // 重置URL状态
                        loadData() // 刷新数据
                    }
            }
        }
    }
    
    // MARK: - 统计卡片区域
    private var statisticsSection: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                // 今日支出卡片
                StatisticCard(
                    title: "今日支出",
                    amount: todayExpenses,
                    icon: "calendar",
                    color: .blue
                )
                
                // 本月支出卡片
                StatisticCard(
                    title: "本月支出",
                    amount: monthExpenses,
                    icon: "chart.bar.fill",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - 快速添加按钮
    private var addExpenseButton: some View {
        Button(action: {
            showingAddExpense = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("快速记账")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.white)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: .blue.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 最近记录区域
    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近记录")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("查看全部") {
                    showingExpenseList = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if recentExpenses.isEmpty {
                EmptyStateView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentExpenses) { expense in
                        ExpenseRowView(expense: expense)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 15)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(15)
    }
    
    // MARK: - 加载数据
    private func loadData() {
        todayExpenses = dataManager.todayExpenses()
        monthExpenses = dataManager.monthExpenses()
        recentExpenses = dataManager.fetchExpenses(limit: 5)
    }
}

// MARK: - 统计卡片视图
struct StatisticCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(amount))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }
}

// MARK: - 支出记录行视图
struct ExpenseRowView: View {
    let expense: Expense
    
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
                
                Text(timeAgoString(from: expense.date ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
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
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("还没有记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击上方按钮开始记账吧！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - 预览
#Preview {
    ContentView()
        .environment(\.managedObjectContext, DataManager.shared.viewContext)
        .environmentObject(DataManager.shared)
}
