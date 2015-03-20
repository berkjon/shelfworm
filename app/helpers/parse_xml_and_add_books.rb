helpers do

  def parse_response(user, api_response)
    total_reviews = api_response['GoodreadsResponse']['reviews']['total'].to_i
    book_array = api_response['GoodreadsResponse']['reviews']['review']
    # thread_list = [] # keep track of all threads

    book_array.each do |book|
      unless book_already_on_shelf?(user, book['book']['id'])
        if hash_or_array_to_string(book['shelves']['shelf'], 'name').match(/(?<![\w\S])read(?![\w\d])/)
          # thread_list << Thread.new { # add new thread to populate each book
            new_book = user.books.create(
              title: book['book']['title'],
              author: hash_or_array_to_string(book['book']['authors']['author'], 'name'),
              isbn10: book['book']['isbn'],
              isbn13: book['book']['isbn13'],
              publication_year: book['book']['publication_year'],
              publication_month: book['book']['publication_month'],
              num_pages: book['book']['num_pages'],
              description: book['book']['description'],
              user_rating: book['rating'],
              user_review: strip_text_if_not_nil(book['body']),
              date_added: book['date_added'],
              gr_review_id: book['id'],
              gr_book_id: book['book']['id'],
              gr_avg_rating: book['book']['average_rating'],
              gr_book_url: book['book']['link'],
              cover_img_url: find_best_cover_img_url(book['book']['image_url'], book['book']['isbn13'])
            )
            # ActiveRecord::Base.connection_pool.release_connection # needed to prevent 5 second timeout caused by threading
          # }
        end
      end
    end

    # thread_list.each {|thread| thread.join} # wait for each thread to complete

    # total_pages_required = total_reviews % 200
    # total_pages_required.times-1 do
  end

  def hash_or_array_to_string(hash_or_array, key)
    output_array = []
    if hash_or_array.is_a?(Array)
      hash_or_array.each { |element| output_array << element[key] }
    else
      output_array << hash_or_array[key]
    end
    output_string = output_array.compact.join(', ')
  end

  def strip_text_if_not_nil(xml_element)
    xml_element.nil? ? xml_element : xml_element.strip
  end

  def find_best_cover_img_url(gr_img_url, isbn13)
    covers = {}

    if isbn13.nil?
      return gr_img_url
      # return "https://s.gr-assets.com/assets/nophoto/book/111x148-bcc042a9c91a29c1d680899eff700a03.png"
    else
      gr_img_url.gsub!(/(?<=\d)(m\/)/, 'l/')
      gr_img_url_dimensions = FastImage.size(gr_img_url)
      gr_img_url_area = gr_img_url_dimensions.inject(:*) unless gr_img_url_dimensions.nil?
      covers[gr_img_url] = gr_img_url_area

      ol_img_url = "http://covers.openlibrary.org/b/isbn/#{isbn13}-L.jpg?default=false"
      ol_img_url_dimensions = FastImage.size(ol_img_url)
      ol_img_url_area = ol_img_url_dimensions.inject(:*) unless ol_img_url_dimensions.nil?
      covers[ol_img_url] = ol_img_url_area

      lt_img_url = "http://covers.librarything.com/devkey/#{ENV['LT_API_KEY']}/large/isbn/#{isbn13}"
      lt_img_url_dimensions = FastImage.size(lt_img_url)
      p "CURRENT ISBN13: #{isbn13}"
      p "LT_IMG_URL: #{lt_img_url}"
      p "LT_IMG_URL_DIMENSIONS: #{lt_img_url_dimensions}"
      lt_img_url_area = lt_img_url_dimensions.inject(:*) unless lt_img_url_dimensions.nil? || lt_img_url_dimensions.inject(:*) == 1
      covers[lt_img_url] = lt_img_url_area

      #add Google Books cover; requires API key and need to parse JSON response
      largest_img_url = covers.select {|k,v| v == covers.values.map(&:to_i).max}.keys.first
      # binding.pry
      return largest_img_url
    end
  end

  def book_already_on_shelf?(user, gr_book_id)
    user.books.where("gr_book_id='#{gr_book_id}'").length > 0
  end

end
