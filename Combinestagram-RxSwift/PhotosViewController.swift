/// Copyright (c) 2024
/// Combinestagram-RxSwift
/// JustinWang    
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Photos
import RxSwift

class PhotosViewController: UICollectionViewController {
  
  // MARK: public properties
  
  // MARK: private properties
  private lazy var photos = PhotosViewController.loadPhotos()
  private lazy var imageManager = PHCachingImageManager()
  private let bag = DisposeBag()
  
  private lazy var thumbnailSize: CGSize = {
    let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
    return CGSize(
      width: cellSize.width * UIScreen.main.scale,
      height: cellSize.height * UIScreen.main.scale
    )
  }()
  
  //  define a private PublishSubject that will emit the selected photos
  private let selectedPhotoSubject = PublishSubject<UIImage>()
  // exposes the subject’s observable
  var selectedPhotos: Observable<UIImage> {
    return selectedPhotoSubject.asObserver()
  }
  
  static func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }
  
  // MARK: View Controller
  override func viewDidLoad() {
    super.viewDidLoad()
    let authorized = PHPhotoLibrary.authorized.share()
    authorized
      // ignore all false elements
      // In case the user doesn’t grant access, your subscription’s onNext code will never get executed
      .skipWhile { !$0 }
      .take(1)
      .subscribe(
        onNext: { [weak self] _ in
          self?.photos = PhotosViewController.loadPhotos()
          // requestAuthorization(_:) doesn’t guarantee on which thread your completion closure will be executed, so it might fall on a background thread
          DispatchQueue.main.async {
            self?.collectionView.reloadData()
          }
        }
      )
      .disposed(by: bag)
    // authorization return false situation
    authorized
      .skip(1)
      .takeLast(1)
      .filter { !$0 }
      .subscribe(
        onNext: { [weak self] _ in
          guard let errorMessage = self?.errorMessage else {
            return
          }
          DispatchQueue.main.async(execute: errorMessage)
        }
      )
      .disposed(by: bag)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // make the subscription in main view controller disposed after finish selecting the images
    selectedPhotoSubject.onCompleted()
  }
  
  // MARK: UICollectionView
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    let asset = photos.object(at: indexPath.item)
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell
    
    cell.representedIdentifier = asset.localIdentifier
    print(thumbnailSize)
    imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil) { image, _ in
      if cell.representedIdentifier == asset.localIdentifier {
        cell.imageView.image = image
      }
    }
    
    return cell
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = photos.object(at: indexPath.item)
    
    if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
      cell.flash()
    }
    
    imageManager.requestImage(for: asset, targetSize: view.frame.size, contentMode: .aspectFill, options: nil) { [weak self] image, info in
      guard let image = image, let info = info else { return }
      
      // check if the image is the thumbnail or the full version of the asset
      if let isThumbnail = info[PHImageResultIsDegradedKey as NSString] as? Bool, !isThumbnail {
        // In the event you receive the full-size image, you call onNext(_) on your subject and provide it with the full photo
        self?.selectedPhotoSubject.onNext(image)
      }
    }
  }
  
  private func errorMessage() {
    alert(title: "No access to Camera Roll", text: "You can grant access to Combinestagram from the Settings app")
      // have to convert your Completable to an observable via asObservable() as the take(_:scheduler:) operator is not available on the Completable type.
      .asObservable()
      // a filtering operator much like take(1) or takeWhile(...). take(_:scheduler:) takes elements from the source sequence for the given time period. Once the time interval has passed, the resulting sequence completes
      .take(.seconds(5), scheduler: MainScheduler.instance)
      .subscribe(
        onCompleted: { [weak self] in
          self?.dismiss(animated: true, completion: nil)
          _ = self?.navigationController?.popViewController(animated: true)
        }
      )
      .disposed(by: bag)
  }
  
}
