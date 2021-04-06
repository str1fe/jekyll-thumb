require "jekyll/thumb"

Liquid::Template.register_tag('thumb', Jekyll::ThumbTag)
Liquid::Template.register_filter(Jekyll::ImgFilter)
