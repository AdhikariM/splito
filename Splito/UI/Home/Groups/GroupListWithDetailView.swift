//
//  GroupListWithDetailView.swift
//  Splito
//
//  Created by Amisha Italiya on 24/07/24.
//

import SwiftUI
import Data
import BaseStyle

struct GroupListWithDetailView: View {
    var isFocused: FocusState<Bool>.Binding

    @ObservedObject var viewModel: GroupListViewModel

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .center, spacing: 0) {
                        if viewModel.filteredGroups.isEmpty {
                            GroupNotFoundView(geometry: geometry, viewModel: viewModel)
                        } else {
                            ForEach(viewModel.filteredGroups.indices, id: \.self) { index in
                                let group = viewModel.filteredGroups[index]
                                GroupListCellView(
                                    isFirstGroup: index == 0,
                                    isLastGroup: index == viewModel.filteredGroups.count - 1,
                                    group: group, viewModel: viewModel
                                )
                                .onTapGestureForced {
                                    viewModel.handleGroupItemTap(group.group)
                                }
                                .onLongPressGesture {
                                    addHapticEffect()
                                    isFocused.wrappedValue = false
                                    viewModel.handleGroupItemTap(group.group, isTapped: false)
                                }
                                .id(group.group.id)

                                if group.group.id == viewModel.filteredGroups.last?.group.id && viewModel.hasMoreGroups {
                                    ProgressView()
                                        .onAppear { viewModel.loadMoreGroups() }
                                }
                            }

                            VSpacer(34)
                        }
                    }
                    .id("groupList")
                    .background(GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .global).minY,
                                      perform: viewModel.manageScrollToTopBtnVisibility(offset:))
                    })
                }
                .refreshable { viewModel.fetchGroupsInitialData() }
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.showScrollToTopBtn {
                        ScrollToTopButton {
                            withAnimation { scrollProxy.scrollTo(0) }
                        }
                        .padding([.trailing, .bottom], 16)
                    }
                }
            }
        }
        .onTapGesture {
            isFocused.wrappedValue = false
        }
    }
}

private struct GroupListCellView: View {

    let isFirstGroup: Bool
    let isLastGroup: Bool
    let group: GroupInformation
    let viewModel: GroupListViewModel

    @State var showInfo: Bool = false

    init(isFirstGroup: Bool, isLastGroup: Bool = false, group: GroupInformation, viewModel: GroupListViewModel) {
        self.isFirstGroup = isFirstGroup
        self.isLastGroup = isLastGroup
        self.group = group
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                GroupProfileImageView(imageUrl: group.group.imageUrl)

                VStack(alignment: .leading, spacing: 0) {
                    Text(group.group.name)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    Text("\(group.group.members.count) people")
                        .font(.caption1())
                        .foregroundStyle(disableText)
                }

                Spacer(minLength: 8)

                let defaultCurrency = group.group.defaultCurrencyCode
                let initialBalance = group.userBalance.first(where: { $0.value != 0 })
                let defaultBalance = group.userBalance.filter { $0.key == defaultCurrency && $0.value != 0 }
                let userBalance = defaultBalance.isEmpty ? initialBalance : defaultBalance.first

                if let userBalance {
                    let isBorrowed = userBalance.value < 0
                    VStack(alignment: .trailing, spacing: 0) {
                        if group.userBalance.allSatisfy({ $0.value == 0 }) {
                            Text(group.group.hasExpenses ? "settled up" : "no expense")
                                .font(.caption1())
                                .foregroundStyle(disableText)
                                .padding(.trailing, 4)
                        } else {
                            Text(isBorrowed ? "you owe" : "you are owed")
                                .font(.caption1())

                            Text(userBalance.value.formattedCurrency(userBalance.key))
                                .font(.body1())
                            + Text(group.userBalance.count > 1 ? "*" : "")
                                .font(.body1())
                                .baselineOffset(1)
                        }
                    }
                    .lineLimit(1)
                    .foregroundStyle(isBorrowed ? errorColor : successColor)

                    if userBalance.value != 0 {
                        GroupExpandBtnView(showInfo: $showInfo, isFirstGroup: isFirstGroup)
                    }
                }
            }
            .padding(.horizontal, 16)

            if showInfo {
                HStack(alignment: .top, spacing: 0) {
                    HSpacer(56) // width of image size for padding

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(group.memberOweAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (currency, memberOweAmount) in
                            ForEach(memberOweAmount.sorted(by: { $0.key < $1.key }), id: \.key) { (memberId, amount) in
                                let name = viewModel.getMemberData(from: group.members, of: memberId)?.nameWithLastInitial ?? "Unknown"
                                GroupExpenseMemberOweView(name: name, amount: amount, currency: currency)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            showInfo = isFirstGroup && group.userBalance.allSatisfy({ $0.value != 0 })
        }

        if !isLastGroup {
            Divider()
                .frame(height: 1)
                .background(dividerColor)
        }
    }
}

private struct GroupExpandBtnView: View {

    @Binding var showInfo: Bool

    let isFirstGroup: Bool

    var body: some View {
        ScrollToTopButton(icon: "chevron.down", iconColor: primaryText, bgColor: container2Color, showWithAnimation: true, size: (10, 7), isFirstGroupCell: isFirstGroup) {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                showInfo.toggle()
            }
        }
        .onAppear {
            if isFirstGroup {
                withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                    showInfo = true
                }
            }
        }
        .padding(.leading, 8)
    }
}

private struct GroupExpenseMemberOweView: View {

    let name: String
    let amount: Double
    let currency: String

    var body: some View {
        if amount > 0 {
            Group {
                Text("\(name.localized) owes you ")
                    .foregroundColor(disableText)
                + Text(amount.formattedCurrency(currency))
                    .foregroundColor(successColor)
            }
            .font(.body3())
        } else if amount < 0 {
            Group {
                Text("You owe \(name.localized) ")
                    .foregroundColor(disableText)
                + Text(amount.formattedCurrency(currency))
                    .foregroundColor(errorColor)
            }
            .font(.body3())
        }
    }
}

private struct GroupNotFoundView: View {

    let geometry: GeometryProxy
    let viewModel: GroupListViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            if !viewModel.showSearchBar {
                Image(viewModel.selectedTab == .settled ? .settleUpGroup : .unsettledGroup)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 165, height: 165)
            }

            Text(viewModel.showSearchBar ? "No results found for \"\(viewModel.searchedGroup)\"!" : viewModel.selectedTab == .settled ? "No groups settled yet!" : "No unsettled bills yet!")
                .font(.Header1())
                .foregroundStyle(primaryText)

            Text(viewModel.showSearchBar ? "No results were found that match your search criteria." : viewModel.selectedTab == .settled ? "Looks like there are no outstanding settlements in any of your groups yet." : "It seems that everything has settled down in all groups.")
                .font(.subTitle2())
                .foregroundStyle(disableText)
                .tracking(-0.2)
                .lineSpacing(4)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(minHeight: viewModel.showSearchBar ? geometry.size.height - 20 : geometry.size.height - 70, maxHeight: .infinity, alignment: .center)
    }
}
