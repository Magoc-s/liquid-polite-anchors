require 'nokogiri'

module Jekyll
    module GenAnchorHeads
        # Filter takes a string argument, usage like so:
        # {{ content | generate_anchor_headings: "..." }}
        # The argument is used to express parameters if the default behaviour needs be changed, documentation:
        #
        # argument           | accepted values   | default      | description
        # -------------------------------------------------------------------
        # disable-aria        'true' | 'false'    'false'       : whether to include internal aria tags or not, default is 'false', i.e. include aria tags
        # anchor-class        string              'opticon'     : the class given to the <a> tag inserted into the <h> tag that contains the anchor symbol
        # anchor-symbol       char   | 'svg'      '#'           : the symbol used for the hyperlink, usage of scalable vector graphics is allowed, requires additional params
        # anchor-svg-attrs    string              ''            : the HTML attributes for the <svg> tag if anchor-symbol is 'svg'. Do not include less/greater than symbols.
        # anchor-svg-content  string              ''            : the inner svg node that describes the graphic drawn. Must include opening and closing html tags (i.e. <path></path>)
        # class-bl-only       string              ''            : CSV list of classes that should not allow headers to be mutated into anchor headings if an object with that class is the headers direct parent.
        # class-bl-recursive  string              ''            : CSV list of classes that should not allow headers to be mutated into anchor headings if any ancestor of the header uses that class.
        # id-bl-only          string              ''            : identical to class-bl-only except for id attributes instead of class attributes
        # id-bl-recursive     string              ''            : identical to class-bl-recursive except for id attributes instead of class attributes
        # header-level        ([1-6],)*           '1,2,3,4,5,6' : CSV list of numbers for <h[num]> tags that are allowed to be mutated into anchor links
        #
        # each argument shall be separated by semi-colons ';', with argument and values separated with colons ':'
        # i.e. generate_anchor_headings: "header-level:2,3,4,5,6;anchor-symbol:%;"
        #
        # example:
        # {{ content | generate_anchor_headings: "class-bl-only:top-banner,bottom-banner;class-bl-recursive:no-anchors,;header-level:1,2,3,4,5,6;" }}
        #
        # defaults:
        # by default the blacklists are both empty, and all header levels (1-6) are allowed to have anchor links.
        def generate_anchor_headings(input, lists)
            args = lists.split(';')
            params = {
                "disable_aria" => "false",
                "anchor_class" => "octicon",
                "anchor_symbol" => "#",
                "anchor_svg_content" => "",
                "anchor_svg_attrs" => "",
                "class_bl_only" => [],
                "class_bl_recursive" => [],
                "id_bl_only" => [],
                "id_bl_recursive" => [],
                "header_level" => '1,2,3,4,5,6'.split(',') # array of chars, not ints
            }
            for arg in args do
                filter_arg = arg.split(':')[0]
                arg_content = arg.split(':')[1].split(',')
                if filter_arg == 'anchor-symbol'
                    if arg_content.to_s.length > 1
                        if arg_content.downcase == 'svg'
                            arg_content = "<svg>"
                        else
                            raise StandardError.new "Unrecognised anchor symbol in 'generate_anchor_headings' filter."
                        end
                    end
                end
                params[filter_arg] = arg_content
            end
            # Handle creation and formatting of SVG object if filter input determines usage of an SVG rather than a char for hyperlink symbol.
            if params["anchor_symbol"] == "<svg>"
                aria_extension = params["disable_aria"] == "true" ? ">" : " aria-hidden='true'>"
                params["anchor_symbol"] = "<svg " + params["anchor_svg_attrs"] + aria_extension + params["anchor_svg_content"] + "</svg>"
            end

            # input to the filter is expected to be HTML, filter is best applied inside a layout.
            doc = Nokogiri::HTML(input)
            id_hash = Hash.new
            known_ids = doc.xpath("//*[@id]")
            for knowns in known_ids do
                id_hash[knowns['id']] = 0
            end
            for level in params['header_level'] do
                headers = doc.search('h'+level)
                for head in headers do
                    # Move onto next heading tag if the current one sits inside a blacklisted parent or ancestor class/id
                    if params["class_bl_only"].include? head.parent['class'] or params["id_bl_only"].include? head.parent['id']
                        next
                    end
                    head_ancestors = head.ancestors
                    inside_blacklist = false
                    for ha in head_ancestors do
                        if params["class_bl_recursive"].include? ha['class'] or params["id_bl_recursive"].include? ha['id'] 
                            inside_blacklist = true
                            break
                        end
                    end
                    if inside_blacklist
                        next
                    end 
                    # generate link/header slug. !! THIS REGEX IS INCOMPLETE, COULD PROBABLY BE A LOT BETTER !!
                    # I want to avoid an additional include/gem for slugifying the heading content.
                    slug = head.content.downcase.gsub(/[\s.\/_]/, ' ').strip.tr(' ', '-').gsub(/[^\w-]/, '').squeeze(' ')
                    if head['id'] != '' and head['id'] != nil
                        if doc.xpath('//a[@href="%s"]' % [head['id']]).length > 0
                            next
                        else
                            slug = head['id']
                        end
                    else
                        if slug == nil
                            slug = ''
                        end
                        if id_hash[slug] != nil then
                            id_hash[slug] = id_hash[slug].to_i + 1
                            slug = slug + '-' + (id_hash[slug]).to_s
                        else
                            id_hash[slug] = 0
                        end
                    end
                    head['id'] = slug
                    head_a_node = Nokogiri::XML::Node.new "a", doc
                    head_a_node['href'] = "#" + slug.to_s
                    if params["disable_aria"] == 'false' then head_a_node['aria-label'] = "Jump to " + head.content end
                    head_a_node['class'] = params["anchor_class"]
                    head_a_node.content = params["anchor_symbol"]
                    # If the header was a link as well, carry that link over into the new object, while maintaining the proper anchor link
                    if head['href'].to_s != ''
                        content_node = Nokogiri::XML::Node.new "a", doc
                        content_node.content = head.content
                        content_node['href'] = head['href']
                        head.content = ""
                        head.add_child(content_node)
                    else   
                        head.add_child(head_a_node)
                    end
                end
            end
            # Return complete HTML document at the end. 
            # Serializing the document may result in some issues with larger HTML? 
            # To be tested. (06/02/22: seems to work just fine, tested on a lab page for COMP2300 webpage.)
            doc.serialize
        end
    end
end

Liquid::Template.register_filter(Jekyll::GenAnchorHeads)
