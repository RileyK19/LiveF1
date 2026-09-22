//
//  GeometryCache.swift
//  Redline
//
//  Created by Riley Koo on 9/21/26.
//

// LRU Cache for track map network calls

//enum GeometryCache {
//    private class CacheNode {
//        var next: CacheNode?
//        var prev: CacheNode?
//        var key: String
//        var val: [(lat: Double, lon: Double)]
//        
//        init(next: CacheNode? = nil, prev: CacheNode? = nil, key: String, val: [(lat: Double, lon: Double)]) {
//            self.next = next
//            self.prev = prev
//            self.key = key
//            self.val = val
//        }
//    }
//
//    private static var map: [String: CacheNode] = [:]
//    private static let listHead = CacheNode(key: "", val: [])
//    private static let listTail = CacheNode(key: "", val: [])
//    private static var count: Int = 0
//    private static var maxCount: Int = 3
//    private static var initialized: Bool = false
//    
//    static func initialize() {
//        if initialized { return }
//        listHead.next = listTail
//        listTail.prev = listHead
//        initialized = true
//    }
//    
//    static func load(trackID: String) -> [(lat: Double, lon: Double)]? {
//        self.initialize()
//        self.moveToTail(nil, trackID: trackID)
//        return map[trackID]?.val
//    }
//
//    static func save(_ points: [(lat: Double, lon: Double)], trackID: String) {
//        self.initialize()
//        if let node = map[trackID] {
//            self.moveToTail(points, trackID: trackID)
//        } else {
//            let newNode = CacheNode(next: listTail, key: trackID, val: points)
//            map[trackID] = newNode
//            count += 1
//            if let endPrev = listTail.prev {
//                endPrev.next = newNode
//                newNode.prev = endPrev
//            }
//            listTail.prev = newNode
//            if count > maxCount {
//                if let headNext = listHead.next {
//                    map[headNext.key] = nil
//                    listHead.next = headNext.next
//                    if let headNextNext = headNext.next {
//                        headNextNext.prev = listHead
//                    }
//                }
//                count -= 1
//            }
//            
//        }
//    }
//    
//    private static func moveToTail(_ points: [(lat: Double, lon: Double)]?, trackID: String) {
//        if let node = map[trackID] {
//            if let points = points {
//                node.val = points
//            }
//            if let prev = node.prev, let next = node.next {
//                prev.next = next
//                next.prev = prev
//            }
//            if let endPrev = listTail.prev {
//                node.prev = endPrev
//                endPrev.next = node
//            }
//            node.next = listTail
//            listTail.prev = node
//        }
//    }
//}
