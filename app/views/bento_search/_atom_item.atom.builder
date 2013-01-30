# single BentoSearch::ResultItem as an atom:entry.
# Assumes atom is default namespace, and uses standard prefixes
# for other namespaces, prism and dc

# HAVE to pass in local 'builder' with xml object from parent builder template,
# builder partials are weird to do well. 
#
# render :partial => "bento_search/atom_item", :collection => results, :locals => {:builder => xml } 
builder ||= xml  # or use the rails-provided 'xml' builder. 

item = atom_item # rails passes in as atom_item, name of partial. 

# TODO: Do we need to provide a way to specify a different
# decorator for the atom view than for html?
bento_decorate(item) do |item|
  builder.entry do     
    
    # An atom:entry needs an <id> with a URI uniquely identifying
    # it. Bah. we'll do what we can, this could use some fine-tuning or
    # customization hooks. We can only do anything if there's an engine_id though
    if item.engine_id.present? && item.unique_id.present?
      builder.id "#{root_url.chomp("/")}/bento_search/#{item.engine_id}/#{item.unique_id}"
    end
    
    
    builder.title item.complete_title
      
    # updated is required, for now we'll just set it to now, sorry
    builder.updated Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")


    if item.schema_org_type_url.present?
      builder.dcterms :type, item.schema_org_type_url, :vocabulary => "http://schema.org/"
    end    
    if item.format_str.present?
      builder.dcterms :type, item.format_str
    end
    if item.format.present?
      builder.dcterms :type, item.format, :vocabulary => "http://github.com/jrochkind/bento_search/"
    end

    
    # links? Let's include all, main and alternate. If 'rel' and
    # possibly 'type' attributes are present on other_links, they'll
    # be used. Main link is assumed rel 'self'
    if item.link                        
      builder.link  "rel" => "alternate", "href" => item.link
    end
    item.other_links.each do |link|
      args = {}
      args["rel"]   = (link.rel || "related") # default 'related'
      args["type"]  = link.type  if link.type.present?
      args["title"] = link.label if link.label.present?
      args["href"]  = link.url
      
      builder.link args
    end
      
    item.authors.each do |author|
      builder.author do 
        builder.name item.author_display(author)
      end
    end
    
    if item.source_title.present?
      builder.prism :publicationName, item.source_title
    end
    
    if item.issn.present?
      builder.prism :issn, item.issn
    end
    
    if item.isbn.present?
      builder.prism :isbn, item.isbn
    end
    
    # prism:doi was added to later versions of the standard,
    # and is sadly used somewhat inconsistently wrt whether
    # its' a bare doi, info uri, http://dx.doi.org, or what.
    # we use bare doi, cause it makes the most sense. 
    if item.doi.present?
      builder.prism :doi, item.doi
    end
    
    if item.publication_date.present? 
      builder.prism :coverDate, item.publication_date.strftime("%Y-%m-%d")
    elsif item.year.present?
      builder.prism :coverDate, item.year
    end
    
    if item.volume.present?
      builder.prism :volume, item.volume
    end
    
    if item.issue.present?
      builder.prism :number, item.issue
    end
    
    if item.start_page.present?
      builder.prism :startingPage, item.start_page
    end
    if item.end_page.present?
      builder.prism :endingPage, item.end_page
    end
      
    if item.abstract.present? 
      builder.summary item.abstract, "type" => (item.abstract.html_safe? ? "html" : "text")        
    end      

 
    if item.language_iso_639_1.present?
      builder.dcterms :language, item.language_iso_639_1, "vocabulary" => "http://dbpedia.org/resource/ISO_639-1"
    end
    if item.language_iso_639_3.present?
      builder.dcterms :language, item.language_iso_639_3, "vocabulary" => "http://dbpedia.org/resource/ISO_639-3"
    end
    if item.language_str.present?
      builder.dcterms :language, item.language_str
    end    
  end
end
