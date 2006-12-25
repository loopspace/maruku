
# There are two black-magic methods `match_couple_of` and `map_match`,
# defined at the end of the file, that make the function 
# `parse_lines_as_span` so elegant.

class Maruku

	# Takes care of all span-level formatting, links, images, etc.
	#
	# Lines must not contain block-level elements.
	def parse_lines_as_span(lines)
		
		# first, get rid of linebreaks
		res = resolve_linebreaks(lines)

		span = MDElement.new
		span.children = res

		# encode all escapes
		span.replace_each_string { |s| s.escape_md_special }


# The order of processing is significant: 
# 1. inline code
# 2. immediate links
# 3. inline HTML 
# 4. everything else

		# search for ``code`` markers
		span.match_couple_of('``') { |children, match1, match2| 
			e = create_md_element(:inline_code)
			e.meta[:raw_code] = children.join('') # this is now opaque to processing
			e
		}

		# Search for `single tick`  code markers
		span.match_couple_of('`') { |children, match1, match2|
			e = create_md_element(:inline_code)
			e.meta[:raw_code] = children.join('').unescape_md_special 
			# this is now opaque to processing
			e
		}
		
		# Detect any immediate link: <http://www.google.com>
		# we expect an http: or something: at the beginning
		span.map_match( /<(\w+:[^\>]+)>/) { |match| 
			url = match[1]
			
			e = create_md_element(:immediate_link, [])
			e.meta[:url] = url
			e
		}
		
		# Search for inline HTML (the support is pretty basic for now)
		
		# this searches for a matching block
		inlineHTML1 = %r{
			(   # put everything in 1 
			<   # open
			(\w+) # opening tag in 2
			>   # close
			.*  # anything
			</\2> # match closing tag
			)
		}x

		# this searches for only one block
		inlineHTML2 = %r{
			(   # put everything in 1 
			<   # open
			\w+ # 
			    # close
			[^<>]*  # anything except
			/> # closing tag
			)
		}x
		
		for reg in [inlineHTML1, inlineHTML2]
			span.map_match(reg) { |match| 
				raw_html = (match[1] || raise("No html?"))
				e = create_md_element(:raw_html)
				e.meta[:raw_html]  = raw_html
				begin
					e.meta[:parsed_html] = Document.new(raw_html)
				rescue 
					$stderr.puts "Malformed HTML:\n#{raw_html}"
				end
				e
			}
		end
		
		# Detect footnotes references: [^1]
		span.map_match(/\[(\^[^\]]+)\]/) { |match| 
			id = match[1].strip.downcase
			e = create_md_element(:footnote_reference)
			e.meta[:footnote_id] = id
			e
		}

		# Detect any image like ![Alt text][url]
		span.map_match(/\!\[([^\]]+)\]\s?\[([^\]]*)\]/) { |match|
			alt = match[1]
			id = match[2].strip.downcase
			
			if id.size == 0
				id = text.strip.downcase
			end
			
			e = create_md_element(:image)
			e.meta[:ref_id] = id
			e
		}

		# Detect any immage with immediate url: ![Alt](url "title")
		# a dummy ref is created and put in the symbol table
		link1 = /!\[([^\]]+)\]\s?\(([^\s\)]*)(?:\s+["'](.*)["'])?\)/
		span.map_match(link1) { |match|
			alt = match[1]
			url = match[2]
			title = match[3]
			
			url = url.strip
			# create a dummy id
			id="dummy_#{@refs.size}"
			@refs[id] = {:url=>url, :title=>title}
			
			e = create_md_element(:image)
			e.meta[:ref_id] = id
			e
		}

		# an id reference: "[id]",  "[ id  ]"
		reg_id_ref = %r{
			\[ # opening bracket 
			([^\]]*) # 0 or more non-closing bracket (this is too permissive)
			\] # closing bracket
			}x
			
		# Detect any link like [Google engine][google]
		span.match_couple_of('[',  # opening bracket
			%r{\]                   # closing bracket
			[ ]?                    # optional whitespace
			#{reg_id_ref} # ref id, with $1 being the reference 
			}x
				) { |children, match1, match2| 
					
#			puts "children = #{children.inspect}"

			id = match2[1]
			id = id.strip.downcase
			
			if id.size == 0
				id = children.join.strip.downcase
			end
			
			e = create_md_element(:link, children)
			e.meta[:ref_id] = id
			e
		}
		
		# validates a url, only $1 is set to the url
 		reg_url = 
			/((?:\w+):\/\/(?:\w+:{0,1}\w*@)?(?:\S+)(?::[0-9]+)?(?:\/|\/([\w#!:.?+=&%@!\-\/]))?)/
		
		# A string enclosed in quotes.
		reg_title = %r{
			" # opening
			[^"]*   # anything = 1
			" # closing
			}x
		
		# (http://www.google.com "Google.com"), (http://www.google.com),
		reg_url_and_title = %r{
			\(  # opening
			\s* # whitespace 
			#{reg_url}  # url = 1 
			(?:\s+["'](.*)["'])? # optional title  = 2
			\s* # whitespace 
			\) # closing
		}x

		# Detect any link with immediate url: [Google](http://www.google.com)
		# a dummy ref is created and put in the symbol table

		span.match_couple_of('[',  # opening bracket
				%r{\]                   # closing bracket
				[ ]?                    # optional whitespace
				#{reg_url_and_title}    # ref id, with $1 being the url and $2 being the title
				}x
					) { |children, match1, match2| 
		
			puts "match2 = #{match2.to_s}"
			puts "         #{match2.inspect}"
			
			url   = match2[1]
			title = match2[3] # XXX? 
			# create a dummy id
			id="dummy_#{@refs.size}"
			@refs[id] = {:url=>url}
			@refs[id][:title] = title if title
			

			puts "url = #{url}"
			puts "title = #{title}"

			e = create_md_element(:link, children)
			e.meta[:ref_id] = id
			e
		}

		# Detect an email address <andrea@invalid.it>
		span.map_match( /<([^:]+@[^:]+)>/) { |match| 
			email = match[1]
			e = create_md_element(:email_address, [])
			e.meta[:email] = email
			e
		}


		# And now the easy stuff
	
		# search for **strong**
		span.match_couple_of('**') { |children,m1,m2|  create_md_element(:strong,   children) }

		# search for __strong__
		span.match_couple_of('__') { |children,m1,m2|  create_md_element(:strong,   children) }

		# search for *emphasis*
		span.match_couple_of('*')  { |children,m1,m2|  create_md_element(:emphasis, children) }
		
		# search for _emphasis_
		span.match_couple_of('_')  { |children,m1,m2|  create_md_element(:emphasis, children) }
		
		# finally, unescape the special characters
		span.replace_each_string { |s|  s.unescape_md_special}
		
		span.children
	end
	
	# returns array containing Strings or :linebreak elements
	def resolve_linebreaks(lines)
		res = []
		s = ""
		lines.each do |l| 
			s += (s.size>0 ? " " : "") + l.strip
			if force_linebreak?(l)
				res << s
				res << create_md_element(:linebreak)
				s = ""
			end
		end
		res << s if s.size > 0
		res
	end

end

# And now the black magic that makes the part above so elegant

class MDElement
	
	# yields to each element of specified node_type
	def each_element(e_node_type, &block) 
		@children.each do |c| 
			if c.kind_of? MDElement
				if (not e_node_type) || (e_node_type == c.node_type)
					block.call c
				end
				c.each_element(e_node_type, &block)
			end
		end
	end
	
	# Apply passed block to each String in the hierarchy.
	def replace_each_string(&block)
		for c in @children
			if c.kind_of? MDElement
				c.replace_each_string(&block)
			end
		end
		
		processed = []
		until @children.empty?
			c = @children.shift
			if c.kind_of? String
				result = block.call(c)
				[*result].each do |e| processed << e end
			else
				processed << c
			end
		end
		@children = processed
	end
	
	# Try to match the regexp to each string in the hierarchy
	# (using `replace_each_string`). If the regexp match, eliminate
	# the matching string and substitute it with the pre_match, the
	# result of the block, and the post_match
	#
	#   ..., matched_string, ... -> ..., pre_match, block.call(match), post_match
	#
	# the block might return arrays.
	#
	def map_match(regexp, &block)
		replace_each_string { |s| 
			processed = []
			while (match = regexp.match(s))
				# save the pre_match
				processed << match.pre_match if match.pre_match && match.pre_match.size>0
				# transform match
				result = block.call(match)
				# and append as processed
				[*result].each do |e| processed << e end
				# go on with the rest of the string
				s = match.post_match 
			end
			processed << s if s.size > 0
			processed
		}
	end
	
	# Finds couple of delimiters in a hierarchy of Strings and MDElements
	#
	# Open and close are two delimiters (like '[' and ']'), or two Regexp.
	#
	# If you don't pass close, it defaults to open.
	#
	# Each block is called with |contained children, match1, match2|
	def match_couple_of(open, close=nil, &block)
		close = close || open
		 open_regexp =  open.kind_of?(Regexp) ?  open : Regexp.new(Regexp.escape(open))
		close_regexp = close.kind_of?(Regexp) ? close : Regexp.new(Regexp.escape(close))
		
		# Do the same to children first
		for c in @children; if c.kind_of? MDElement
			c.match_couple_of(open_regexp, close_regexp, &block)
		end end
		
		processed_children = []
		
		until @children.empty?
			c = @children.shift
			if c.kind_of? String
				match1 = open_regexp.match(c)
				if not match1
					processed_children << c
				else # we found opening, now search closing
#					puts "Found opening (#{marker}) in #{c.inspect}"
					# pre match is processed
					processed_children.push match1.pre_match if 
						match1.pre_match && match1.pre_match.size > 0
					# we will process again the post_match
					@children.unshift match1.post_match if 
						match1.post_match && match1.post_match.size>0
					
					contained = []; found_closing = false
					until @children.empty?  || found_closing
						c = @children.shift
						if c.kind_of? String
							match2 = close_regexp.match(c)
							if not match2 
								contained << c
							else
								# we found closing
								found_closing = true
								# pre match is contained
								contained.push match2.pre_match if 
									match2.pre_match && match2.pre_match.size>0
								# we will process again the post_match
								@children.unshift match2.post_match if 
									match2.post_match && match2.post_match.size>0

								# And now we call the block
								substitute = block.call(contained, match1, match2) 
								processed_children  << substitute
								
#								puts "Found closing (#{marker}) in #{c.inspect}"
#								puts "Children: #{contained.inspect}"
#								puts "Substitute: #{substitute.inspect}"
							end
						else
							contained << c
						end
					end
					
					if not found_closing
						# $stderr.puts "##### Could not find closing for #{open}, #{close} -- ignoring"
						processed_children << match1.to_s
						contained.reverse.each do |c|
							@children.unshift c
						end
					end
				end
			else
				processed_children << c
			end
		end
		
		raise "BugBug" unless @children.empty?
		
		rebuilt = []
		# rebuild strings
		processed_children.each do |c|
			if c.kind_of?(String) && rebuilt.last && rebuilt.last.kind_of?(String)
				rebuilt.last << c
			else
				rebuilt << c
			end
		end
		@children = rebuilt
	end
end