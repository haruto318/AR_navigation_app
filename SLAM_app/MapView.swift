//
//  MapView.swift
//  SLAM_app
//
//  Created by Haruto Hamano on 2024/06/17.
//

import UIKit

class MapView: UIView {
    var path: [Node] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Ensure there is a path to draw
        guard let context = UIGraphicsGetCurrentContext(), !path.isEmpty else { return }
        
        context.setLineWidth(2.0)
        context.setStrokeColor(UIColor.red.cgColor)
        
        // Define the coordinates and order
        let coordinates: [(x: CGFloat, y: CGFloat)] = [
            (x: 127, y: 361),
            (x: 145, y: 361),
            (x: 165, y: 361),
            (x: 145, y: 401.5),
            (x: 127, y: 442),
            (x: 145, y: 442),
            (x: 165, y: 442),
            (x: 145, y: 484.5),
            (x: 127, y: 527),
            (x: 145, y: 527),
            (x: 165, y: 527),
            (x: 145, y: 568),
            (x: 127, y: 609),
            (x: 145, y: 609),
            (x: 145, y: 650),
            (x: 127, y: 688),
            (x: 145, y: 688),
            (x: 145, y: 729),
            (x: 127, y: 771),
            (x: 145, y: 771),
            (x: 165, y: 771),
            (x: 145, y: 812),
            (x: 127, y: 850),
            (x: 145, y: 850),
            (x: 165, y: 850)
        ]
        
        let order = ["G", "m", "H", "l", "F", "k", "I", "j", "E", "i", "J", "h", "D", "g", "f", "C", "e", "d", "B", "c", "M", "b", "A", "a", "N"]
        
        // Create a dictionary to map letters to coordinates
        var coordinatesDict = [String: (x: CGFloat, y: CGFloat)]()
        for (index, letter) in order.enumerated() {
            coordinatesDict[letter] = coordinates[index]
        }
        
        print(coordinatesDict)
        
        // Update nodes' coordinates based on the given path
        for node in path {
            if let coord = coordinatesDict[String(node.id)] {
                node.x = Int(coord.x)
                node.y = Int(coord.y)
            }
        }
        
        // Draw the path
        let firstNode = path[0]
        context.move(to: CGPoint(x: firstNode.x, y: firstNode.y))
        
        for node in path.dropFirst() {
            context.addLine(to: CGPoint(x: node.x, y: node.y))
        }
        
        context.strokePath()
        
        // Draw the letters at each point
//        for node in path {
//            let point = CGPoint(x: node.x, y: node.y)
//            let attributes: [NSAttributedString.Key: Any] = [
//                .font: UIFont.systemFont(ofSize: 12),
//                .foregroundColor: UIColor.black
//            ]
//            let attributedString = NSAttributedString(string: String(node.id), attributes: attributes)
////            attributedString.draw(at: CGPoint(x: point.x - 10, y: point.y - 10))
//        }
    }
}
