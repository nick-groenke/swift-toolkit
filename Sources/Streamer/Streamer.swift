//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Opens a `Publication` using a list of parsers.
@available(*, unavailable, renamed: "PublicationOpener", message: "Use a `PublicationOpener` instead")
public final class Streamer {
    public init(
        parsers: [PublicationParser] = [],
        ignoreDefaultParsers: Bool = false,
        contentProtections: [ContentProtection] = [],
        httpClient: HTTPClient = DefaultHTTPClient(),
        onCreatePublication: Publication.Builder.Transform? = nil
    ) {}
}
