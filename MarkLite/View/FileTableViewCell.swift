//
//  FileTableViewCell.swift
//  MarkLite
//
//  Created by zhubch on 2017/6/22.
//  Copyright © 2017年 zhubch. All rights reserved.
//

import UIKit

class FileTableViewCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var checkButton: UIButton!
    @IBOutlet weak var iconImage: UIImageView!
    
    var showCheckButton: Bool = false {
        didSet {
            checkButton.isHidden = !showCheckButton
            layoutIfNeeded()
        }
    }
    
    var file: File! {
        didSet {
            nameLabel.text = file.name
            sizeLabel.text = file.size.readabelSize
            iconImage.image = file.type == .text ? #imageLiteral(resourceName: "note") : #imageLiteral(resourceName: "folder")
        }
    }

}
