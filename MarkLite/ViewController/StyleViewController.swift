//
//  StyleViewController.swift
//  Markdown
//
//  Created by 朱炳程 on 2020/2/25.
//  Copyright © 2020 zhubch. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class StyleViewController: UIViewController, UITableViewDelegate,UITableViewDataSource {
    var items = [/"FontSize",/"Style",/"CodeStyle"]
           
    let table = UITableView(frame: CGRect(), style: .grouped)
       
    let styles: OptionsWraper? = {
       let path = resourcesPath + "/Styles/"
       
       guard let subPaths = FileManager.default.subpaths(atPath: path) else { return nil }
       
       let items = subPaths.map{ $0.replacingOccurrences(of: ".css", with: "")}.filter{!$0.hasPrefix(".")}.sorted(by: >)
       let index = items.index{ Configure.shared.markdownStyle.value == $0 }
       let wraper = OptionsWraper(selectedIndex: index, editable: true, title: /"Style", items: items) {
           Configure.shared.markdownStyle.value = $0.toString
       }
       return wraper
    }()
   
    let highlight: OptionsWraper? = {
       let path = resourcesPath + "/Highlight/highlight-style/"
       
       guard let subPaths = FileManager.default.subpaths(atPath: path) else { return nil }
       
       let items = subPaths.map{ $0.replacingOccurrences(of: ".css", with: "")}.filter{!$0.hasPrefix(".")}
       let index = items.index{ Configure.shared.highlightStyle.value == $0 }
       let wraper = OptionsWraper(selectedIndex: index, editable: false, title: /"CodeStyle", items: items) {
           Configure.shared.highlightStyle.value = $0.toString
       }
       return wraper
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        title = /"Settings"
    }
       
    override func viewDidLayoutSubviews() {
          super.viewDidLayoutSubviews()
          
          table.frame = self.view.bounds
    }
      
    func setupUI() {
        navBar?.setTintColor(.navTint)
        navBar?.setBackgroundColor(.navBar)
        navBar?.setTitleColor(.navTitle)
        
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 48
        table.estimatedRowHeight = 48
        table.setSeparatorColor(.primary)
        table.setBackgroundColor(.tableBackground)
        view.addSubview(table)
    }
    
    @objc func fontChanged(_ sender: UIStepper!) {
        Configure.shared.fontSize.value = Int(sender.value)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.items.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = BaseTableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = self.items[indexPath.section]
        cell.accessoryType = .disclosureIndicator

        if indexPath.section == 0 {
            cell.accessoryType = .none
            cell.selectionStyle = .none
            let stepper = UIStepper()
            stepper.addTarget(self, action: #selector(fontChanged(_:)), for: .valueChanged)
            cell.addSubview(stepper)
            stepper.maximumValue = 24
            stepper.minimumValue = 14
            stepper.value = Double(Configure.shared.fontSize.value)
            stepper.snp.makeConstraints { maker in
                maker.centerY.equalToSuperview()
                maker.right.equalToSuperview().offset(-16)
            }
            _ = Configure.shared.fontSize.asObservable().subscribe(onNext: { size in
                cell.textLabel?.text = /"FontSize" + ": \(size)"
            })
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        impactIfAllow()
        if indexPath.section == 0 {
            
        } else if indexPath.section == 1 {
            let vc = OptionsViewController()
            vc.options = styles
            pushVC(vc)
        } else if indexPath.section == 2 {
            let vc = OptionsViewController()
            vc.options = highlight
            pushVC(vc)
        }
    }
 
}

