//
//  URLSessionRequestExecutor.swift
//  Pods
//
//  Created by Admin on 10/11/2016.
//
//

import UIKit

@objc public class USRExecutor: NSObject, RequestExecutor, URLSessionDelegate {
    
    var tasks: [URLSessionDataTask] = [URLSessionDataTask]()
    var taskIdByRequestID: [String: Int] = [String: Int]()
    var taskRetryCountByRequestID: [String: Int] = [String: Int]()
    var usedRequestConfiguration: RequestConfiguration?
    
    enum ResponseError: Error {
        case emptyOrIncorrectURL
        case incorrectJSONBody
    }
    
    @objc public static let shared = USRExecutor()
    @objc public var requestConfiguration: RequestConfiguration = RequestConfiguration()
    
    func clean(request: Request) {
        
        if let index = taskIndexForRequest(request: request) {
            tasks.remove(at: index)
        }
        taskRetryCountByRequestID.removeValue(forKey: request.requestId)
        taskIdByRequestID.removeValue(forKey: request.requestId)
    }
    
    public func taskIndexForRequest(request: Request) -> Int? {
    
        if let taskId = self.taskIdByRequestID[request.requestId] {
            
            let taskIndex = self.tasks.firstIndex(where: { (taskInArray:URLSessionDataTask) -> Bool in
                
                if taskInArray.taskIdentifier == taskId {
                    return true
                } else {
                    return false
                }
            })
            
            if let index = taskIndex {
                return index
            } else {
                return nil
            }

        } else {
            return nil
        }
    }
    
    // MARK: - RequestExecutor
    
    public func send(request: Request){
        
        var urlRequest: URLRequest = URLRequest(url: request.url)
        
        // Handle http method
        if let method = request.method {
            urlRequest.httpMethod = method.value
        }
        
        // Handle body
        if let data = request.dataBody {
            urlRequest.httpBody = data
        }
        
        // Handle headers
        if let headers = request.headers {
            for (headerKey,headerValue) in headers {
                urlRequest.setValue(headerValue, forHTTPHeaderField: headerKey)
            }
        }
        
        // We will use the request's requestConfiguration if it was configured,
        // otherwise we will use the executor's requestConfiguration.
        if let requestConfiguration = request.configuration {
            usedRequestConfiguration = requestConfiguration
        } else {
            usedRequestConfiguration = requestConfiguration
        }
        
        let session: URLSession!
        
        if let configuration = usedRequestConfiguration, configuration.ignoreLocalCache {
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
            session = URLSession(configuration: sessionConfiguration)
        } else {
            session = URLSession.shared
        }
        
        let urlSessionDataTask = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // Remove the task before we create a new one in case of a retry.
            let index = self.taskIndexForRequest(request: request)
            if let i = index {
               self.tasks.remove(at: i)
            }
            
            // Perform retry in case the response code is 400 - 599.
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 && httpResponse.statusCode < 600 {
                    let retryCount = self.usedRequestConfiguration?.retryCount ?? 0
                    let taskRetryCount = self.taskRetryCountByRequestID[request.requestId] ?? 0
                    if taskRetryCount < retryCount {
                        self.taskRetryCountByRequestID[request.requestId] = taskRetryCount + 1
                        self.send(request: request)
                        return
                    }
                }
            }
        
            // Retry was not performed, clean the request and call the completion block.
            self.clean(request: request)
            DispatchQueue.main.async {
                if let completion = request.completion {
                    
                    // If we got an error because the request failed, send that error.
                    if let err = error {
                        let nsError = err as NSError
                        switch nsError.code {
                        case NSURLErrorCancelled:
                            // Canceled - no need to call the completion block
                            break
                        default:
                            let result = Response(data: nil, error: nsError)
                            completion(result)
                        }
                        return
                    }
                    
                    // If the response code is 400 - 599, send that as the error.
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode >= 400 && httpResponse.statusCode < 600 {
                            var json: Any?
                            if let d = data, !d.isEmpty {
                                json = try? JSONSerialization.jsonObject(with: d, options: JSONSerialization.ReadingOptions(rawValue:0))
                            }
                            let nsError = NSError(domain: "NetKitHttpResponseError", code: httpResponse.statusCode, userInfo: nil)
                            let result = Response(data: json, error: nsError)
                            completion(result)
                            return
                        }
                    }
                    
                    // If we got data returned from the server and it's not empty, parse and return it.
                    if let d = data, !d.isEmpty {
                        do {
                            let json = try request.responseSerializer.serialize(data: d)
                            let result = Response(data: json, error: nil)
                            completion(result)
                        } catch {
                            // The parsing error will be sent.
                            let result = Response(data: nil, error: error)
                            completion(result)
                        }
                        return
                    }
                    // Will arrive here only if there was no request error, the response status code was 100 - 399, and the data is empty.
                     else {
                        let result = Response(data: nil, error: error)
                        completion(result)
                    }
                }
            }
        }
        
        taskIdByRequestID[request.requestId] = urlSessionDataTask.taskIdentifier
        if taskRetryCountByRequestID[request.requestId] == nil {
            taskRetryCountByRequestID[request.requestId] = 0
        }
        tasks.append(urlSessionDataTask)
        urlSessionDataTask.resume()
    }
    
    public func cancel(request: Request) {
        
        if let index = taskIndexForRequest(request: request) {
            let task = tasks[index]
            task.cancel()
        }
        
        clean(request: request)
    }
    
    public func clean() {
    
    }
    
    // MARK: URLSessionDelegate
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?){
        
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void){
        
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession){
        
    }
    
}
