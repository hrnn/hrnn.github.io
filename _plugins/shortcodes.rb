
class ImageTag < Liquid::Tag
  def initialize(tag_name, args, tokens)
    super
    @src, @width, @height, @option = args.split
  end

  def render(context)
    if @option == 'fw'
      <<-MARKUP.strip
        <figure class="fullwidth"><amp-img width="#{@width}" height="#{@height}" layout="responsive" src="#{context["site"]["baseurl"]}#{@src}"></amp-img></figure>
      MARKUP
    elsif @option == 'raw'
      <<-MARKUP.strip
        <amp-img width="#{@width}" height="#{@height}" src="#{@src}"></amp-img>
      MARKUP
    else
      <<-MARKUP.strip
        <figure><amp-img width="#{@width}" height="#{@height}" layout="responsive" src="#{context["site"]["baseurl"]}#{@src}"></amp-img></figure>
      MARKUP
    end
  end
end

class YoutubeTag < Liquid::Tag
  def initialize(tag_name, args, tokens)
    super
    @youtube_id, @width, @height, @option = args.split
  end

  def render(context)
    if @option == 'fw'
      <<-MARKUP.strip
        <figure class="fullwidth"><amp-youtube data-videoid="#{@youtube_id}" layout="responsive" width="#{@width}" height="#{@height}"></amp-youtube></figure>
      MARKUP
    elsif @option == 'raw'
      <<-MARKUP.strip
        <amp-youtube data-videoid="#{@youtube_id}" layout="responsive" width="#{@width}" height="#{@height}"></amp-youtube>
      MARKUP
    else
      <<-MARKUP.strip
        <figure><amp-youtube data-videoid="#{@youtube_id}" layout="responsive" width="#{@width}" height="#{@height}"></amp-youtube></figure>
      MARKUP
    end
  end
end

class SlideTag < Liquid::Tag
  MARKER_PREFIX = "CAROUSEL_SLIDE"

  def initialize(tag_name, args, tokens)
    super
    @src, @width, @height = args.split
  end

  def render(context)
    "#{MARKER_PREFIX}|#{@src}|#{@width}|#{@height}"
  end
end

class CarouselTag < Liquid::Block
  def initialize(tag_name, args, tokens)
    super
    @identifier, *@label_parts = args.split
  end

  def render(context)
    site_baseurl = context["site"]["baseurl"].to_s
    label = @label_parts.join(" ")
    label = "Image carousel" if label.empty?
    slides = super.scan(/#{SlideTag::MARKER_PREFIX}\|([^\|]+)\|([0-9]+)\|([0-9]+)/)
    slide_markup = slides.each_with_index.map do |(src, width, height), index|
      slide_id = "#{@identifier}-slide-#{index + 1}"
      <<-MARKUP.strip
        <div class="image-carousel-slide" id="#{slide_id}"><amp-img width="#{width}" height="#{height}" layout="responsive" src="#{site_baseurl}#{src}"></amp-img></div>
      MARKUP
    end.join
    nav_markup = slides.each_with_index.map do |_slide, index|
      slide_number = index + 1
      <<-MARKUP.strip
        <a href="##{@identifier}-slide-#{slide_number}" aria-label="Show carousel photo #{slide_number}">#{slide_number}</a>
      MARKUP
    end.join

    <<-MARKUP.strip
      <figure class="image-carousel image-carousel-count-#{slides.length}" aria-label="#{label}" markdown="0"><div class="image-carousel-viewport"><div class="image-carousel-track">#{slide_markup}</div></div><div class="image-carousel-nav">#{nav_markup}</div></figure>
    MARKUP
  end
end

class SideNoteTag < Liquid::Tag
  def initialize(tag_name, args, tokens)
    super
    @tag_identifier = args.split[0]
    @sidenote = args.split.drop(1).join(" ")
  end

  def render(context)
    <<-MARKUP.strip
      <span id="#{@tag_identifier}" class="margin-toggle sidenote-number"></span>
      <span class="sidenote">#{@sidenote}</span>
    MARKUP
  end
end

class MarginNoteTag < Liquid::Block
  def initialize(tag_name, args, tokens)
    super
    @tag_identifier = args.split[0]
  end

  def render(context)
    <<-MARKUP.strip
      <span class="marginnote">#{super.strip}</span>
    MARKUP
  end
end

class BlockQuoteTag < Liquid::Block
  def initialize(tag_name, args, tokens)
    super
    @footer = args.strip
  end

  def render(context)
    <<-MARKUP.strip
      <blockquote><p>#{super.strip}</p><p class="footer">#{@footer}</p></blockquote>
    MARKUP
  end
end

Liquid::Template.register_tag('image', ImageTag)
Liquid::Template.register_tag('carousel', CarouselTag)
Liquid::Template.register_tag('slide', SlideTag)
Liquid::Template.register_tag('youtube', YoutubeTag)
Liquid::Template.register_tag('sidenote', SideNoteTag)
Liquid::Template.register_tag('marginnote', MarginNoteTag)
Liquid::Template.register_tag('blockquote', BlockQuoteTag)
