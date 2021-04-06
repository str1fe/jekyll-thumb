require "jekyll/thumb/img_generator"

module Jekyll
  module ImgFilter
    def optimized_image_path(src, background = '0,0,0')
      site = @context.registers[:site]

      img = Thumb::ImgGenerator.new(
        site,
        src,
        { 
          "width" => 1000,
          "background" => background.split(',').map(&:to_f)
        }
      ).generate_image!

      img['src']
    end
  end
end
