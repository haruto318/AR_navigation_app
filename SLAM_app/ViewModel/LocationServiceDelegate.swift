//
//  LocationServiceDelegate.swift
//  SLAM_app
//
//  Created by Haruto Hamano on 2024/06/17.
//

import CoreLocation

protocol LocationServiceDelegate: class {
    func trackingLocation(for currentLocation: CLLocation)
    func trackingLocationDidFail(with error: Error)
}
