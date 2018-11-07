import XCTest
@testable import PointFreeFramework

class PointFreeFrameworkTests: SnapshotTestCase {
  func testEpisodesView() {
    let episodesVC = EpisodeListViewController(episodes: episodes)

    assertSnapshot(matching: episodesVC)
  }

  func testGreeting() {
    let greeting = """
Welcome to Point-Free!
-----------------------------------------
A Swift video series exploring functional
programming and more.
"""

    assertSnapshot(matching: greeting)
  }
}











protocol Snapshottable {
  associatedtype Snapshot: Diffable
  static var pathExtension: String { get }
  var snapshot: Snapshot { get }
}

protocol Diffable {
  static func diff(old: Self, new: Self) -> (String, [XCTAttachment])?
  static func from(data: Data) -> Self
  var data: Data { get }
}

extension String: Diffable {
  static func diff(old: String, new: String) -> (String, [XCTAttachment])? {
    guard let string = Diff.lines(old, new) else { return nil }
    return ("Difference:\n\n\(string)", [XCTAttachment(string: string)])
  }

  static func from(data: Data) -> String {
    return String(decoding: data, as: UTF8.self)
  }

  var data: Data {
    return Data(self.utf8)
  }
}

extension String: Snapshottable {
  static let pathExtension = "txt"

  var snapshot: String {
    return self
  }
}

extension UIImage: Diffable {
  var data: Data {
    return self.pngData()!
  }

  static func from(data: Data) -> Self {
    return self.init(data: data, scale: UIScreen.main.scale)!
  }

  static func diff(old: UIImage, new: UIImage) -> (String, [XCTAttachment])? {
    guard let image = Diff.images(old, new) else { return nil }
    return ("Expected new@\(new.size) to match old@\(old.size)", [old, new, image].map(XCTAttachment.init))
  }
}

extension Snapshottable where Snapshot == UIImage {
  static var pathExtension: String {
    return "png"
  }
}

extension UIView: Snapshottable {
//  var snapshot: UIImage {
//    return self.layer.snapshot
//  }

  static let pathExtension = "txt"

  var snapshot: String {
    self.setNeedsLayout()
    self.layoutIfNeeded()

    return (self.perform(Selector(("recursiveDescription")))?
      .takeUnretainedValue() as! String)
    .replacingOccurrences(of: ":?\\s*0x[\\da-f]+(\\s*)", with: "$1", options: .regularExpression)
  }
}

extension UIImage: Snapshottable {
  var snapshot: UIImage {
    return self
  }
}

extension CALayer: Snapshottable {
  var snapshot: UIImage {
    return UIGraphicsImageRenderer(size: self.bounds.size)
      .image { ctx in self.render(in: ctx.cgContext) }
  }
}

extension UIViewController: Snapshottable {
  static let pathExtension = "txt"
  var snapshot: String {
    return self.view.snapshot
  }
}

class SnapshotTestCase: XCTestCase {
  var record = false

  func assertSnapshot<S: Snapshottable>(
    matching value: S,
    file: StaticString = #file,
    function: String = #function,
    line: UInt = #line) {

    let snapshot = value.snapshot
    let referenceUrl = snapshotUrl(file: file, function: function)
      .appendingPathExtension(S.pathExtension)

    if !self.record, let referenceData = try? Data(contentsOf: referenceUrl) {
      let reference = S.Snapshot.from(data: referenceData)
      guard let (failure, attachments) = S.Snapshot.diff(old: reference, new: snapshot) else { return }
//      guard let difference = Diff.images(reference, snapshot) else { return }
      XCTFail(failure, file: file, line: line)
      XCTContext.runActivity(named: "Attached failure diff") { activity in
        attachments
          .forEach { image in activity.add(image) }
      }
    } else {
      try! snapshot.data.write(to: referenceUrl)
      XCTFail("Recorded: …\n\"\(referenceUrl.path)\"", file: file, line: line)
    }
  }
}
