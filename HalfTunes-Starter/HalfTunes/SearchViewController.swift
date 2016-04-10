//
//  SearchViewController.swift
//  HalfTunes
//
//  Created by Ken Toh on 13/7/15.
//  Copyright (c) 2015 Ken Toh. All rights reserved.
//

import UIKit
import MediaPlayer

class SearchViewController: UIViewController {

  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var searchBar: UISearchBar!

  var searchResults = [Track]()
    var activeDownloads = [String: Download]()
    
  lazy var tapRecognizer: UITapGestureRecognizer = {
    var recognizer = UITapGestureRecognizer(target:self, action: #selector(SearchViewController.dismissKeyboard))
    return recognizer
  }()
  
    let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("bgSessionConfiguration"))
    var dataTask:NSURLSessionTask?
    
    lazy var downloadSession: NSURLSession = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
  // MARK: View controller methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    _ = self.downloadSession
    tableView.tableFooterView = UIView()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  // MARK: Handling Search Results
  
  // This helper method helps parse response JSON NSData into an array of Track objects.
  func updateSearchResults(data: NSData?) {
    searchResults.removeAll()
    do {
      if let data = data, response = try NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions(rawValue:0)) as? [String: AnyObject] {
        
        // Get the results array
        if let array: AnyObject = response["results"] {
          for trackDictonary in array as! [AnyObject] {
            if let trackDictonary = trackDictonary as? [String: AnyObject], previewUrl = trackDictonary["previewUrl"] as? String {
              // Parse the search result
              let name = trackDictonary["trackName"] as? String
              let artist = trackDictonary["artistName"] as? String
              searchResults.append(Track(name: name, artist: artist, previewUrl: previewUrl))
            } else {
              print("Not a dictionary")
            }
          }
        } else {
          print("Results key not found in dictionary")
        }
      } else {
        print("JSON Error")
      }
    } catch let error as NSError {
      print("Error parsing results: \(error.localizedDescription)")
    }
    
    dispatch_async(dispatch_get_main_queue()) {
      self.tableView.reloadData()
      self.tableView.setContentOffset(CGPointZero, animated: false)
    }
  }
  
  // MARK: Keyboard dismissal
  
  func dismissKeyboard() {
    searchBar.resignFirstResponder()
  }
  
  // MARK: Download methods
  
  // Called when the Download button for a track is tapped
  func startDownload(track: Track) {
    guard let urlString = track.previewUrl, url = NSURL(string: urlString)
        else{
            return
    }
    let download = Download(url:urlString)
    download.downloadTask = downloadSession.downloadTaskWithURL(url)
    download.downloadTask!.resume()
    download.isDownloading = true
    activeDownloads[download.url] = download
    
  }
  
  // Called when the Pause button for a track is tapped
  func pauseDownload(track: Track) {
    guard let urlString = track.previewUrl, let download = activeDownloads[urlString] else{
        return
    }
    if download.isDownloading
    {
        download.downloadTask?.cancelByProducingResumeData({ (data) in
            download.resumeData = data
        })
    }
    download.isDownloading = false
  }
  
  // Called when the Cancel button for a track is tapped
  func cancelDownload(track: Track) {
    guard let urlString = track.previewUrl, download = activeDownloads[urlString] else{
        return
    }
    download.downloadTask?.cancel()
    activeDownloads[urlString] = nil
  }
  
  // Called when the Resume button for a track is tapped
  func resumeDownload(track: Track) {
    guard let urlString = track.previewUrl, download = activeDownloads[urlString] else{
        return
    }
    if let resumeData = download.resumeData
    {
        download.downloadTask = downloadSession.downloadTaskWithResumeData(resumeData)
        download.downloadTask?.resume()
        download.isDownloading = true
    }else if let url = NSURL(string: download.url)
    {
        download.downloadTask = downloadSession.downloadTaskWithURL(url)
        download.downloadTask?.resume()
        download.isDownloading = true
    }
  }
  
   // This method attempts to play the local file (if it exists) when the cell is tapped
  func playDownload(track: Track) {
    if let urlString = track.previewUrl, url = localFilePathForUrl(urlString) {
      let moviePlayer:MPMoviePlayerViewController! = MPMoviePlayerViewController(contentURL: url)
      presentMoviePlayerViewControllerAnimated(moviePlayer)
    }
  }
  
  // MARK: Download helper methods
  
  // This method generates a permanent local file path to save a track to by appending
  // the lastPathComponent of the URL (i.e. the file name and extension of the file)
  // to the path of the app’s Documents directory.
  func localFilePathForUrl(previewUrl: String) -> NSURL? {
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
    if let url = NSURL(string: previewUrl), lastPathComponent = url.lastPathComponent {
        let fullPath = documentsPath.stringByAppendingPathComponent(lastPathComponent)
        return NSURL(fileURLWithPath:fullPath)
    }
    return nil
  }
  
  // This method checks if the local file exists at the path generated by localFilePathForUrl(_:)
  func localFileExistsForTrack(track: Track) -> Bool {
    if let urlString = track.previewUrl, localUrl = localFilePathForUrl(urlString) {
      var isDir : ObjCBool = false
      if let path = localUrl.path {
        return NSFileManager.defaultManager().fileExistsAtPath(path, isDirectory: &isDir)
      }
    }
    return false
  }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        dismissKeyboard()
        
        if !searchBar.text!.isEmpty {
            // 1
            if dataTask != nil {
                dataTask?.cancel()
            }
            // 2
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            // 3
            let expectedCharSet = NSCharacterSet.URLQueryAllowedCharacterSet()
            let searchTerm = searchBar.text!.stringByAddingPercentEncodingWithAllowedCharacters(expectedCharSet)!
            // 4
            let url = NSURL(string: "https://itunes.apple.com/search?media=music&entity=song&term=\(searchTerm)")
            // 5
            dataTask = defaultSession.dataTaskWithURL(url!) {
                data, response, error in
                // 6
                dispatch_async(dispatch_get_main_queue()) {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
                // 7
                if let error = error {
                    print(error.localizedDescription)
                } else if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self.updateSearchResults(data)
                    }
                }
            }
            // 8
            dataTask?.resume()
        }
    }
  
    
  func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
    return .TopAttached
  }
    
  func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
    view.addGestureRecognizer(tapRecognizer)
  }
    
  func searchBarTextDidEndEditing(searchBar: UISearchBar) {
    view.removeGestureRecognizer(tapRecognizer)
  }
}

