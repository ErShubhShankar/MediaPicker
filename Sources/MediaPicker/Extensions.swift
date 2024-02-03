//
//  File.swift
//  
//
//  Created by Shubham Joshi on 03/02/24.
//

import Foundation

extension FileManager {
    func sizeOfFile(atPath path: String) -> KiloByte {
        do {
            let attrs = try attributesOfItem(atPath: path)
            let sizeInKB = (attrs[.size] as? Int64 ?? 0)/1000
            return sizeInKB
        } catch {
            print("Error while getting size: ", error.localizedDescription)
        }
        return 0
    }
}
