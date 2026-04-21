# NIS

Lightweight, composable networking layer for Swift.

Focused on **predictable request execution**, **clear extensibility**, and **modern concurrency**.

---

## ✨ Features

* Async/Await first
* Combine bridge
* Request adaptation pipeline
* Retry handling
* Error parsing & interception
* Response analyzers (analytics / logging)
* In-flight request deduplication
* Short-lived response reuse (TTL-based)
* Fully composable components

---

## 📦 Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/your-repo/NIS.git", from: "1.0.0")
```

### CocoaPods (soon)

```ruby
pod 'NIS'
```

---

## 🚀 Quick Start

### Async / Await

```swift
let dispatcher = NISRequestDispatcher()

let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

let response: NISResponse<[User]> = await dispatcher.request(request)

switch response.result {
case .success(let users):
    print(users)
case .failure(let error):
    print(error)
}
```

### Callback (Closure-based API)

```swift
let dispatcher = NISRequestDispatcher()

let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

let cancellable = dispatcher.request(
    request: request,
    of: [User].self
) { response in
    switch response.result {
    case .success(let users):
        print(users)
    case .failure(let error):
        print(error)
    }
}

// Cancel if needed
cancellable.cancel()
```

### Combine Publisher

```swift
let dispatcher = NISRequestDispatcher()

let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

let cancellable = dispatcher
    .publisher(for: request, as: [User].self)
    .sink { response in
        switch response.result {
        case .success(let users):
            print(users)
        case .failure(let error):
            print(error)
        }
    }

// Cancel subscription
cancellable.cancel()
```

---

## 🧠 Core Concepts

### 1. Dispatcher

`NISRequestDispatcher` is the central entry point.

It orchestrates:

* request adaptation
* execution
* retry
* error handling
* response analysis
* deduplication & reuse

---

### 2. Composable Pipeline

Every stage is defined via protocol and can be replaced or composed.

---

## 🔌 Request Adapters

Modify request before execution.

```swift
struct AuthAdapter: NISRequestAdaptable {
    func adapt(request: URLRequest) async throws -> URLRequest {
        var request = request
        request.addValue("Bearer token", forHTTPHeaderField: "Authorization")
        return request
    }
}

dispatcher.requestAdapter = AuthAdapter()
```

Adapters are executed sequentially.

---

## 🔁 Retry Strategy

```swift
struct RetryStrategy: NISRequestRetryable {
    func retry(
        request: URLRequest,
        dueTo error: NISError,
        attempt: Int
    ) async -> NISRetryDecision {
        guard attempt < 3 else { return .doNotRetry }
        return .init(shouldRetry: true, delay: 1)
    }
}

dispatcher.requestRetrier = RetryStrategy()
```

---

## ⚠️ Error Handling

NIS separates **parsing backend errors** from **intercepting/normalizing them**.

---

### 🧩 Error Parser (backend → domain error)

Use `NISErrorParsable` to convert raw response payload into a meaningful error.

#### Example: JSON API error

```swift
struct APIError: Decodable, Error {
    let code: String
    let message: String
}

struct APIErrorParser: NISErrorParsable {
    func parse(data: Data?, response: HTTPURLResponse?) -> Error? {
        guard let data, let http = response, !(200...299).contains(http.statusCode) else {
            return nil
        }

        // Try decode structured error
        if let apiError = try? JSONDecoder.nis.decode(APIError.self, from: data) {
            return apiError
        }

        // Fallback: unknown backend error
        return NSError(
            domain: "API",
            code: http.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "Unknown backend error"]
        )
    }
}

dispatcher.errorParser = APIErrorParser()
```

#### When to use

* Multiple backend formats
* GraphQL / REST mixed APIs
* Versioned error schemas

You can compose multiple parsers:

```swift
dispatcher.errorParser = NISErrorParserComposer([
    GraphQLErrorParser(),
    RESTErrorParser()
])
```

---

### 🔁 Error Interceptor (normalization / side-effects)

Use `NISDispatcherErrorInterceptable` to transform or enrich errors **after parsing**.

#### Example: token refresh / logging

```swift
struct LoggingInterceptor: NISDispatcherErrorInterceptable {
    func interceptError(
        error: NISError,
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?
    ) async -> NISError {
        print("[NIS] Error: \(error)")
        return error
    }
}
```

#### Example: mapping status codes

```swift
struct StatusCodeInterceptor: NISDispatcherErrorInterceptable {
    func interceptError(
        error: NISError,
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?
    ) async -> NISError {
        guard let status = response?.statusCode else { return error }

        switch status {
        case 401:
            return .other(NISUnderlyingError(AuthError.unauthorized))
        case 403:
            return .other(NISUnderlyingError(AuthError.forbidden))
        default:
            return error
        }
    }
}
```

Compose interceptors for pipelines:

```swift
dispatcher.errorInterceptor = NISErrorInterceptorComposer([
    LoggingInterceptor(),
    StatusCodeInterceptor()
])
```

---

## 📊 Response Analyzer

`NISResponseDataAnalyzable` allows you to observe **raw response data after request execution**.

Typical use cases:

* logging
* analytics
* metrics
* extracting headers / metadata

---

### Basic example

```swift
struct LoggingAnalyzer: NISResponseDataAnalyzable {
    func analyze(responseData: NISResponseData) {
        print(responseData)
    }
}

