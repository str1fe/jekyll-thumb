require "ruby-vips"
require "digest/sha1"
require "jekyll/thumb/img_generator"

module Jekyll
  class ThumbTag < Liquid::Tag
    attr_accessor :markup

    def self.optipng?
      @optinpng ||= system("which optipng")
    end

    def initialize(tag_name, markup, _)
      @markup = markup
      super
    end

    def render(context)
      options = parse_options(markup, context)

      return "Bad options to thumb_tag, syntax is: {% thumb_tag src=\"image.png\" width=\"100\"}" unless options["src"]
      return "Error resizing - can't set both width and height" if options["width"] && options["height"]

      site = context.registers[:site]
      thumb_attrs = generate_image(site, options["src"], options.merge({ "width" => options["thumbwidth"] }))
      img_attrs = generate_image(site, options["src"], options)

      gallery = options.delete 'gallery'
      img = %Q{<img #{options.merge(img_attrs).map {|k,v| "#{k}=\"#{v}\""}.join(" ")}>}
      return img if gallery == "false"
      %Q{<a href="#{img_attrs['src']}" data-ngthumb="#{thumb_attrs['src']}"></a>}
    end

    def parse_options(markup, context)
      options = {}
      markup.scan(/(\w+)=((?:"[^"]+")|(?:'[^']+')|[\w\.\_-]+)/) do |key,value|
        if (value[0..0] == "'" && value[-1..-1]) == "'" || (value[0..0] == '"' && value[-1..-1] == '"')
          options[key] = value[1..-2]
        else
          options[key] = context[value]
        end
      end
      options
    end



    def generate_image(site, src, attrs)
      Thumb::ImgGenerator.new(site, src, attrs).generate_image!
    end
  end
end
