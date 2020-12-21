//
//  UIView+ViewController.swift
//  PlayKit_IMA
//
//  Created by Nilit Danan on 9/17/20.
//

import Foundation

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
