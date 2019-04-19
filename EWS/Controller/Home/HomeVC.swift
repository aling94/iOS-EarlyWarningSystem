//
//  HomeVC.swift
//  EWS
//
//  Created by Alvin Ling on 4/9/19.
//  Copyright © 2019 iOSPlayground. All rights reserved.
//

import UIKit
import GooglePlaces
import SVProgressHUD

class HomeVC: BaseVC {

    @IBOutlet weak var collection: UICollectionView!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var locNameLabel: UILabel!
    
    @IBOutlet weak var weatherIcon: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var highLabel: UILabel!
    @IBOutlet weak var lowLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    
    var myLocation: CLLocationCoordinate2D?
    var loaded = false
    
    var weatherData: WeatherResponse? {
        didSet {
            DispatchQueue.main.async {
                self.collection.reloadData()
                self.setWeatherInfo()
                SVProgressHUD.dismiss()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let loc = app.currentLocation?.coordinate {
            myLocation = loc
            locNameLabel.text = app.locationName
            fetchWeatherData()
        }
        setupUserData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        if loaded { setupUserData() }
        else { loaded = true }
    }
    
    func fetchWeatherData() {
        guard let loc = myLocation else { return }
        SVProgressHUD.show()
        APIHandler.shared.fetchWeatherData(loc.latitude, loc.longitude) { (response) in
            DispatchQueue.main.async { SVProgressHUD.dismiss() }
            guard let data = response else { return }
            self.weatherData = data
        }
    }
    
    func setWeatherInfo() {
        let data = weatherData!
        if let iconName = data.currently?.icon { weatherIcon.image = UIImage(named: iconName) }
        dateLabel.text = "\(data.date!)"
        highLabel.text = "\(data.high!) °F"
        lowLabel.text = "\(data.low!) °F"
        let summ = (data.currently?.summary)!
        summaryLabel.text = summ
    }
    
    func setupUserData() {
        guard let currentUser = FirebaseManager.shared.currentUser else { return }
        
        emailLabel.text = currentUser.email
        // Define function to set data
        let setData: (UserInfo?) -> Void = { userInfo in
            if let  loc = userInfo?.coords, self.myLocation == nil {
                self.myLocation = loc
                self.fetchWeatherData()
                self.locNameLabel.text = userInfo?.location
            } else { SVProgressHUD.dismiss() }
            DispatchQueue.main.async {
                if let pic = userInfo?.image {
                    self.userImage.image = pic
                }
            }
        }
        
        // Check if current user is already saved
        if let userInfo = FirebaseManager.shared.currentUserInfo {
            setData(userInfo)
            return
        }
        // Else fetch it
        SVProgressHUD.show()
        FirebaseManager.shared.getCurrentUserInfo(completion: setData)
    }
    
    @IBAction func searchPlaces(_ sender: Any) {
        let placesPicker = GMSPlacePicker()
        placesPicker.selectPlaceAction = { [unowned self] place in
            self.myLocation = place.coordinate
            self.locNameLabel.text = place.name
            self.fetchWeatherData()
        }
        present(placesPicker, animated: true)
    }
}

extension HomeVC: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return weatherData?.daily?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WeatherCell", for: indexPath) as! WeatherCell
        setCell(cell, indexPath: indexPath)
        return cell
    }
    
    func setCell(_ cell: WeatherCell, indexPath: IndexPath) {
        let data = (weatherData?.daily?[indexPath.item])!
        cell.icon.image = UIImage(named: data.icon!)
        cell.highLabel.text = "\(data.high!) °F"
        cell.lowLabel.text = "\(data.low!) °F"
        cell.dateLabel.text = data.day
    }
}
