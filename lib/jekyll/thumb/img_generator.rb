require "ruby-vips"
require "digest/sha1"

module Jekyll
  module Thumb
    class ImgGenerator
      def initialize(site, src, attrs)
        @site = site
        @src = src
        @attrs = attrs
      end

      def generate_image!
        cache = cache_dir
        
        sha = cache && Digest::SHA1.hexdigest(@attrs.sort.inspect + File.read(File.join(@site.source, @src)) + (optimize? ? "optimize" : ""))
        if sha
          if File.exists?(File.join(cache, sha))
            img_attrs = JSON.parse(File.read(File.join(cache,sha,"json")))
            filename = img_attrs["src"].sub(/^\//, '')
            dest = File.join(@site.dest, filename)
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp(File.join(cache,sha,"img"), dest)

            @site.config['keep_files'] << filename unless @site.config['keep_files'].include?(filename)

            return img_attrs
          end
        end
        original_img_path = File.join(@site.source, @src)
        original_img = Vips::Image.new_from_file original_img_path
        
        img_attrs = {}
        
        if @attrs['width']
          scale = @attrs['width'].to_f / original_img.width
          @attrs['height'] = original_img.height * scale
        elsif @attrs['height']
          scale = @attrs['height'].to_f / original_img.height
          @attrs['width'] = original_img.width * scale
        else
          raise 'must specify either width or height'
        end

        img_attrs["height"] = @attrs["height"].to_i if @attrs["height"]
        img_attrs["width"]  = @attrs["width"].to_i  if @attrs["width"]
        img_attrs["src"] = @src.sub(/(\.\w+)$/, "-#{img_attrs["width"]}w" + '\1')
        img_attrs["src"] = img_attrs["src"].split(".").first + ".jpg"
        img_attrs["background"] = @attrs['background'] || [255,255,255]
        puts img_attrs

        filename = img_attrs["src"].sub(/^\//, '')
        filename = filename.split(".").first + ".jpg"
        dest = File.join(@site.dest, filename)
        
        FileUtils.mkdir_p(File.dirname(dest))

        unless File.exist?(dest)
          puts "Heeeloooooo"
          puts dest
          thumb = Vips::Image.thumbnail(original_img_path, img_attrs["width"], height: 10000000)
          thumb.jpegsave(dest, optimize_coding: true, strip: true, Q: 90, background: img_attrs["background"])

          if dest.match(/\.png$/) && optimize? && self.class.optipng?
            `optipng #{dest}`
          end
        end
        @site.config['keep_files'] << filename unless @site.config['keep_files'].include?(filename)
        # Keep files around for incremental builds in Jekyll 3
        @site.regenerator.add(filename) if @site.respond_to?(:regenerator)

        if sha
          FileUtils.mkdir_p(File.join(cache, sha))
          FileUtils.cp(dest, File.join(cache, sha, "img"))
          File.open(File.join(cache, sha, "json"), "w") do |f|
            f.write(JSON.generate(img_attrs))
          end
        end

        img_attrs
      end

      def config
        @site.config['thumb'] || {}
      end

      def optimize?
        config['optipng']
      end

      def cache_dir
        config['cache']
      end
    end
  end
end
