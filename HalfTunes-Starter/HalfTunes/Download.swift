//
//  Download.swift
//  HalfTunes
//
//  Created by 余泽锋 on 16/4/10.
//  Copyright © 2016年 Ken Toh. All rights reserved.
//

import UIKit

class Download: NSObject {
    var url:String
    var isDownloading = false
    var progress: Float = 0.0
    
    var downloadTask: NSURLSessionDownloadTask?
    var resumeData: NSData?
    
    init(url: String) {
        self.url = url
    }
}