dispatcher.responseAnalyzer = LoggingAnalyzer()
```

---

### Real-world example: store value from headers

```swift
struct LastUpdateAnalyzer: NISResponseDataAnalyzable {
    func analyze(responseData: NISResponseData) {
        guard
            let http = responseData.httpResponse,
            let lastUpdate = http.value(forHTTPHeaderField: "X-Last-Update")
        else {
            return
        }

        UserDefaults.standard.set(lastUpdate, forKey: "last_update")
    }
}
```

This is useful when backend returns:

* sync timestamps
* feature flags
* versioning info
* cache hints

---

### Combine multiple analyzers

```swift
dispatcher.responseAnalyzer = NISResponseAnalyzerComposer([
    LoggingAnalyzer(),
    LastUpdateAnalyzer()
])
```

```swift
dispatcher.responseAnalyzer = LoggingAnalyzer()
    .asComposer()
    .appending(LastUpdateAnalyzer())
```

All analyzers receive the same `NISResponseData`.

No short-circuiting — every analyzer is executed.

---

## ♻️ Deduplication & Response Reuse

Handled internally by dispatcher via `InflightRequestStore`.

### In-flight deduplication

If multiple identical requests are executed simultaneously:

→ only **one network call** is performed
→ others **subscribe to the same task**

### Recent response reuse

Controlled via:

```swift
dispatcher.responseReusePolicy = MyPolicy()
```

Where:

```swift
struct MyPolicy: NISRecentResponseReusable {
    func policy(for request: URLRequest) -> NISRecentResponseReusePolicy {
        guard let url = request.url?.absoluteString else {
            return .disabled
        }

        // Example: different policies per endpoint
        switch true {
        case url.contains("/feed"):
            // Feed can tolerate short reuse
            return .successOnly(ttl: 2)

        case url.contains("/profile"):
            // Profile slightly longer
            return .successOnly(ttl: 5)

        case url.contains("/transactions"):
            // Critical data — no reuse
            return .disabled

        default:
            return .disabled
        }
    }
}
}
```

You can also compose policies:

```swift
dispatcher.responseReusePolicy = NISRecentResponseComposer([
    FeedPolicy(),
    ImagesPolicy()
])
```

---

## ⚡ Combine Support

```swift
dispatcher
    .publisher(for: request, as: [User].self)
    .sink { response in
        print(response)
    }
```

Single-shot publisher.

Cancelling subscription cancels underlying request.

---

## 🧩 Composition

Multiple components can be combined:

```swift
let adapter = NISRequestAdapterComposer([
    AuthAdapter(),
    LoggingAdapter()
])
```

Same pattern applies to:

* adapters
* retriers
* analyzers
* error interceptors
* reuse policies

---

## 🧪 Defaults

All components have NoOp implementations.

You can start with zero configuration.

---

## 🔐 Secure Session

NIS allows you to use a **secure URLSession layer** via `NISSecureURLSession`.

This is useful when you need:

* certificate pinning
* public key pinning
* enhanced transport security

---

### Basic usage

```swift
let secureSession = NISSecureURLSession(
    configuration: .nis,
    security: .disabled // or your custom config
)

let dispatcher = NISRequestDispatcher(
    session: secureSession
)
```

---

### Example: Public Key Pinning

```swift
let secureSession = NISSecureURLSession(
    configuration: .nis,
    security: .publicKey(hashes: [
        "base64EncodedSPKIHash"
    ])
)
```

---

### Example: Certificate Pinning

```swift
let secureSession = NISSecureURLSession(
    configuration: .nis,
    security: .certificate(certificates: [
        "base64EncodedDER"
    ])
)
```

---

### Notes

* Public key pinning is generally more stable than certificate pinning
* Certificates must be in DER format (base64 encoded)
* Use secure session only when you control backend infrastructure

---

## 🧭 Design Principles

* Explicit control over behavior
* Composable building blocks
* Async-first execution model
* No hidden magic

---

## 📌 Notes

* Not a caching system
* Reuse is short-lived and controlled
* Safe by default

---

## 📄 License

MIT License — see the [LICENSE](LICENSE) file for details.
