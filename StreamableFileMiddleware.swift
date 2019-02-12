/// Serves static files from a public directory.
///
///     middlewareConfig = MiddlewareConfig()
///     middlewareConfig.use(FileMiddleware.self)
///     services.register(middlewareConfig)
///
/// `FileMiddleware` will default to `DirectoryConfig`'s working directory with `"/Public"` appended.
import Vapor

/// A custom class that replaces FileMiddleware temporarily until the issue below is fixed:
/// https://github.com/vapor/vapor/issues/1762

public final class StreamableFileMiddleware: Middleware, ServiceType {
  /// See `ServiceType`.
  public static func makeService(for container: Container) throws -> StreamableFileMiddleware {
    return try .init(publicDirectory: container.make(DirectoryConfig.self).workDir + "Public/")
  }
  
  /// The public directory.
  /// - note: Must end with a slash.
  private let publicDirectory: String
  
  /// Creates a new `FileMiddleware`.
  public init(publicDirectory: String) {
    self.publicDirectory = publicDirectory.hasSuffix("/") ? publicDirectory : publicDirectory + "/"
  }
  
  /// See `Middleware`.
  public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
    // make a copy of the path
    var path = req.http.url.path
    
    // path must be relative.
    while path.hasPrefix("/") {
      path = String(path.dropFirst())
    }
    
    // protect against relative paths
    guard !path.contains("../") else {
      throw Abort(.forbidden)
    }
    
    // create absolute file path
    let filePath = publicDirectory + path
    

    if let response = rangeHeaderResponse(in: req, filePath: filePath) {
      return response
    }
    
    // check if file exists and is not a directory
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
      return try next.respond(to: req)
    }
    
    // stream the file
    return try req.streamFile(at: filePath)
  }
  
  /// This is a hack to add support for Range Headers in FileMiddleware
  /// https://github.com/vapor/vapor/issues/1762
  ///
  /// Refactored from code written by Joe Kramer
  /// https://iosdevelopers.slack.com/archives/C0G0MMJ69/p1549997917004000
  ///
  /// - Parameters:
  ///   - req: Reuest
  ///   - filePath: The string of the file location being processed
  /// - Returns: A future for a Response or nil
  func rangeHeaderResponse(in req: Request, filePath: String) -> EventLoopFuture<Response>? {
    guard
      let rangeHeader = req.http.headers.firstValue(name: HTTPHeaderName.range),
      let data = NSData(contentsOfFile: filePath),
      rangeHeader.starts(with: "bytes=") else {
        return nil
    }
    
    let split = String(rangeHeader.dropFirst(6)).split(separator: "-")
    
    guard split.count == 2, let start = Int(split[0]), let end = Int(split[1]) else {
      fatalError("Range header formatting is unexpected")
    }
    
    let length = end - start + 1
    if length > 0 {
      let retValue = data.subdata(with: NSRange(location: start, length: length))
      let res = req.response()
      res.http.status = .partialContent
      res.http.headers.add(name: HTTPHeaderName.contentLength, value: "\(length)")
      res.http.headers.add(name: HTTPHeaderName.contentRange, value: "bytes \(start)-\(end)/\(data.length)")
      res.http.headers.add(name: HTTPHeaderName.acceptRanges, value: "bytes")
      res.http.body = HTTPBody(data: retValue)
      let future = req.eventLoop.newSucceededFuture(result: res)
      return future
    }
    
    return nil
  }
}
