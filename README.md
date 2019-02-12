# StreamableFileMiddleware
A custom Vapor FileMiddleware with support for Range Headers

It fixes a bug that prevents Safari from streaming HTML5 videos hosted on a Vapor server.

To use this replacement FileMiddleware, follow the steps below:
1. Copy the `StreamableFileMiddleware.swift` file into your Vapor project's "App" folder
2. In your Configure.swift file, replace any configuration using `FileMiddleware.self` with `StreamableFileMiddleware.self`.

For example, my `configure.swift` file contains the following registrations:

```
  var middlewareConfig = MiddlewareConfig()
  services.register(StreamableFileMiddleware.self)
  middlewareConfig.use(StreamableFileMiddleware.self)
  services.register(middlewareConfig)
```
