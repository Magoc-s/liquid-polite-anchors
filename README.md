# liquid-polite-anchors
A liquid filter for Jekyll that creates anchor links at headings, but only where you want them.

Add the ruby file to your `_plugins` directory, or if you have a separate plugins repo/gem, add it to that.

## polite-anchors
polite-anchors registers a new Liquid filter that runs document contents through `nokogiri` and adds links 
and id's to headings, and doesn't do it where you don't want it too.

**Requires nokogiri, this should be in your Gemfile already, but just make sure it is, cheers**
