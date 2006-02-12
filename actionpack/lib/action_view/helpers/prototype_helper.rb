require File.dirname(__FILE__) + '/javascript_helper'
require 'set'

module ActionView
  module Helpers
    # Provides a set of helpers for calling Prototype JavaScript functions, 
    # including functionality to call remote methods using 
    # Ajax[http://www.adaptivepath.com/publications/essays/archives/000385.php]. 
    # This means that you can call actions in your controllers without 
    # reloading the page, but still update certain parts of it using 
    # injections into the DOM. The common use case is having a form that adds
    # a new element to a list without reloading the page.
    #
    # To be able to use these helpers, you must include the Prototype 
    # JavaScript framework in your pages. See the documentation for 
    # ActionView::Helpers::JavaScriptHelper for more information on including 
    # the necessary JavaScript.
    #
    # See link_to_remote for documentation of options common to all Ajax
    # helpers.
    #
    # See also ActionView::Helpers::ScriptaculousHelper for helpers which work
    # with the Scriptaculous controls and visual effects library.
    #
    # See JavaScriptGenerator for information on updating multiple elements
    # on the page in an Ajax response. 
    module PrototypeHelper
      unless const_defined? :CALLBACKS
        CALLBACKS    = Set.new([ :uninitialized, :loading, :loaded,
                         :interactive, :complete, :failure, :success ] +
                         (100..599).to_a)
        AJAX_OPTIONS = Set.new([ :before, :after, :condition, :url,
                         :asynchronous, :method, :insertion, :position,
                         :form, :with, :update, :script ]).merge(CALLBACKS)
      end

      # Returns a link to a remote action defined by <tt>options[:url]</tt> 
      # (using the url_for format) that's called in the background using 
      # XMLHttpRequest. The result of that request can then be inserted into a
      # DOM object whose id can be specified with <tt>options[:update]</tt>. 
      # Usually, the result would be a partial prepared by the controller with
      # either render_partial or render_partial_collection. 
      #
      # Examples:
      #   link_to_remote "Delete this post", :update => "posts", 
      #     :url => { :action => "destroy", :id => post.id }
      #   link_to_remote(image_tag("refresh"), :update => "emails", 
      #     :url => { :action => "list_emails" })
      #
      # You can also specify a hash for <tt>options[:update]</tt> to allow for
      # easy redirection of output to an other DOM element if a server-side 
      # error occurs:
      #
      # Example:
      #   link_to_remote "Delete this post",
      #     :url => { :action => "destroy", :id => post.id },
      #     :update => { :success => "posts", :failure => "error" }
      #
      # Optionally, you can use the <tt>options[:position]</tt> parameter to 
      # influence how the target DOM element is updated. It must be one of 
      # <tt>:before</tt>, <tt>:top</tt>, <tt>:bottom</tt>, or <tt>:after</tt>.
      #
      # By default, these remote requests are processed asynchronous during 
      # which various JavaScript callbacks can be triggered (for progress 
      # indicators and the likes). All callbacks get access to the 
      # <tt>request</tt> object, which holds the underlying XMLHttpRequest. 
      #
      # To access the server response, use <tt>request.responseText</tt>, to
      # find out the HTTP status, use <tt>request.status</tt>.
      #
      # Example:
      #   link_to_remote word,
      #     :url => { :action => "undo", :n => word_counter },
      #     :complete => "undoRequestCompleted(request)"
      #
      # The callbacks that may be specified are (in order):
      #
      # <tt>:loading</tt>::       Called when the remote document is being 
      #                           loaded with data by the browser.
      # <tt>:loaded</tt>::        Called when the browser has finished loading
      #                           the remote document.
      # <tt>:interactive</tt>::   Called when the user can interact with the 
      #                           remote document, even though it has not 
      #                           finished loading.
      # <tt>:success</tt>::       Called when the XMLHttpRequest is completed,
      #                           and the HTTP status code is in the 2XX range.
      # <tt>:failure</tt>::       Called when the XMLHttpRequest is completed,
      #                           and the HTTP status code is not in the 2XX
      #                           range.
      # <tt>:complete</tt>::      Called when the XMLHttpRequest is complete 
      #                           (fires after success/failure if they are 
      #                           present).
      #                     
      # You can further refine <tt>:success</tt> and <tt>:failure</tt> by 
      # adding additional callbacks for specific status codes.
      #
      # Example:
      #   link_to_remote word,
      #     :url => { :action => "action" },
      #     404 => "alert('Not found...? Wrong URL...?')",
      #     :failure => "alert('HTTP Error ' + request.status + '!')"
      #
      # A status code callback overrides the success/failure handlers if 
      # present.
      #
      # If you for some reason or another need synchronous processing (that'll
      # block the browser while the request is happening), you can specify 
      # <tt>options[:type] = :synchronous</tt>.
      #
      # You can customize further browser side call logic by passing in
      # JavaScript code snippets via some optional parameters. In their order 
      # of use these are:
      #
      # <tt>:confirm</tt>::      Adds confirmation dialog.
      # <tt>:condition</tt>::    Perform remote request conditionally
      #                          by this expression. Use this to
      #                          describe browser-side conditions when
      #                          request should not be initiated.
      # <tt>:before</tt>::       Called before request is initiated.
      # <tt>:after</tt>::        Called immediately after request was
      #                          initiated and before <tt>:loading</tt>.
      # <tt>:submit</tt>::       Specifies the DOM element ID that's used
      #                          as the parent of the form elements. By 
      #                          default this is the current form, but
      #                          it could just as well be the ID of a
      #                          table row or any other DOM element.
      def link_to_remote(name, options = {}, html_options = {})  
        link_to_function(name, remote_function(options), html_options)
      end

      # Periodically calls the specified url (<tt>options[:url]</tt>) every 
      # <tt>options[:frequency]</tt> seconds (default is 10). Usually used to
      # update a specified div (<tt>options[:update]</tt>) with the results 
      # of the remote call. The options for specifying the target with :url 
      # and defining callbacks is the same as link_to_remote.
      def periodically_call_remote(options = {})
         frequency = options[:frequency] || 10 # every ten seconds by default
         code = "new PeriodicalExecuter(function() {#{remote_function(options)}}, #{frequency})"
         javascript_tag(code)
      end

      # Returns a form tag that will submit using XMLHttpRequest in the 
      # background instead of the regular reloading POST arrangement. Even 
      # though it's using JavaScript to serialize the form elements, the form
      # submission will work just like a regular submission as viewed by the
      # receiving side (all elements available in @params). The options for 
      # specifying the target with :url and defining callbacks is the same as
      # link_to_remote.
      #
      # A "fall-through" target for browsers that doesn't do JavaScript can be
      # specified with the :action/:method options on :html.
      #
      # Example:
      #   form_remote_tag :html => { :action => 
      #     url_for(:controller => "some", :action => "place") }
      #
      # The Hash passed to the :html key is equivalent to the options (2nd) 
      # argument in the FormTagHelper.form_tag method.
      #
      # By default the fall-through action is the same as the one specified in 
      # the :url (and the default method is :post).
      def form_remote_tag(options = {})
        options[:form] = true

        options[:html] ||= {}
        options[:html][:onsubmit] = "#{remote_function(options)}; return false;"
        options[:html][:action] = options[:html][:action] || url_for(options[:url])
        options[:html][:method] = options[:html][:method] || "post"

        tag("form", options[:html], true)
      end

      # Works like form_remote_tag, but uses form_for semantics.
      def remote_form_for(object_name, object, options = {}, &proc)
        concat(form_remote_tag(options), proc.binding)
        fields_for(object_name, object, options, &proc)
        concat('</form>', proc.binding)
      end
      alias_method :form_remote_for, :remote_form_for
      
      # Returns a button input tag that will submit form using XMLHttpRequest 
      # in the background instead of regular reloading POST arrangement. 
      # <tt>options</tt> argument is the same as in <tt>form_remote_tag</tt>.
      def submit_to_remote(name, value, options = {})
        options[:with] ||= 'Form.serialize(this.form)'

        options[:html] ||= {}
        options[:html][:type] = 'button'
        options[:html][:onclick] = "#{remote_function(options)}; return false;"
        options[:html][:name] = name
        options[:html][:value] = value

        tag("input", options[:html], false)
      end
      
      # Returns a JavaScript function (or expression) that'll update a DOM 
      # element according to the options passed.
      #
      # * <tt>:content</tt>: The content to use for updating. Can be left out
      #   if using block, see example.
      # * <tt>:action</tt>: Valid options are :update (assumed by default), 
      #   :empty, :remove
      # * <tt>:position</tt> If the :action is :update, you can optionally 
      #   specify one of the following positions: :before, :top, :bottom, 
      #   :after.
      #
      # Examples:
      #   <%= javascript_tag(update_element_function("products", 
      #     :position => :bottom, :content => "<p>New product!</p>")) %>
      #
      #   <% replacement_function = update_element_function("products") do %>
      #     <p>Product 1</p>
      #     <p>Product 2</p>
      #   <% end %>
      #   <%= javascript_tag(replacement_function) %>
      #
      # This method can also be used in combination with remote method call 
      # where the result is evaluated afterwards to cause multiple updates on
      # a page. Example:
      #
      #   # Calling view
      #   <%= form_remote_tag :url => { :action => "buy" }, 
      #     :complete => evaluate_remote_response %>
      #   all the inputs here...
      #
      #   # Controller action
      #   def buy
      #     @product = Product.find(1)
      #   end
      #
      #   # Returning view
      #   <%= update_element_function(
      #         "cart", :action => :update, :position => :bottom, 
      #         :content => "<p>New Product: #{@product.name}</p>")) %>
      #   <% update_element_function("status", :binding => binding) do %>
      #     You've bought a new product!
      #   <% end %>
      #
      # Notice how the second call doesn't need to be in an ERb output block
      # since it uses a block and passes in the binding to render directly. 
      # This trick will however only work in ERb (not Builder or other 
      # template forms).
      #
      # See also JavaScriptGenerator and update_page.
      def update_element_function(element_id, options = {}, &block)
        content = escape_javascript(options[:content] || '')
        content = escape_javascript(capture(&block)) if block
        
        javascript_function = case (options[:action] || :update)
          when :update
            if options[:position]
              "new Insertion.#{options[:position].to_s.camelize}('#{element_id}','#{content}')"
            else
              "$('#{element_id}').innerHTML = '#{content}'"
            end
          
          when :empty
            "$('#{element_id}').innerHTML = ''"
          
          when :remove
            "Element.remove('#{element_id}')"
          
          else
            raise ArgumentError, "Invalid action, choose one of :update, :remove, :empty"
        end
        
        javascript_function << ";\n"
        options[:binding] ? concat(javascript_function, options[:binding]) : javascript_function
      end
      
      # Returns 'eval(request.responseText)' which is the JavaScript function
      # that form_remote_tag can call in :complete to evaluate a multiple
      # update return document using update_element_function calls.
      def evaluate_remote_response
        "eval(request.responseText)"
      end

      # Returns the JavaScript needed for a remote function.
      # Takes the same arguments as link_to_remote.
      # 
      # Example:
      #   <select id="options" onchange="<%= remote_function(:update => "options", 
      #       :url => { :action => :update_options }) %>">
      #     <option value="0">Hello</option>
      #     <option value="1">World</option>
      #   </select>
      def remote_function(options)
        javascript_options = options_for_ajax(options)

        update = ''
        if options[:update] and options[:update].is_a?Hash
          update  = []
          update << "success:'#{options[:update][:success]}'" if options[:update][:success]
          update << "failure:'#{options[:update][:failure]}'" if options[:update][:failure]
          update  = '{' + update.join(',') + '}'
        elsif options[:update]
          update << "'#{options[:update]}'"
        end

        function = update.empty? ? 
          "new Ajax.Request(" :
          "new Ajax.Updater(#{update}, "

        function << "'#{url_for(options[:url])}'"
        function << ", #{javascript_options})"

        function = "#{options[:before]}; #{function}" if options[:before]
        function = "#{function}; #{options[:after]}"  if options[:after]
        function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
        function = "if (confirm('#{escape_javascript(options[:confirm])}')) { #{function}; }" if options[:confirm]

        return function
      end

      # Observes the field with the DOM ID specified by +field_id+ and makes
      # an Ajax call when its contents have changed.
      # 
      # Required +options+ are:
      # <tt>:url</tt>::       +url_for+-style options for the action to call
      #                       when the field has changed.
      # 
      # Additional options are:
      # <tt>:frequency</tt>:: The frequency (in seconds) at which changes to
      #                       this field will be detected. Not setting this
      #                       option at all or to a value equal to or less than
      #                       zero will use event based observation instead of
      #                       time based observation.
      # <tt>:update</tt>::    Specifies the DOM ID of the element whose 
      #                       innerHTML should be updated with the
      #                       XMLHttpRequest response text.
      # <tt>:with</tt>::      A JavaScript expression specifying the
      #                       parameters for the XMLHttpRequest. This defaults
      #                       to 'value', which in the evaluated context 
      #                       refers to the new field value.
      # <tt>:on</tt>::        Specifies which event handler to observe. By default,
      #                       it's set to "changed" for text fields and areas and
      #                       "click" for radio buttons and checkboxes. With this,
      #                       you can specify it instead to be "blur" or "focus" or
      #                       any other event.
      #
      # Additionally, you may specify any of the options documented in
      # link_to_remote.
      def observe_field(field_id, options = {})
        if options[:frequency] && options[:frequency] > 0
          build_observer('Form.Element.Observer', field_id, options)
        else
          build_observer('Form.Element.EventObserver', field_id, options)
        end
      end
      
      # Like +observe_field+, but operates on an entire form identified by the
      # DOM ID +form_id+. +options+ are the same as +observe_field+, except 
      # the default value of the <tt>:with</tt> option evaluates to the
      # serialized (request string) value of the form.
      def observe_form(form_id, options = {})
        if options[:frequency]
          build_observer('Form.Observer', form_id, options)
        else
          build_observer('Form.EventObserver', form_id, options)
        end
      end
      
      # JavaScriptGenerator generates blocks of JavaScript code that allow you 
      # to change the content and presentation of multiple DOM elements.  Use 
      # this in your Ajax response bodies, either in a <script> tag or as plain
      # JavaScript sent with a Content-type of "text/javascript".
      #
      # Create new instances with PrototypeHelper#update_page or with 
      # ActionController::Base#render, then call #insert_html, #replace_html, 
      # #remove, #show, #hide, #visual_effect, or any other of the built-in 
      # methods on the yielded generator in any order you like to modify the 
      # content and appearance of the current page. 
      #
      # Example:
      #
      #   update_page do |page|
      #     page.insert_html :bottom, 'list', "<li>#{@item.name}</li>"
      #     page.visual_effect :highlight, 'list'
      #     page.hide 'status-indicator', 'cancel-link'
      #   end
      # 
      # generates the following JavaScript:
      #
      #   new Insertion.Bottom("list", "<li>Some item</li>");
      #   new Effect.Highlight("list");
      #   ["status-indicator", "cancel-link"].each(Element.hide);
      #
      # Helper methods can be used in conjunction with JavaScriptGenerator.
      # When a helper method is called inside an update block on the +page+ 
      # object, that method will also have access to a +page+ object.
      # 
      # Example:
      #
      #   module ApplicationHelper
      #     def update_time
      #       page.replace_html 'time', Time.now.to_s(:db)
      #       page.visual_effect :highlight, 'time'
      #     end
      #   end
      #
      #   # Controller action
      #   def poll
      #     render :update { |page| page.update_time }
      #   end
      #
      # You can also use PrototypeHelper#update_page_tag instead of 
      # PrototypeHelper#update_page to wrap the generated JavaScript in a
      # <script> tag.
      class JavaScriptGenerator
        def initialize(context, &block) #:nodoc:
          @context, @lines = context, []
          include_helpers_from_context
          @context.instance_exec(self, &block)
        end
  
        def to_s #:nodoc:
          @lines * $/
        end

        # Returns a element reference by finding it through +id+ in the DOM. This element can then be
        # used for further method calls. Examples:
        #
        #   page['blank_slate']                  # => $('blank_slate');
        #   page['blank_slate'].show             # => $('blank_slate').show();
        #   page['blank_slate'].show('first').up # => $('blank_slate').show('first').up();
        def [](id)
          JavaScriptElementProxy.new(self, "$('#{id}')")
        end

        # Returns a collection reference by finding it through a CSS +pattern+ in the DOM. This collection can then be
        # used for further method calls. Examples:
        #
        #   page.select('p')                      # => $$('p');
        #   page.select('p.welcome b').first      # => $$('p.welcome b').first();
        #   page.select('p.welcome b').first.hide # => $$('p.welcome b').first().hide();
        def select(pattern)
          JavaScriptElementProxy.new(self, "$$('#{pattern}')")
        end
  
        # Inserts HTML at the specified +position+ relative to the DOM element
        # identified by the given +id+.
        # 
        # +position+ may be one of:
        # 
        # <tt>:top</tt>::    HTML is inserted inside the element, before the 
        #                    element's existing content.
        # <tt>:bottom</tt>:: HTML is inserted inside the element, after the
        #                    element's existing content.
        # <tt>:before</tt>:: HTML is inserted immediately preceeding the element.
        # <tt>:after</tt>::  HTML is inserted immediately following the element.
        #
        # +options_for_render+ may be either a string of HTML to insert, or a hash
        # of options to be passed to ActionView::Base#render.  For example:
        #
        #   # Insert the rendered 'navigation' partial just before the DOM
        #   # element with ID 'content'.
        #   insert_html :before, 'content', :partial => 'navigation'
        #
        #   # Add a list item to the bottom of the <ul> with ID 'list'.
        #   insert_html :bottom, 'list', '<li>Last item</li>'
        #
        def insert_html(position, id, *options_for_render)
          insertion = position.to_s.camelize
          call "new Insertion.#{insertion}", id, render(*options_for_render)
        end
  
        # Replaces the inner HTML of the DOM element with the given +id+.
        #
        # +options_for_render+ may be either a string of HTML to insert, or a hash
        # of options to be passed to ActionView::Base#render.  For example:
        #
        #   # Replace the HTML of the DOM element having ID 'person-45' with the
        #   # 'person' partial for the appropriate object.
        #   replace_html 'person-45', :partial => 'person', :object => @person
        #
        def replace_html(id, *options_for_render)
          call 'Element.update', id, render(*options_for_render)
        end
  
        # Replaces the "outer HTML" (i.e., the entire element, not just its
        # contents) of the DOM element with the given +id+.
        #
        # +options_for_render+ may be either a string of HTML to insert, or a hash
        # of options to be passed to ActionView::Base#render.  For example:
        #
        #   # Replace the DOM element having ID 'person-45' with the
        #   # 'person' partial for the appropriate object.
        #   replace_html 'person-45', :partial => 'person', :object => @person
        #
        # This allows the same partial that is used for the +insert_html+ to
        # be also used for the input to +replace+ without resorting to
        # the use of wrapper elements.
        #
        # Examples:
        #
        #   <div id="people">
        #     <%= render :partial => 'person', :collection => @people %>
        #   </div>
        #
        #   # Insert a new person
        #   page.insert_html :bottom, :partial => 'person', :object => @person
        #
        #   # Replace an existing person
        #   page.replace 'person_45', :partial => 'person', :object => @person
        #
        def replace(id, *options_for_render)
          call 'Element.replace', id, render(*options_for_render)
        end
        
        # Removes the DOM elements with the given +ids+ from the page.
        def remove(*ids)
          record "#{javascript_object_for(ids)}.each(Element.remove)"
        end
  
        # Shows hidden DOM elements with the given +ids+.
        def show(*ids)
          call 'Element.show', *ids
        end
  
        # Hides the visible DOM elements with the given +ids+.
        def hide(*ids)
          call 'Element.hide', *ids
        end
        
        # Toggles the visibility of the DOM elements with the given +ids+.
        def toggle(*ids)
          call 'Element.toggle', *ids
        end
        
        # Displays an alert dialog with the given +message+.
        def alert(message)
          call 'alert', message
        end
        
        # Redirects the browser to the given +location+, in the same form as
        # +url_for+.
        def redirect_to(location)
          assign 'window.location.href', @context.url_for(location)
        end
        
        # Calls the JavaScript +function+, optionally with the given 
        # +arguments+.
        def call(function, *arguments)
          record "#{function}(#{arguments_for_call(arguments)})"
        end
        
        # Assigns the JavaScript +variable+ the given +value+.
        def assign(variable, value)
          record "#{variable} = #{javascript_object_for(value)}"
        end
        
        # Writes raw JavaScript to the page.
        def <<(javascript)
          @lines << javascript
        end

        # Executes the content of the block after a delay of +seconds+. Example:
        #
        #   page.delay(20) do
        #     page.visual_effect :fade, 'notice'
        #   end
        def delay(seconds = 1)
          record "setTimeout(function() {\n\n"
          yield
          record "}, #{(seconds * 1000).to_i})"
        end
        
        # Starts a Scriptaculous visual effect. See 
        # ActionView::Helpers::ScriptaculousHelper for more information.
        def visual_effect(name, id, options = {})
          record @context.send(:visual_effect, name, id, options)
        end
        
      private
        def include_helpers_from_context
          @context.extended_by.each do |mod|
            extend mod unless mod.name =~ /^ActionView::Helpers/
          end
        end
        
        def page
          self
        end
        
        def record(line)
          returning line = "#{line.to_s.chomp.gsub /\;$/, ''};" do
            self << line
          end
        end
  
        def render(*options_for_render)
          Hash === options_for_render.first ? 
            @context.render(*options_for_render) : 
              options_for_render.first.to_s
        end

        def javascript_object_for(object)
          object.respond_to?(:to_json) ? object.to_json : object.inspect
        end

        def arguments_for_call(arguments)
          arguments.map { |argument| javascript_object_for(argument) }.join ', '
        end
      end
      
      # Yields a JavaScriptGenerator and returns the generated JavaScript code.
      # Use this to update multiple elements on a page in an Ajax response.
      # See JavaScriptGenerator for more information.
      def update_page(&block)
        JavaScriptGenerator.new(@template, &block).to_s
      end
      
      # Works like update_page but wraps the generated JavaScript in a <script>
      # tag. Use this to include generated JavaScript in an ERb template.
      # See JavaScriptGenerator for more information.
      def update_page_tag(&block)
        javascript_tag update_page(&block)
      end

    protected
      def options_for_ajax(options)
        js_options = build_callbacks(options)
      
        js_options['asynchronous'] = options[:type] != :synchronous
        js_options['method']       = method_option_to_s(options[:method]) if options[:method]
        js_options['insertion']    = "Insertion.#{options[:position].to_s.camelize}" if options[:position]
        js_options['evalScripts']  = options[:script].nil? || options[:script]

        if options[:form]
          js_options['parameters'] = 'Form.serialize(this)'
        elsif options[:submit]
          js_options['parameters'] = "Form.serialize('#{options[:submit]}')"
        elsif options[:with]
          js_options['parameters'] = options[:with]
        end
      
        options_for_javascript(js_options)
      end

      def method_option_to_s(method) 
        (method.is_a?(String) and !method.index("'").nil?) ? method : "'#{method}'"
      end
    
      def build_observer(klass, name, options = {})
        options[:with] ||= 'value' if options[:update]
        callback = remote_function(options)
        javascript  = "new #{klass}('#{name}', "
        javascript << "#{options[:frequency]}, " if options[:frequency]
        javascript << "function(element, value) {"
        javascript << "#{callback}}"
        javascript << ", '#{options[:on]}'" if options[:on]
        javascript << ")"
        javascript_tag(javascript)
      end
          
      def build_callbacks(options)
        callbacks = {}
        options.each do |callback, code|
          if CALLBACKS.include?(callback)
            name = 'on' + callback.to_s.capitalize
            callbacks[name] = "function(request){#{code}}"
          end
        end
        callbacks
      end
    end

    # Converts chained method calls on DOM proxy elements into JavaScript chains 
    class JavaScriptElementProxy < Builder::BlankSlate #:nodoc:
      def initialize(generator, root)
        @generator = generator
        @generator << root
      end

      def replace_html(*options_for_render)
        call 'update', @generator.render(*options_for_render)
      end

      def replace(*options_for_render)
        call 'replace', @generator.render(*options_for_render)
      end
      
      private
        def method_missing(method, *arguments)
          if method.to_s =~ /(.*)=$/
            assign($1, arguments.first)
          else
            call(method, *arguments)
          end
        end
      
        def call(function, *arguments)
          append_to_function_chain!("#{function}(#{@generator.send(:arguments_for_call, arguments)})")
          self
        end

        def assign(variable, value)
          append_to_function_chain! "#{variable} = #{@generator.send(:javascript_object_for, value)}"
        end
        
        def function_chain
          @function_chain ||= @generator.instance_variable_get("@lines")
        end
        
        def append_to_function_chain!(call)
          function_chain[-1] = function_chain[-1][0..-2] if function_chain[-1][-1..-1] == ";" # strip last ;
          function_chain[-1] += ".#{call};"
        end
    end
  end
end
