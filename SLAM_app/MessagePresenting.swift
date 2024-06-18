//
//  MessagePresenting.swift
//  SLAM_app
//
//  Created by Haruto Hamano on 2024/06/17.
//

import UIKit

protocol MessagePresenting {
    func presentMessage(title: String, message: String)
}

extension MessagePresenting where Self: UIViewController {
    func presentMessage(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(dismissAction)
        present(alertController, animated: true)
    }
}
