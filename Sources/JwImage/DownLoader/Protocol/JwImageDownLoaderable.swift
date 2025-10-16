//
//  JwImageDownLoaderable.swift
//  JwImage
//
//  Created by heojiwoo on 10/15/25.
//

import Foundation

protocol JwImageDownloadable {
    func downloadImage(from url: URL, etag: String?) async throws -> JwImageData
    func cancelDownloadImage(url: URL) async
}
