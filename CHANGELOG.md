0.7.0
-----

* Maruku has been relicensed under the MIT license.

* Maruku now uses Nokogiri to parse and output HTML, fixing many bugs and
  providing a big speedup.
	
* JRuby no longer obfuscates email addresses due to a Nokogiri bug.

* Maruku produces unicode characters in the output HTML in many cases where
  before it produced XML entity references.

* Empty link references now match the way other Markdown implementations work.

* Maruku now requires Ruby 1.8.7 or newer.

* Maruku no longer extends NilType or String with its own internal-use methods.

* Backtick-style (```) and tilde-style (~~~) fenced code blocks are now supported, including the
  language option (```ruby). They must be enabled using the
  :fenced_code_blocks option.

* Parsing errors and warnings are less repetitive.

* Markdown is parsed within span-level HTML elements.

* Markdown content after HTML tags is no longer lost.

* Maruku is now tested on MRI 2.0.0, MRI 1.9.3, MRI 1.8.7, Rubinius and JRuby.

* Deeply nested lists work correctly in many more cases.

* The maruku CLI exits with a nonzero exit code when given invalid options.

0.6.1
-----

* Fix iconv warning in Ruby 1.9.
