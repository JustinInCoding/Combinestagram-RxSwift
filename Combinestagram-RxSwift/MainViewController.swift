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
import RxSwift
import RxRelay

class MainViewController: UIViewController {
  
  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  // store the image's byte length to make the image unique after selected
  private var imageCache = [Int]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // subscribe for .next events emitted by images
    images
      // filters any elements followed by another element within the specified time interval
      // 500 milliseconds equal to 0.5 seconds but the RxTimeInterval type you use with throttle does not allow for fractions so we use 500 milliseconds instead of setting the interval in seconds
      .throttle(.milliseconds(500), scheduler: MainScheduler.instance)
      .subscribe(
        onNext: { [weak self, imagePreview] photos in
          guard let preview = imagePreview else { return }
          preview.image = photos.collage(size: preview.frame.size)
          self?.updateUI(photos: photos)
        }
      )
      // add this subscription to the view controller’s dispose bag
      .disposed(by: bag)
    
//    images
//      .subscribe(
//        onNext: { [weak self] photos in
//          self?.updateUI(photos: photos)
//        }
//      )
//      .disposed(by: bag)
  }
  
  // All of the logic is in a single place and easy to read through
  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
  
  @IBAction func actionClear() {
    images.accept([])
    imageCache = []
    navigationItem.leftBarButtonItem = nil
  }
  
  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    // call PhotoWriter.save(image) to save the current collage
    PhotoWriter.save(image)
      // convert the returned Observable to a Single
      // ensuring your subscription will get at most one element, and display a message when it succeeds or errors out
      // uncomment it if use Observer as a return type in PhotoWriter
//      .asSingle()
      .subscribe(
        onSuccess: { [weak self] id in
          self?.showMessage("Saved with id: \(id)")
          // clear the current collage if the write operation was a success
          self?.actionClear()
        }, onError: { [weak self] error in
          self?.showMessage("Error", description: error.localizedDescription)
        }
      )
      .disposed(by: bag)
  }
  
  @IBAction func actionAdd() {
//    let newImages = images.value + [UIImage(named: "IMG_1907.jpg")!]
//    images.accept(newImages)
    // instantiate PhotosViewController from the project’s storyboard and push it onto the navigation stack
    let photosViewController = storyboard!.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
    // `share` allow for multiple subscriptions to consume the elements that a single Observable produces for all of them
    let newPhotos = photosViewController.selectedPhotos
      .share()
    
    newPhotos
      .takeWhile { [weak self] image in
        let count = self?.images.value.count ?? 0
        return count < 6
      }
      .filter { newImage in
        return newImage.size.width > newImage.size.height
      }
      .filter { [weak self] newImage in
        let len = newImage.pngData()?.count ?? 0
        guard self?.imageCache.contains(len) == false else {
          return false
        }
        self?.imageCache.append(len)
        return true
      }
      .subscribe(
        onNext: { [weak self] newImage in
          guard let images = self?.images else { return }
          images.accept(images.value + [newImage])
        },
        onDisposed: {
          print("Completed photo selection")
        }
      )
      .disposed(by: bag)
    
    navigationController!.pushViewController(photosViewController, animated: true)
    
    newPhotos
      .ignoreElements()
      .subscribe(
        onCompleted: { [weak self] in
          self?.updateNavigationIcon()
        }
      )
      .disposed(by: bag)
  }
  
  private func updateNavigationIcon() {
    let icon = imagePreview.image?
      .scale(CGSize(width: 22, height: 22))
      .withRenderingMode(.alwaysOriginal)
    
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon, style: .done, target: nil, action: nil)
  }
  
  func showMessage(_ title: String, description: String? = nil) {
//    let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
//    alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { [weak self] _ in
//      self?.dismiss(animated: true, completion: nil)
//    }))
//    present(alert, animated: true, completion: nil)
    alert(title: title, text: description)
      .subscribe()
      .disposed(by: bag)
  }
}
