require 'scraperwiki'
require 'mechanize'

agent = Mechanize.new

comment_url = "mailto:planning@melbourne.vic.gov.au"
base_url = "http://www.melbourne.vic.gov.au/building-and-development/property-information/planning-building-registers/Pages/town-planning-permits-register-search-results.aspx"

# Get applications from the last two weeks
start_date = (Date.today - 14).strftime("%d/%m/%Y")
end_date = Date.today.strftime("%d/%m/%Y")

page = 1
all_urls = []
begin
  url = "#{base_url}?std=#{start_date}&end=#{end_date}&page=#{page}"
  puts "Fetching #{url}"
  p = agent.get(url)
  urls = p.search('table.permits-list .detail .column1 a').map{|a| a["href"]}

  all_urls += urls
  page += 1
  # FIXME: This is just working around an infinite loop that we currently have
  raise "15 pages processed: aborting due to probably infinite loop" if page == 15
end until urls.count == 0


all_urls.each do |url|
  puts "Fetching #{url}"
  p = agent.get(url)

  record = {"info_url" => url, "comment_url" => comment_url, "date_scraped" => Date.today.to_s}

  p.at('.permit-detail').search('tr').each do |tr|
    heading = tr.at('th').inner_text
    value = tr.at('td').inner_text
    case heading
    when "Permit Number"
      record["council_reference"] = value
    when "Date Received"
      day, month, year = value.split("/")
      record["date_received"] = Date.new(year.to_i, month.to_i, day.to_i).to_s
    when "Address of Land"
      t = value.split("(").first
      if t
        record["address"] = t.strip
      else
        record["address"] = ""
      end
    when "Applicant's Name and Address", "Officer's Name", "Objections Received", "Application Status",
      "Decision", "Expiry Date", "Change to Application"
      # Do nothing with this
    when "Proposed Use or Development"
      record["description"] = value
    else
      #Need to find better way to handle exceptions
      raise "Unexpected #{heading}"
    end
  end
  ScraperWiki.save_sqlite(['council_reference'], record)
end
