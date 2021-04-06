require "ruby-vips"
require "digest/sha1"

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

      link = options.delete 'link'
      img = %Q{<img #{options.merge(thumb_attrs).map {|k,v| "#{k}=\"#{v}\""}.join(" ")}>}
      return img if link == false
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

    def config(site)
      site.config['thumb'] || {}
    end

    def optimize?(site)
      config(site)['optipng']
    end

    def cache_dir(site)
      config(site)['cache']
    end

    def generate_image(site, src, attrs)
      cache = cache_dir(site)
      
      sha = cache && Digest::SHA1.hexdigest(attrs.sort.inspect + File.read(File.join(site.source, src)) + (optimize?(site) ? "optimize" : ""))
      if sha
        if File.exists?(File.join(cache, sha))
          img_attrs = JSON.parse(File.read(File.join(cache,sha,"json")))
          filename = img_attrs["src"].sub(/^\//, '')
          dest = File.join(site.dest, filename)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(File.join(cache,sha,"img"), dest)

          site.config['keep_files'] << filename unless site.config['keep_files'].include?(filename)

          return img_attrs
        end
      end
      original_img_path = File.join(site.source, src)
      original_img = Vips::Image.new_from_file original_img_path
      
      img_attrs = {}
      
      if attrs['width']
        scale = attrs['width'].to_f / original_img.width
        attrs['height'] = original_img.height * scale
      elsif attrs['height']
        scale = attrs['height'].to_f / original_img.height
        attrs['width'] = original_img.width * scale
      else
        raise 'must specify either width or height'
      end

      img_attrs["height"] = attrs["height"].to_i if attrs["height"]
      img_attrs["width"]  = attrs["width"].to_i  if attrs["width"]
      img_attrs["src"] = src.sub(/(\.\w+)$/, "-#{img_attrs["width"]}w" + '\1')

      filename = img_attrs["src"].sub(/^\//, '')
      dest = File.join(site.dest, filename)
      
      FileUtils.mkdir_p(File.dirname(dest))

      unless File.exist?(dest)
        thumb = Vips::Image.thumbnail(original_img_path, img_attrs["width"], height: 10000000)
        thumb.jpegsave(dest, optimize_coding: true, strip: true, Q: 90)

        #if dest.match(/\.png$/) && optimize?(site) && self.class.optipng?
        #  `optipng #{dest}`
        #end
      end
      site.config['keep_files'] << filename unless site.config['keep_files'].include?(filename)
      # Keep files around for incremental builds in Jekyll 3
      site.regenerator.add(filename) if site.respond_to?(:regenerator)

      if sha
        FileUtils.mkdir_p(File.join(cache, sha))
        FileUtils.cp(dest, File.join(cache, sha, "img"))
        File.open(File.join(cache, sha, "json"), "w") do |f|
          f.write(JSON.generate(img_attrs))
        end
      end

      img_attrs
    end
  end
end
