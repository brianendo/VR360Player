//
//  ViewController.swift
//  VR360Player
//
//  Created by Brian Endo on 6/23/16.
//  Copyright © 2016 Brian Endo. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import Haneke

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Variables
    @IBOutlet weak var tableView: UITableView!
    var videoArray = [Video]()
    var index = 0
    
    // MARK: - viewLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        tableView.delegate = self
        tableView.dataSource = self
        
        self.loadData()
        
        self.navigationController!.navigationBar.barTintColor = UIColor(red:0.06, green:0.08, blue:0.15, alpha:1.0)
        self.navigationController!.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor(red:0.29, green:0.61, blue:0.64, alpha:1.0), NSFontAttributeName: UIFont(name: "HelveticaNeue-Light", size: 26)!]
        self.title = "Metta VR"
        
        self.tableView.tableFooterView = UIView()
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 300
        self.tableView.scrollsToTop = true
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - tableView
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoArray.count
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        index = indexPath.row
        self.performSegueWithIdentifier("segueToScene3D", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "segueToScene3D" {
            let scene3DVC: Scene3DViewController = segue.destinationViewController as! Scene3DViewController
            
            var url = ""
            if videoArray[index].video480url != "" {
                url = videoArray[index].video480url
            } else {
                url = videoArray[index].video720url
            }
            scene3DVC.videoURL = url
        }
    }
    

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("feedCell", forIndexPath: indexPath) as! FeedTableViewCell
        
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero
        
        if let imageUrl = NSURL(string:videoArray[indexPath.row].thumbnail) {
            cell.previewImageView.hnk_setImageFromURL(imageUrl)
        }
        
        if let profileImageUrl = NSURL(string: videoArray[indexPath.row].creatorPic) {
            cell.profileImageView.hnk_setImageFromURL(profileImageUrl)
        }
        let title = videoArray[indexPath.row].title
        cell.titleLabel.text = title
        
        let creator = videoArray[indexPath.row].creator
        cell.nameLabel.text = creator
        
        let duration = Int(videoArray[indexPath.row].duration)
        
        let durationString = printSecondsToHoursMinutesSeconds(duration)
        cell.durationLabel.text = durationString
        
        
        return cell
    }
    
    // MARK: - Functions
    
    func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    func printSecondsToHoursMinutesSeconds (seconds:Int) -> String {
        var (h, m, s) = secondsToHoursMinutesSeconds (seconds)
        if s < 10 {
            return ("\(m):0\(s)")
        }
        return ("\(m):\(s)")
    }
    
    // Load all the data from the api
    func loadData() {
        let url = "http://www.mettavr.com/api/codingChallengeData"
        
        Alamofire.request(.GET, url, parameters: nil, headers: nil)
            .responseJSON { response in
                
                if let value = response.result.value {
                    let json = JSON(value)
//                    print(json)
                    for (_,subJson):(String, SwiftyJSON.JSON) in json {
                        var video = Video()
                        
                        if let id = subJson["id"].string {
                            video.id = id
                        }
                        if let createdAt = subJson["ts"].double {
                            let date = NSDate(timeIntervalSince1970: createdAt)
                            video.createdAt = date
                        }
                        if let creator = subJson["owner_data"]["first-name"].string {
                            video.creator = creator
                        }
                        if let creatorPic = subJson["owner_data"]["smallPicture"].string {
                            print(creatorPic)
                            video.creatorPic = creatorPic
                        }
                        if let title = subJson["title"].string {
                            video.title = title
                        }
                        if let thumbnail = subJson["thumbnail"]["versions"][0]["src"].string {
                            video.thumbnail = thumbnail
                        }
                        
                        if let views = subJson["viewCount"].int {
                            video.views = views
                        }
                        if let description = subJson["description"].string {
                            video.description = description
                        }
                        if let video480url = subJson["copies"]["480"]["url"].string {
                            video.video480url = video480url
                        }
                        if let video720url = subJson["copies"]["720"]["url"].string {
                            video.video720url = video720url
                        }
                        if let video960url = subJson["copies"]["960"]["url"].string {
                            video.video960url = video960url
                        }
                        if let duration = subJson["duration"].float {
                            video.duration = duration
                        }
                        
                        self.videoArray.append(video)
                        
                    }
                } else {
                    print("No value loaded")
                }
                self.tableView.reloadData()

        }
    }
}

