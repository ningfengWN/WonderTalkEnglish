import Foundation

struct LessonLine: Identifiable {
    let id: Int
    let english: String
    let chinese: String
}

struct Lesson: Identifiable {
    let id: String
    let category: String
    let title: String
    let subtitle: String
    let lines: [LessonLine]

    var fullAudioStem: String { "\(id)_full" }
    func sentenceStem(_ index: Int) -> String {
        "\(id)_\(String(format: "%02d", index + 1))"
    }

    static let all: [Lesson] = [
        Lesson(
            id: "rates", category: "FINANCE · B1–B2",
            title: "Why Interest Rates Matter",
            subtitle: "Borrowing, valuation and expectations",
            lines: [
                .init(id: 0, english: "When a central bank raises interest rates, borrowing usually becomes more expensive.", chinese: "当中央银行提高利率时，借贷通常会变得更加昂贵。"),
                .init(id: 1, english: "Businesses may postpone investment projects, while households may reduce spending.", chinese: "企业可能推迟投资项目，家庭则可能减少支出。"),
                .init(id: 2, english: "Higher interest rates can also change the way investors value companies.", chinese: "更高的利率也可能改变投资者对企业的估值方式。"),
                .init(id: 3, english: "Analysts often discount future cash flows to estimate what a business is worth today.", chinese: "分析师通常对未来现金流进行折现，以估计企业今天的价值。"),
                .init(id: 4, english: "When the discount rate rises, distant cash flows generally become less valuable in today's terms.", chinese: "当折现率上升时，较远期的现金流以现值计算通常会下降。"),
                .init(id: 5, english: "This is one reason why fast-growing companies can be sensitive to interest rate changes.", chinese: "这也是高速成长型公司可能对利率变化较为敏感的原因之一。"),
                .init(id: 6, english: "However, stock prices also depend on profits, competition, risk and market expectations.", chinese: "不过，股价还取决于利润、竞争、风险和市场预期。"),
                .init(id: 7, english: "A thoughtful investor asks not only what changed, but also what the market had already expected.", chinese: "审慎的投资者不仅关心发生了什么变化，也关心市场此前已经预期了什么。")
            ]
        ),
        Lesson(
            id: "renaissance", category: "HISTORY · B1–B2",
            title: "The Italian Renaissance",
            subtitle: "Commerce, patronage and classical learning",
            lines: [
                .init(id: 0, english: "The Renaissance did not begin with a single event or a single brilliant artist.", chinese: "文艺复兴并非始于某个单一事件或某位天才艺术家。"),
                .init(id: 1, english: "It developed gradually in a network of Italian cities, including Florence and Venice.", chinese: "它逐渐发展于包括佛罗伦萨和威尼斯在内的意大利城市网络之中。"),
                .init(id: 2, english: "Trade and finance helped some merchant families accumulate substantial wealth.", chinese: "贸易和金融帮助一些商人家族积累了可观的财富。"),
                .init(id: 3, english: "These families supported painters, architects and scholars through patronage.", chinese: "这些家族通过赞助支持画家、建筑师和学者。"),
                .init(id: 4, english: "Patronage created opportunities, but it also shaped which projects received attention.", chinese: "赞助创造了机会，但也影响了哪些项目能够获得关注。"),
                .init(id: 5, english: "Competition between city-states encouraged rulers to display their prestige through art.", chinese: "城邦之间的竞争促使统治者通过艺术展示自身声望。"),
                .init(id: 6, english: "At the same time, humanist scholars studied ancient Greek and Roman writing with renewed interest.", chinese: "与此同时，人文主义学者以新的热情研究古希腊和古罗马著作。"),
                .init(id: 7, english: "The Renaissance emerged from the interaction of economic, political and intellectual forces.", chinese: "文艺复兴源于经济、政治和思想力量之间的相互作用。")
            ]
        )
    ]
}
