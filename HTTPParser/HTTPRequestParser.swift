// HTTPRequestParser.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import http_parser

public func parseRequest(stream stream: HTTPStream, completion: HTTPParseResult<RawHTTPRequest> -> Void) {
    var parser = http_parser()
    http_parser_init(&parser, HTTP_REQUEST)

    var settings: http_parser_settings = http_parser_settings()
    http_parser_settings_init(&settings)

    settings.on_message_begin    = onRequestMessageBegin
    settings.on_url              = onRequestURL
    settings.on_header_field     = onRequestHeaderField
    settings.on_header_value     = onRequestHeaderValue
    settings.on_headers_complete = onRequestHeadersComplete
    settings.on_body             = onRequestBody
    settings.on_message_complete = onRequestMessageComplete

    let completionContext = UnsafeMutablePointer<HTTPRequestParserCompletionContext>.alloc(1)
    completionContext.initialize(HTTPRequestParserCompletionContext(completion: completion))
    parser.data = UnsafeMutablePointer<Void>(completionContext)

    do {
        try stream.readData { (var buffer) in
            let bytesParsed = http_parser_execute(&parser, &settings, &buffer, buffer.count)

            if parser.upgrade == 1 {
                let error = HTTPParseError(description: "Upgrade not supported")
                completion(HTTPParseResult.Failure(error))
            }

            if bytesParsed != buffer.count {
                let errorString = http_errno_name(http_errno(parser.http_errno))
                let error = HTTPParseError(description: String.fromCString(errorString)!)
                completion(HTTPParseResult.Failure(error))
            }
        }
    } catch {
        completion(HTTPParseResult.Failure(error))
    }
}
