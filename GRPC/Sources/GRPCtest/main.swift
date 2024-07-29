import GRPC
import NIO
import Logging

// サーバーコード
func runServer() {
    class GreeterProvider: Hello_GreeterProvider {
        var interceptors: Hello_GreeterServerInterceptorFactoryProtocol? {
            return nil
        }

        func sayHello(request: Hello_HelloRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Hello_HelloReply> {
            let reply = Hello_HelloReply.with {
                $0.message = "Hello \(request.name)"
            }
            return context.eventLoop.makeSucceededFuture(reply)
        }
    }

    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let provider = GreeterProvider()
    do {
        let server = try Server.insecure(group: group)
            .withServiceProviders([provider])
            .bind(host: "localhost", port: 50051)
            .wait()

        print("Server started on port \(server.channel.localAddress!.port!)")

        try server.onClose.wait()
    } catch {
        print("Server failed to start: \(error)")
    }
}

// クライアントコード
func runClient() {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
        try? group.syncShutdownGracefully()
    }

    let channel = ClientConnection.insecure(group: group)
        .connect(host: "localhost", port: 50051)
    defer {
        try? channel.close().wait()
    }

    let client = Hello_GreeterNIOClient(channel: channel)
    let request = Hello_HelloRequest.with {
        $0.name = "World"
    }

    do {
        let response = try client.sayHello(request).response.wait()
        print("Received: \(response.message)")
    } catch {
        print("Failed to receive response: \(error)")
    }
}

// メイン関数
if CommandLine.arguments.contains("--server") {
    runServer()
} else if CommandLine.arguments.contains("--client") {
    runClient()
} else {
    print("Specify --server or --client")
}
