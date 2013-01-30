require 'language_list'

module BentoSearch
  # Data object representing a single hit from a search, normalized
  # with common data fields. Usually held in a BentoSearch::Results object.
  #
  # ANY field can be nil, clients should be aware.  
  #
  # Each item has a field for one main link as string url, at #link (which may be nil),
  # as well as array of possibly additional links (with labels and metadata)
  # under #other_links.  #other_links is an array of BentoSearch::Link 
  # objects. 
  class ResultItem
    include ERB::Util # for html_escape for our presentational stuff
    include ActionView::Helpers::OutputSafetyHelper # for safe_join
    
    # Can initialize with a hash of key/values
    def initialize(args = {})
      args.each_pair do |key, value|
        send("#{key}=", value)
      end
      
      self.authors ||= []
      self.other_links ||= []
      
      self.custom_data ||= {}
    end
    
    # internal unique id for the document, from the particular
    # search service it came from. May be alphanumeric. May be nil
    # for engines that don't support it. 
    attr_accessor :unique_id 
    
    # If set to true, item will refuse to generate an openurl,
    # returning nil from #to_openurl or #openurl_kev
    attr_accessor :openurl_disabled 
    
    # Array (possibly empty) of BentoSearch::Link objects
    # representing additional links. Often SearchEngine's themselves
    # won't include any of these, but Decorators will be used
    # to add them in. 
    attr_accessor :other_links
    
    # * dc.title 
    # * schema.org CreativeWork: 'name'    
    attr_accessor :title
    # backwards compat, we used to have separate titles and subtitles
    alias_method :complete_title, :title
    
    # usually a direct link to the search provider's 'native' page. 
    # Can be changed in actual presentation with a Decorator.
    # * schema.org CreativeWork: 'url'
    attr_accessor :link
    
    # does the #link correspond to fulltext?  true or false -- or nil
    # for unknown/non-applicable. Not all engines will set. 
    def link_is_fulltext?
      @link_is_fulltext
    end
    def link_is_fulltext=(v)
      @link_is_fulltext = v
    end
    
    # Our own INTERNAL controlled vocab for 'format'. 
    #
    # Important that this be supplied by engine for maximum
    # success of openurl, ris export, etc. 
    #
    # This vocab is based on schema.org CreativeWork 'types', 
    # but supplemented with values we needed not present in schema.org. 
    # String values are last part of schema.org URLs, symbol values are custom.
    #
    # However, for backwards compat, values that didn't exist in schema.org
    # when we started but later came to exist -- we still use our string
    # values. If you actually want a schema.org url, see #schema_org_type_url
    # which translates as needed. 
    #
    # schema.org 'type' that's a sub-type of CreativeWork. 
    # should hold a string that, when appended to "http://schema.org/"
    # is a valid schema.org type uri, that sub-types CreativeWork. Ones
    # we have used:
    # * Article
    # * Book
    # * Movie
    # * MusicRecording
    # * Photograph
    # * SoftwareApplication
    # * WebPage
    # * VideoObject
    # * AudioObject
    # 
    # 
    # 
    # OR one of these symbols, sadly not covered by schema.org types:
    # * :serial (magazine or journal)
    # * :dissertation (dissertation or thesis)
    # * :conference_paper  # individual paper
    # * :conference_proceedings # collected proceedings
    # * :report # white paper or other report.
    # * :book_item # section or exceprt from book.
    #
    # Note: We're re-thinking this, might allow uncontrolled
    # in here instead. 
    attr_accessor :format

    # Translated from internal format vocab at #format. Outputs
    # eg http://schema.org/Book
    # Uses the @@format_to_schema_org hash for mapping from
    # certain internal symbol values to schema org value, where
    # possible. 
    #
    # Can return nil if we don't know a schema.org type
    def schema_org_type_url    
      if format.kind_of? String
        "http://schema.org/#{format}"
      elsif mapped = @@format_to_schema_org[format]
        "http://schema.org/#{mapped}"
      else
        nil
      end
    end
    @@format_to_schema_org = {
      :report => "Article",
    }
    
    # uncontrolled presumably english-language format string.
    # if supplied will be used in display in place of controlled
    # format. 
    attr_accessor :format_str
    
    # Language of materials. Producer can set language_code to an ISO 639-1 (two
    # letter) or 639-3 (three letter) language code. If you do this, you don't
    # need to set language_str, it'll be automatically looked up. (Providing
    # language name in English at present, i18n later maybe). 
    #
    # Or, if you don't know the language code (or there isn't one?), you can set 
    # language_str manually to a presumably english user-displayable string.
    # Manually set language_str will over-ride display string calculated from
    # language_code. 
    # 
    # Consumers that want a language code can use #language_iso_639_1 or
    # #language_iso_639_2 (either may be null), or #language_str for uncontrolled
    # string. If engine just sets one of these, internals take care of filling
    # out the others. r
    attr_accessor :language_code
    attr_writer :language_str
    def language_str
      @language_str || language_code.try do |code|
        LanguageList::LanguageInfo.find(code).try do |lang_obj|
          lang_obj.name
        end
      end
    end
    # Returns a LanguageList gem language object, from #language_code,
    # convenience
    def language_obj
      return nil unless self.language_code
      
      @language_obj ||= LanguageList::LanguageInfo.find( self.language_code )
    end
    
    # Two letter ISO language code, or nil
    def language_iso_639_1
      language_obj.try { |l| l.iso_639_1 }
    end
    
    # Three letter ISO language code, or nil
    def language_iso_639_3
      language_obj.try {|l| l.iso_639_3 }
    end
    
    # year published. a ruby int
    # PART of:. 
    # * schema.org CreativeWork "datePublished", year portion
    # * dcterms.issued, year portion
    # * prism:coverDate, year portion
    #
    # See also publication_date when you have a complete date
    attr_accessor :year
    # ruby stdlib Date object. 
    attr_accessor :publication_date
    
    attr_accessor :volume
    attr_accessor :issue
    attr_accessor :start_page
    attr_accessor :end_page
    
    # source_title is often used for journal_title (and aliased
    # as #journal_title, although that may go away), but can
    # also be used for other 'container' titles. Book title for
    # a book chapter. Even web site or URL for a web page. 
    attr_accessor :source_title
    alias_method :journal_title, :source_title
    alias_method :'journal_title=',  :'source_title='
    
    
    attr_accessor :issn
    attr_accessor :isbn
    attr_accessor :oclcnum # OCLC accession number, WorldCat. 
    
    attr_accessor :doi
    
    # usually used for books rather than articles
    attr_accessor :publisher
    
    # an openurl kev-encoded context object. optional,
    # only if source provides one that may be better
    # than can be constructed from individual elements above
    attr_accessor :openurl_kev_co
    
    # Short summary of item. 
    # Mark .html_safe if it includes html -- creator is responsible
    # for making sure html is safely sanitizied and/or stripped,
    # rails ActionView::Helpers::Sanistize #sanitize and #strip_tags
    # may be helpful. 
    attr_accessor :abstract
    
    # An array (order matters) of BentoSearch::Author objects
    # add authors to it with results.authors << Author
    attr_accessor :authors
    
    # engine-specific data not suitable for abstract API, usually
    # for internal use. 
    attr_accessor :custom_data
    
    # Copied over from engine configuration usually, a string
    # qualified name of a decorator class. Can be nil for default. 
    attr_accessor :decorator
    
    # Copied over from engine configuration :for_display key
    # by BentoSearch#search wrapper, here as a convenience t
    # parameterize logic in decorators or other presentational logic, based
    # on configuration, in places where logic has access to an item but
    # not the overall Results obj anymore. 
    #
    # TODO: Consider, should we just copy over the whole Results
    # into a backpointing reference instead? And user cover-methods
    # for it? Nice thing about the configuration has instead is it's
    # easily serializable, it's just data.  
    attr_accessor :display_configuration
    attr_accessor :engine_id
    
  end
end
