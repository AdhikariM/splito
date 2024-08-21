//
//  GroupBalancesViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 26/04/24.
//

import Data
import SwiftUI

class GroupBalancesViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var viewState: ViewState = .initial

    @Published var groupId: String
    @Published var showSettleUpSheet: Bool = false
    @Published var memberBalances: [MembersCombinedBalance] = []
    @Published var memberOwingAmount: [String: Double] = [:]

    @Published var payerId: String?
    @Published var receiverId: String?
    @Published var amount: Double?

    private var groupMemberData: [AppUser] = []
    let router: Router<AppRoute>
    var group: Groups?

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        fetchGroupMembers()
    }

    // MARK: - Data Loading
    func fetchGroupMembers() {
        viewState = .loading
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { users in
                self.groupMemberData = users
                self.fetchGroupAndExpenses()
            }.store(in: &cancelable)
    }

    private func fetchGroupAndExpenses() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.calculateExpensesSimplified(group: group)
            }.store(in: &cancelable)
    }

    // MARK: - Helper Methods
    private func calculateExpensesSimplified(group: Groups) {
        let memberBalances = group.balance.map { MembersCombinedBalance(id: $0.id, totalOwedAmount: $0.balance) }

        DispatchQueue.main.async {
            let debts = self.settleDebts(balances: memberBalances)
            self.sortMemberBalances(memberBalances: debts)
        }
    }

    private func settleDebts(balances: [MembersCombinedBalance]) -> [MembersCombinedBalance] {
        var creditors: [(MembersCombinedBalance, Double)] = []
        var debtors: [(MembersCombinedBalance, Double)] = []

        // Separate users into creditors and debtors
        for balance in balances {
            if balance.totalOwedAmount > 0 {
                creditors.append((balance, balance.totalOwedAmount))
            } else if balance.totalOwedAmount < 0 {
                debtors.append((balance, -balance.totalOwedAmount)) // Store as positive for ease of calculation
            }
        }

        // Sort creditors and debtors by the amount they owe or are owed
        creditors.sort { $0.1 < $1.1 }
        debtors.sort { $0.1 < $1.1 }

        var updatedBalances = balances

        while !creditors.isEmpty && !debtors.isEmpty { // Process all debts
            let (creditor, credAmt) = creditors.removeFirst()
            let (debtor, debtAmt) = debtors.removeFirst()
            let minAmt = min(credAmt, debtAmt)

            // Update the balances
            if let creditorIndex = updatedBalances.firstIndex(where: { $0.id == creditor.id }) {
                updatedBalances[creditorIndex].balances[debtor.id, default: 0.0] += minAmt
            }

            if let debtorIndex = updatedBalances.firstIndex(where: { $0.id == debtor.id }) {
                updatedBalances[debtorIndex].balances[creditor.id, default: 0.0] -= minAmt
            }

            // Reinsert any remaining balances
            if credAmt > debtAmt {
                creditors.insert((creditor, credAmt - debtAmt), at: 0)
            } else if debtAmt > credAmt {
                debtors.insert((debtor, debtAmt - credAmt), at: 0)
            }
        }
        return updatedBalances
    }

    private func sortMemberBalances(memberBalances: [MembersCombinedBalance]) {
        guard let userId = preference.user?.id, let userIndex = memberBalances.firstIndex(where: { $0.id == userId }) else { return }

        var sortedMembers = memberBalances

        var userBalance = sortedMembers.remove(at: userIndex)
        userBalance.isExpanded = userBalance.totalOwedAmount != 0
        sortedMembers.insert(userBalance, at: 0)

        sortedMembers.sort { member1, member2 in
            if member1.id == userId { true } else if member2.id == userId { false } else { getMemberName(id: member1.id) < getMemberName(id: member2.id) }
        }

        self.memberBalances = sortedMembers
        self.viewState = .initial
    }

    private func getMemberDataBy(id: String) -> AppUser? {
        return groupMemberData.first(where: { $0.id == id })
    }

    func getMemberImage(id: String) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return member.imageUrl ?? ""
    }

    func getMemberName(id: String, needFullName: Bool = false) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return needFullName ? member.fullName : member.nameWithLastInitial
    }

    // MARK: - User Actions
    func handleBalanceExpandView(id: String) {
        if let index = memberBalances.firstIndex(where: { $0.id == id }) {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                memberBalances[index].isExpanded.toggle()
            }
        }
    }

    func handleSettleUpTap(payerId: String, receiverId: String, amount: Double) {
        self.payerId = payerId
        self.receiverId = receiverId
        self.amount = amount
        showSettleUpSheet = true
    }

    func dismissSettleUpSheet() {
        fetchGroupMembers()
        showSettleUpSheet = false
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully"))
    }
}

// MARK: - Struct to hold combined expense and user owe amount
struct MembersCombinedBalance {
    let id: String
    var isExpanded: Bool = false
    var totalOwedAmount: Double = 0
    var balances: [String: Double] = [:]
}

// MARK: - View States
extension GroupBalancesViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
