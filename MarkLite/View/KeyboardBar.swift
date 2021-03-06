//
//  KeyboardBar.swift
//  Markdown
//
//  Created by zhubch on 2017/7/11.
//  Copyright © 2017年 zhubch. All rights reserved.
//

import UIKit
import Alamofire
import RxSwift

fileprivate var width: CGFloat = {
    return isPad ? 50 : 40
}()

protocol ButtonConvertiable {
    func makeButton() -> UIButton
}

extension UIImage: ButtonConvertiable {
    func makeButton() -> UIButton {
        let button = UIButton(type: UIButtonType.system)
        button.setImage(self, for: .normal)
        button.contentEdgeInsets = isPad ? UIEdgeInsetsMake(15, 15, 15, 15) : UIEdgeInsetsMake(12, 12, 12, 12)
        return button
    }
}

extension String: ButtonConvertiable {
    func makeButton() -> UIButton {
        let button = UIButton(type: UIButtonType.system)
        button.setTitle(self, for: .normal)
        button.titleLabel?.font = UIFont.font(ofSize: isPad ? 18 : 16, bold: true)
        return button
    }
}

fileprivate let uploadURL = ""
class KeyboardBar: UIView {
    let scrollView = UIScrollView()
    var endButton: UIButton!

    let items: [(ButtonConvertiable,Selector)] = {
        var items: [(ButtonConvertiable,Selector)] = [
        (#imageLiteral(resourceName: "bar_tab"), #selector(tapTab(_:))),
        (#imageLiteral(resourceName: "bar_image"), #selector(tapImage(_:))),
        (#imageLiteral(resourceName: "bar_link"), #selector(tapLink)),
        (#imageLiteral(resourceName: "bar_header"), #selector(tapHeader)),
        (#imageLiteral(resourceName: "bar_bold"), #selector(tapBold)),
        (#imageLiteral(resourceName: "bar_italic"), #selector(tapItalic)),
        (#imageLiteral(resourceName: "highlight"), #selector(tapHighliht)),
        (#imageLiteral(resourceName: "bar_deleteLine"), #selector(tapDeletion)),
        (#imageLiteral(resourceName: "bar_quote"), #selector(tapQuote)),
        (#imageLiteral(resourceName: "bar_code"), #selector(tapCode)),
        (#imageLiteral(resourceName: "bar_olist"), #selector(tapOList)),
        (#imageLiteral(resourceName: "bar_ulist"), #selector(tapUList)),
        (#imageLiteral(resourceName: "bar_todolist"), #selector(tapTodoList))
        ]
        items.append(contentsOf: Configure.shared.keyboardBarItems.mapFilter(mapFunction: { item -> (ButtonConvertiable,Selector) in
            return (item, #selector(tapChar(_:)))
        }))
        return items
    }()
    
    weak var textView: UITextView?
    weak var viewController: UIViewController?
    weak var menu: MenuView?
    weak var file: File?
    
    let bag = DisposeBag()
    var imagePicker: ImagePicker?
    var textField: UITextField?
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, w: windowWidth, h: width))

        setBackgroundColor(.tableBackground)
        
        items.forEachEnumerated { (index, item) in
            let button = item.0.makeButton()
            button.addTarget(self, action: item.1, for: .touchUpInside)
            button.tintColor = .gray
            button.tag = index
            button.frame = CGRect(x: CGFloat(index) * width, y: 0, w: width, h: width)
            self.scrollView.addSubview(button)
        }
        scrollView.contentSize = CGSize(width: CGFloat(items.count) * width, height: width)
        addSubview(scrollView)
        
        endButton = #imageLiteral(resourceName: "bar_keyboard").makeButton()
        endButton.tintColor = .gray
        endButton.addTarget(self, action: #selector(hideKeyboard), for: .touchUpInside)
        addSubview(endButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = CGRect(x: 0, y: 0, w: w - width, h: width)
        endButton.frame = CGRect(x: w - width, y: 0, w: width, h: width)
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
    }
    
    @objc func hideKeyboard() {
        impactIfAllow()
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
        textView?.resignFirstResponder()
    }
    
    @objc func tapChar(_ sender: UIButton) {
        let char = sender.currentTitle ?? ""
        textView?.insertText(char)
    }
    
    @objc func tapTab(_ sender: UIButton) {
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
        let pos = sender.superview!.convert(sender.center, to: sender.window)
        let menu = MenuView(items: [/"&nbsp;",/"&emsp;",/"Tab"].map{($0,false)},
                 postion: CGPoint(x: pos.x - 20, y: pos.y - 150)) { [weak self] (index) in
                    let texts = ["&nbsp;","&emsp;","\t"]
                    self?.textView?.insertText(texts[index])
        }
        menu.show()
        self.menu = menu
    }

    @objc func tapImage(_ sender: UIButton) {
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
        guard let textView = self.textView, let vc = viewController else { return }

        let pos = sender.superview!.convert(sender.center, to: sender.window)
        let menu = MenuView(items: [/"PickFromPhotos",/"PickFromCamera",/"RecentUpload"].map{($0,false)},
                 postion: CGPoint(x: pos.x - 20, y: pos.y - 150)) { [weak self] (index) in
                    if index == 0 {
                        self?.imagePicker = ImagePicker(viewController: vc){ self?.didPickImage($0) }
                        self?.imagePicker?.pickFromLibray()
                    } else if index == 1 {
                        self?.imagePicker = ImagePicker(viewController: vc){ self?.didPickImage($0) }
                        self?.imagePicker?.pickFromCamera()
                    } else {
                        let vc = RecentImagesViewController()
                        let nav = UINavigationController(rootViewController: vc)
                        nav.modalPresentationStyle = .formSheet
                        vc.didPickRecentImage = { url in
                            Configure.shared.recentImages.removeAll { $0 == url }
                            Configure.shared.recentImages.insert(url, at: 0)
                            let currentRange = textView.selectedRange
                            let insertText = /"Alt"
                            textView.insertText("![\(insertText)](\(url))")
                            textView.selectedRange = NSMakeRange(currentRange.location + 2, insertText.length)
                        }
                        self?.viewController?.presentVC(nav)
                    }
        }
        menu.show()
        self.menu = menu
    }
    
    @objc func tapLink() {
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
        guard let vc = viewController else { return }
        vc.showAlert(title: /"InsertHref", message: "", actionTitles: [/"Cancel",/"OK"], textFieldconfigurationHandler: { (textField) in
            textField.placeholder = "http://example.com"
            textField.font = UIFont.font(ofSize: 13)
            textField.setTextColor(.primary)
            self.textField = textField
        }) { (index) in
            if index == 1 {
                self.insertLink()
            }
        }
    }
    
    func insertLink() {
        guard let textView = self.textView else { return }
        let link = textField?.text ?? ""
        let currentRange = textView.selectedRange
        let insertText = /"EnterLink"
        textView.insertText("[\(insertText)](\(link))")
        textView.selectedRange = NSMakeRange(currentRange.location + 1, insertText.length)
    }
    
    @objc func tapCode() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let text = textView.text.substring(with: currentRange)
        let isEmpty = text.length == 0
        let insertText = isEmpty ? /"EnterCode": text
        textView.insertText("`\(insertText)`")
        if isEmpty {
            textView.selectedRange = NSMakeRange(currentRange.location + 1, insertText.length)
        }
    }
    
    @objc func tapTodoList(_ sender: UIButton) {
        guard let textView = self.textView else { return }
        
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
        let pos = sender.superview!.convert(sender.center, to: sender.window)
        let menu = MenuView(items: [/"Completed",/"Uncompleted"].map{($0,false)},
                 postion: CGPoint(x: pos.x - 20, y: pos.y - 110)) { (index) in
                    let currentRange = textView.selectedRange
                    let insertText = "- [\(index == 0 ? "x" : " ")] item"
                    textView.insertText("\n\(insertText)")
                    textView.selectedRange = NSMakeRange(currentRange.location + 7, (/"item").length)
        }
        menu.show()
        self.menu = menu
    }
    
    @objc func tapUList() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let insertText = "* item"
        textView.insertText("\n\(insertText)")
        textView.selectedRange = NSMakeRange(currentRange.location + 3, (/"item").length)
    }
    
    @objc func tapOList() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let insertText = "1. item"
        textView.insertText("\n\(insertText)")
        textView.selectedRange = NSMakeRange(currentRange.location + 4, (/"item").length)
    }
    
    @objc func tapHeader(_ sender: UIButton) {
        guard let textView = self.textView else { return }
        self.menu?.dismiss(sender: self.menu?.superview as? UIControl)
        let pos = sender.superview!.convert(sender.center, to: sender.window)
        let menu = MenuView(items: [/"Header1",/"Header2",/"Header3",/"Header4"].map{($0,false)},
                 postion: CGPoint(x: pos.x - 20, y: pos.y - 190)) { (index) in
                    let currentRange = textView.selectedRange
                    let insertText = ("#" * (index+1)) + " " + /"Header"
                    textView.insertText("\n\(insertText)")
                    textView.selectedRange = NSMakeRange(currentRange.location + index + 3, (/"Header").length)
        }
        menu.show()
        self.menu = menu
    }
    
    @objc func tapDeletion() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let text = textView.text.substring(with: currentRange)
        let isEmpty = text.length == 0
        let insertText = isEmpty ? /"Delection": text
        textView.insertText("~~\(insertText)~~")
        if isEmpty {
            textView.selectedRange = NSMakeRange(currentRange.location + 2, insertText.length)
        }
    }
    
    @objc func tapQuote() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let insertText = /"Blockquote"
        textView.insertText("\n> \(insertText)\n")
        textView.selectedRange = NSMakeRange(currentRange.location + 3, insertText.length)
    }
    
    @objc func tapHighliht() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let text = textView.text.substring(with: currentRange)
        let isEmpty = text.length == 0
        let insertText = isEmpty ? /"Highlight": text
        textView.insertText("==\(insertText)==")
        if isEmpty {
            textView.selectedRange = NSMakeRange(currentRange.location + 2, insertText.length)
        }
    }
    
    @objc func tapBold() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let text = textView.text.substring(with: currentRange)
        let isEmpty = text.length == 0
        let insertText = isEmpty ? /"StrongText": text
        textView.insertText("**\(insertText)**")
        if isEmpty {
            textView.selectedRange = NSMakeRange(currentRange.location + 2, insertText.length)
        }
    }
    
    @objc func tapItalic() {
        guard let textView = self.textView else { return }

        let currentRange = textView.selectedRange
        let text = textView.text.substring(with: currentRange)
        let isEmpty = text.length == 0
        let insertText = isEmpty ? /"EmphasizedText": text
        textView.insertText("*\(insertText)*")
        if isEmpty {
            textView.selectedRange = NSMakeRange(currentRange.location + 1, insertText.length)
        }
    }
    
    func didPickImage(_ image: UIImage) {
        imagePicker = nil
        guard (self.file?.parent) != nil else {
            self.uploadImage(image)
            return
        }
        viewController?.showActionSheet(title: /"ImageUploadTips", actionTitles: [/"UploadImage",/"LocalReference"]) { [unowned self] (index) in
            if index == 0 {
                self.uploadImage(image)
            } else if index == 1 {
                self.copyImageToLocal(image)
            }
        }
    }
    
    func copyImageToLocal(_ image: UIImage) {
        guard let textView = self.textView else { return }
        guard let data = UIImageJPEGRepresentation(image, 0.8) else { return }
        viewController?.showAlert(title: nil, message: /"CreateImageTips", actionTitles: [/"CreateImage",/"Cancel"], textFieldconfigurationHandler: { textField in
            textField.clearButtonMode = .whileEditing
            textField.text = (self.file?.displayName ?? "") + " " + Date().toString(format: "HH-mm-ss")
            textField.placeholder = /"FileNamePlaceHolder"
            self.textField = textField
        }) { index in
            let name = self.textField?.text ?? Date().toString(format: "HH:mm")
            if index == 2 {
                return
            }
            guard let parent = self.file?.parent, let file = parent.createFile(name: name, contents: data, type: .image) else {
                return
            }
            let currentRange = textView.selectedRange
            let insertText = /"Alt"
            textView.insertText("![\(insertText)](\(file.name))")
            textView.selectedRange = NSMakeRange(currentRange.location + 2, insertText.length)
        }
    }
    
    func uploadImage(_ image: UIImage) {
        guard let textView = self.textView else { return }
        
        guard var data = UIImageJPEGRepresentation(image, 0.8) else { return }
        
        if data.count > 1 * 1024 * 1024 {
            if let newData = UIImageJPEGRepresentation(image, 0.6) {
                data = newData
            }
        }
        
        if data.count > 1 * 1024 * 1024 {
            if let newData = UIImageJPEGRepresentation(image, 0.4) {
                data = newData
            }
        }
        
        SVProgressHUD.show()
        Alamofire.upload(multipartFormData: { (formData) in
            formData.append(data, withName: "smfile", fileName: "temp", mimeType: "image/jpg")
        }, to: imageUploadUrl,headers:["Authorization":smKey]) { (result) in
            switch result {
            case .success(let upload,_, _):
                upload.responseJSON{ (response) in
                    if case .success(let json) = response.result {
                        SVProgressHUD.dismiss()
                        let dict = json as? [String:Any] ?? [:]
                        var url: String? = nil
                        if let data = dict["data"] as? [String:Any] {
                            url = data["url"] as? String
                        }
                        if url == nil {
                            if let message = dict["message"] as? String {
                                url = message.firstMatch("https.*jpg")
                            }
                        }
                        if let url = url {
                            Configure.shared.recentImages.insert(URL(string: url)!, at: 0)
                            if Configure.shared.recentImages.count > 20 {
                                Configure.shared.recentImages.removeLast(Configure.shared.recentImages.count - 20)
                            }
                            let currentRange = textView.selectedRange
                            let insertText = /"Alt"
                            textView.insertText("![\(insertText)](\(url))")
                            textView.selectedRange = NSMakeRange(currentRange.location + 2, insertText.length)
                        } else if let message = dict["message"] as? String {
                            SVProgressHUD.showError(withStatus: message)
                        }
                    } else if case .failure(let error) = response.result {
                        SVProgressHUD.dismiss()
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                    }
                }
            case .failure(let error):
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
        }
    }
}