// MARK: TrackCellDelegate

extension SearchViewController: TrackCellDelegate {
  func pauseTapped(cell: TrackCell) {
    if let indexPath = tableView.indexPathForCell(cell) {
      let track = searchResults[indexPath.row]
      pauseDownload(track)
      tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
    }
  }
  
  func resumeTapped(cell: TrackCell) {
    if let indexPath = tableView.indexPathForCell(cell) {
      let track = searchResults[indexPath.row]
      resumeDownload(track)
      tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
    }
  }
  
  func cancelTapped(cell: TrackCell) {
    if let indexPath = tableView.indexPathForCell(cell) {
      let track = searchResults[indexPath.row]
      cancelDownload(track)
      tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
    }
  }
  
  func downloadTapped(cell: TrackCell) {
    if let indexPath = tableView.indexPathForCell(cell) {
      let track = searchResults[indexPath.row]
      startDownload(track)
      tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
    }
  }
    func trackIndexForDownloadTask(downloadTask: NSURLSessionDownloadTask)->Int?
    {
        guard let url = downloadTask.originalRequest?.URL?.absoluteString else{
            return nil
        }
        let re = searchResults.enumerate().filter { ( index, track ) -> Bool in
            return url == track.previewUrl!
        }
        return re[0].index
    }
}

// MARK: UITableViewDataSource

extension SearchViewController: UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchResults.count
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("TrackCell", forIndexPath: indexPath) as!TrackCell
    
    // Delegate cell button tap events to this view controller
    cell.delegate = self
    
    let track = searchResults[indexPath.row]
    
    // Configure title and artist labels
    cell.titleLabel.text = track.name
    cell.artistLabel.text = track.artist

    // If the track is already downloaded, enable cell selection and hide the Download button
    let downloaded = localFileExistsForTrack(track)
    var showDownloadControls = false

    if let download = activeDownloads[track.previewUrl!]
    {
        showDownloadControls = true
        cell.progressView.progress = download.progress
        cell.progressLabel.text = (download.isDownloading) ? "Downloading...":"Paused";
        let title = (download.isDownloading) ? "Pause" : "Resume" ;
        cell.pauseButton.setTitle(title, forState: UIControlState.Normal)
    }

    cell.progressView.hidden = !showDownloadControls
    cell.progressLabel.hidden = !showDownloadControls
    

    
    cell.selectionStyle = downloaded ? UITableViewCellSelectionStyle.Gray : UITableViewCellSelectionStyle.None
    cell.downloadButton.hidden = downloaded || showDownloadControls
    cell.pauseButton.hidden = !showDownloadControls
    cell.cancelButton.hidden = !showDownloadControls
    
    return cell
  }
}

// MARK:

extension SearchViewController: UITableViewDelegate {
  func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    return 62.0
  }
  
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let track = searchResults[indexPath.row]
    if localFileExistsForTrack(track) {
      playDownload(track)
    }
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
  }
}

extension SearchViewController: NSURLSessionDownloadDelegate
{
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        
        guard let originalURL = downloadTask.originalRequest?.URL?.absoluteString, destinationURL = localFilePathForUrl(originalURL) else{
            return
        }
        print(destinationURL)
        let fileManager = NSFileManager.defaultManager()
        do{
            try fileManager.removeItemAtURL(destinationURL)
        }catch{
            
        }
        do{
            try fileManager.copyItemAtURL(location, toURL: destinationURL)
        }catch let error as NSError{
            print("Could not copy file to disk:\(error.localizedDescription)")
        }
        guard let url = downloadTask.originalRequest?.URL?.absoluteString else{
            return
        }
        activeDownloads[url] = nil
        
        guard let trackIndex = trackIndexForDownloadTask(downloadTask) else{
            return
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: trackIndex, inSection: 0)], withRowAnimation:.None)
        }
        
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let downloadURL = downloadTask.originalRequest?.URL?.absoluteString, let download = activeDownloads[downloadURL] else{
            return
        }
        download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
        let totalSize = NSByteCountFormatter.stringFromByteCount(totalBytesExpectedToWrite, countStyle: NSByteCountFormatterCountStyle.Binary)
        guard let trackIndex = trackIndexForDownloadTask(downloadTask), let trackCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow:trackIndex, inSection:0)) as? TrackCell else{
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            trackCell.progressView.progress = download.progress
            trackCell.progressLabel.text = String(format: "%.1f%% of %@", download.progress * 100, totalSize)
            
        })
    }
}

extension SearchViewController:NSURLSessionDelegate
{

    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        guard let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate else{
            return
        }

        guard let completionHandler = appDelegate.backgroundSessionCompletionHandler else{
            return
        }
        appDelegate.backgroundSessionCompletionHandler = nil
        dispatch_async(dispatch_get_main_queue()) { 
            completionHandler()
        }
    }
}






























