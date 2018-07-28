require "rack/contrib/try_static"
require_relative "backend/_lib/not_found"

use Rack::Deflater

use Rack::TryStatic,
    root: "_site",
    urls: %w(/),
    try: %w(.html index.html /index.html)


run NotFound
