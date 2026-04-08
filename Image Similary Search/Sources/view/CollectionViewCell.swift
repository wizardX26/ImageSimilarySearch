//
//  CollectionViewCell.swift
//  AI integration sample
//
//  Created by Nguyen Duc Hung on 27/9/25.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
    class var identifier: String { return String(describing: self) }
        class var nib: UINib { return UINib(nibName: identifier, bundle: nil) }

    @IBOutlet weak var viewInclude: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var timeProcessLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Tối ưu: Setup UI nhanh hơn
        
        self.viewInclude.backgroundColor = #colorLiteral(red: 0.9960784314, green: 1, blue: 1, alpha: 1)
        self.viewInclude.clipsToBounds = false
        self.viewInclude.layer.shadowColor = #colorLiteral(red: 0.01176470588, green: 0.0862745098, blue: 0.168627451, alpha: 1)
        self.viewInclude.layer.shadowOpacity = 1
        self.viewInclude.layer.shadowOffset = CGSize.zero
        self.viewInclude.layer.shadowRadius = 8.0
        self.viewInclude.layer.cornerRadius = 8.0
        
        // // Tối ưu: Shadow setup đơn giản hơn
        // self.viewInclude.layer.shadowColor = #colorLiteral(red: 0.01176470588, green: 0.0862745098, blue: 0.168627451, alpha: 1)
        // self.viewInclude.layer.shadowOpacity = 0.3  // Giảm opacity để nhanh hơn
        // self.viewInclude.layer.shadowOffset = CGSize(width: 0, height: 2)
        // self.viewInclude.layer.shadowRadius = 4.0  // Giảm radius
        
        self.imageView.backgroundColor = UIColor.clear
        self.imageView.layer.cornerRadius = 8.0
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
            
        self.titleLabel.textColor = #colorLiteral(red: 0.006256354973, green: 0.116940625, blue: 0.2229348421, alpha: 1)
        self.titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        self.titleLabel.textAlignment = .center
    }

}
