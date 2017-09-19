import Foundation

class ImageDownloader: Equatable {
  enum Result {
    case success(image: Image, byteCount: Int)
    case failure(Error)
  }

  let url: URL
  var task: URLSessionDataTask?
  var active = false

  var session: URLSession {
    return URLSession.shared
  }

  // MARK: - Initialization

  init(url: URL) {
    self.url = url
  }

  // MARK: - Fetching

  func start(_ preprocess: @escaping Preprocess, completion: @escaping (_ result: Result) -> Void) {
    active = true

    DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async { [weak self] in
      guard let `self` = self, self.active else {
        return
      }

      self.task = self.session.dataTask(with: self.url, completionHandler: { [weak self] data, response, error -> Void in

        guard let `self` = self, self.active else {
          return
        }

        if let error = error {
          self.complete { completion(.failure(error)) }
          return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
          self.complete { completion(.failure(ImaginaryError.invalidResponse)) }
          return
        }

        guard httpResponse.statusCode == 200 else {
          self.complete { completion(.failure(ImaginaryError.invalidStatusCode)) }
          return
        }

        guard let data = data, httpResponse.validateLength(data) else {
          self.complete { completion(.failure(ImaginaryError.invalidContentLength)) }
          return
        }

        guard let decodedImage = Decompressor.decompress(data) else {
          self.complete { completion(.failure(ImaginaryError.conversionError)) }
          return
        }

        let image = preprocess(decodedImage)

        Configuration.bytesLoaded += data.count

        if self.active {
          self.complete {
            completion(Result.success(image: image, byteCount: data.count))
          }
        }
      })

      self.task?.resume()
    }
  }

  func cancel() {
    task?.cancel()
    active = false
  }

  func complete(_ closure: @escaping () -> Void) {
    active = false

    DispatchQueue.main.async {
      closure()
    }
  }

  static func == (lhs: ImageDownloader, rhs: ImageDownloader) -> Bool {
    return lhs.active == rhs.active &&
      lhs.session == rhs.session &&
      lhs.task == rhs.task &&
      lhs.url == rhs.url
  }
}
