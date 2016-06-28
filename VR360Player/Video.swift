//
//  Video.swift
//  VR360Player
//
//  Created by Brian Endo on 6/23/16.
//  Copyright © 2016 Brian Endo. All rights reserved.
//

import Foundation

struct Video {
    var id: String
    var creator: String
    var creatorPic: String
    var title: String
    var createdAt: NSDate
    var thumbnail: String
    var views: Int
    var description: String
    var video480url: String
    var video720url: String
    var video960url: String
    var duration: Float
    
    init() {
        self.id = ""
        self.creator = ""
        self.creatorPic = ""
        self.title = ""
        self.createdAt = NSDate()
        self.thumbnail = ""
        self.views = 0
        self.description = ""
        self.video480url = ""
        self.video720url = ""
        self.video960url = ""
        self.duration = 0.000
    }
}