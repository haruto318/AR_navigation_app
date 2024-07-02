//
//  Node.swift
//  SLAM_app
//
//  Created by Haruto Hamano on 2024/06/17.
//

import UIKit

class Node: Hashable {
    let id: Character
    var x: Int
    var y: Int
    var neighbors: [Node] = []
    var gCost: Int = Int.max
    var hCost: Int = 0
    var parent: Node?
    var ARPoint: (z: Float, y: Float) = (z: 0, y: 0)
    var pointType: Int = 0

    var fCost: Int {
        return gCost + hCost
    }

    init(id: Character, x: Int, y: Int) {
        self.id = id
        self.x = x
        self.y = y
    }

    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

func aStar(startNode: Node, goalNode: Node) -> [Node] {
    var openSet: Set<Node> = [startNode]
    var closedSet: Set<Node> = []
    startNode.gCost = 0

    while !openSet.isEmpty {
        let currentNode = openSet.min(by: { $0.fCost < $1.fCost })!

        if currentNode == goalNode {
            return constructPath(goalNode: goalNode)
        }

        openSet.remove(currentNode)
        closedSet.insert(currentNode)

        for neighbor in currentNode.neighbors {
            if closedSet.contains(neighbor) {
                continue
            }

            let tentativeGCost = currentNode.gCost + 1
            if tentativeGCost < neighbor.gCost {
                neighbor.gCost = tentativeGCost
                neighbor.hCost = heuristic(from: neighbor, to: goalNode)
                neighbor.parent = currentNode

                if !openSet.contains(neighbor) {
                    openSet.insert(neighbor)
                }
            }
        }
    }

    return []
}

func heuristic(from: Node, to: Node) -> Int {
    return abs(from.x - to.x) + abs(from.y - to.y)
}

func constructPath(goalNode: Node) -> [Node] {
    var path: [Node] = []
    var currentNode: Node? = goalNode

    while let node = currentNode {
        path.insert(node, at: 0)
        currentNode = node.parent
    }
    
    path[0].ARPoint = (z: 0, y: 0)
    let startLine = path.first!.y
    
    for (index, node) in zip(path.indices, path) {
        if index == 0 { ///原点
            print("原点：\(index)")
            print("\(node.id) = \(node.x): \(node.y)")
            path[index].pointType = 0
            continue
        } else if index == 1 {
            print("後ろ：\(index)")
            path[index].ARPoint = (z: 2.2, y: 0) ///後ろ
            path[index].pointType = 1
        } else if (node.x < path[index - 1].x && startLine == 1) || (node.x > path[index - 1].x &&  startLine == 3){ ///廊下 右
            print("廊下：\(index)")
            path[index].ARPoint = path[index - 1].ARPoint
            path[index].ARPoint.y += 9.1/3
            path[index].pointType = 2
        } else if (node.x > path[index - 1].x && startLine == 1) || (node.x < path[index - 1].x &&  startLine == 3){ ///廊下 左
            print("廊下：\(index)")
            path[index].ARPoint = path[index - 1].ARPoint
            path[index].ARPoint.y -= 9.1/3
            path[index].pointType = 3
        } else if (node.x == path[index - 1].x) && node.y != startLine { ///ゴール前（startと異なるライン）
            print("ゴール前（startと異なるライン）：\(index)")
            path[index].ARPoint = path[index - 1].ARPoint
            path[index].ARPoint.z += 2.2
            path[index].pointType = 4
        } else if (node.x == path[index - 1].x) && node.y == startLine { ///ゴール前（startと同じライン）
            print("ゴール前（startと同じライン）：\(index)")
            path[index].ARPoint = path[index - 1].ARPoint
            path[index].ARPoint.z -= 2.2
            path[index].pointType = 5
        } else {
            print("その他：\(index)")
            print(path[index - 1].x)
        }
        print("\(node.id) = \(node.x): \(node.y)")
    }

    return path
}

