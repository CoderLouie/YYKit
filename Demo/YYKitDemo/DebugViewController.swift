//
//  File.swift
//  YYKitDemo
//
//  Created by 李阳 on 2024/4/3.
//  Copyright © 2024 ibireme. All rights reserved.
//

import UIKit

fileprivate let db = YYSQLStorage(path: NSHomeDirectory() + "/Documents/test_sql/")!

fileprivate struct Person: Codable {
    let name: String
    let age: Int
}

fileprivate enum TestCase: String, CaseIterable {
    case save = "存储"
    case oldest
    case youngest
    case read
    
    static var index = 0
    func perform(from vc: DebugViewController) {
        switch self {
        case .save:
            Self.index += 1
            let i = Self.index
            let stu = Person(name: "xiaoming\(i)", age: i)
            guard let data = try? JSONEncoder().encode(stu) else {
                print("Encode error")
                return
            }
            print("insert row id \(db.saveItem(withValue: data))")
        case .oldest:
            guard let item = db.theOldest() else {
                print("none oldest")
                return
            }
            log(with: item)
        case .youngest:
            guard let item = db.theYoungest() else {
                print("none youngest")
                return
            }
            log(with: item)
        case .read:
            guard let item = db.getItemForRowID(2) else {
                print("none oldest")
                return
            }
            log(with: item)
        }
    }
    
    func log(with item: YYSQLStorageItem) {
        print(item.rowID, item.modTime)
        guard let per = try? JSONDecoder().decode(Person.self, from: item.value) else {
            print("Decode error")
            return
        }
        print(per)
    }
}
fileprivate class TestCaseCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
    }
}
class DebugViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        tableView = UITableView().then {
            $0.backgroundColor = .clear
            $0.tableFooterView = UIView()
            $0.contentInsetAdjustmentBehavior = .never
            $0.separatorStyle = .none
            $0.delegate = self
            $0.dataSource = self
            $0.rowHeight = 45
            $0.register(TestCaseCell.self, forCellReuseIdentifier: "TestCaseCell")
            view.addSubview($0)
            $0.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
            $0.frame = view.bounds
        }
    }
    private unowned var tableView: UITableView!
    private lazy var items: [TestCase] = TestCase.allCases
}

// MARK: - Delegate
extension DebugViewController: UITableViewDataSource {
   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       items.count
   }
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       let cell = tableView.dequeueReusableCell(withIdentifier: "TestCaseCell", for: indexPath) as! TestCaseCell
       let index = indexPath.row
       let text = String(format: "%02d. ", index) + items[index].rawValue
       cell.textLabel?.text = text
       return cell
   }
}
//
extension DebugViewController: UITableViewDelegate {
   func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       tableView.deselectRow(at: indexPath, animated: true)
       items[indexPath.row].perform(from: self)
//        Broadcaster.notify(UpdateTitle.self) {
//            $0.updateTitle("哈哈哈哈")
//        }
   }
}
