/*
  The Simple Form module provides a way to create simple AJAX forms
  that send JSON POST requests.
*/

function simple_form_CallbackStore () {
  var _handlers = {};

  this.register = function (formId) {
    _handlers [formId] = [];
  }

  this.add = function (formId, callback) {
    if (_handlers [formId]) {
      _handlers [formId].push (callback);
    } else {
      strictError (new Error ('Error: an error occured while trying to register a Simple Form callback for form ID ' + formId + '. The form does not exist.'));
    }
  }

  this.execute = function (formId, done) {
    async.applyEach (_handlers [formId], done);
  }
}

var simple_form_CALLBACKS = new simple_form_CallbackStore ();

/*
  Registers the block handlers.
*/
MODULE_LOAD_HANDLERS.add (
  function (done) {
    block_HANDLERS.addHandlers ({
      'simple_form_block': simple_form_block
    });
    done (null);
});

/*
  Accepts two arguments:

  * context, a Block Expansion Context
  * and done, a function that accepts two
    arguments: an Error object and a JQuery
    HTML Element

  treats context.element as the submit button for a form. When
  clicked, this module will find all of the other form elements
  that have the same form ID and create a JSON object that contains
  their values. It will then send the resulting JSON object to the
  specified URL.

  Once this function adds this click callback it calls done.
*/
function simple_form_block (context, done) {
  var formId   = context.element.data ('simple-form-id');
  var url      = context.element.data ('simple-form-url');
  var reload   = context.element.data ('simple-form-reload');
  var redirect = context.element.data ('simple-form-redirect');
  var escapeNewlines = context.element.data ('simple-form-escape');

  context.element
    .click (async function () {
       var request = {}
       var elements = $('[data-simple-form-id="' + formId + '"]').toArray (); 
       async.each (elements,
         function (element, next) {
           var name = $(element).data ('simple-form-name');
           if (!name) { return next (); }

           if ($(element).attr ('type') == 'file') {
             if (element.files.length == 0) { return next (); }
             if (element.files.length > 1) {
               return next (new Error ('Error: an error occured while trying to upload files using the Simple Form module. The Simple Form module only supports one file at a time.'));
             }
             var reader = new FileReader ();
             reader.onload = function () {
               var encodedContent = reader.result;
               var contentStartIndex = encodedContent.indexOf ('base64');
               request [name] = encodedContent.slice (contentStartIndex + 7);
               next ();
             };
             reader.onerror = function () {
               next (new Error ('Error: an error occured while trying to upload a file using the Simple Form module.'));
             };
             var file = element.files[0];
             reader.readAsDataURL (file);
           } else {
             var value = "";
             if ($(element).is(':checkbox')) {
               value = $(element).is(':checked') ? 'checked' : '';
             } else {
               value = $(element).val ();
             }
             if (escapeNewlines) {
               value = value
                 .replace (/\n/g, '\\\\n')
                 .replace (/\"/g, '\\"');
             }
             request [name] = value
             next ();
           }
         },
         function (error) {
           if (error) { return strictError (error); }

           $.post (url, JSON.stringify (request) + "\n",
             function (content) {
               simple_form_CALLBACKS.execute (formId, function () {
                 if (reload) {
                   location.reload();
                 } else if (redirect) {
                   loadPage (redirect);
                 } else {
                   alert ('success: ' + content)
                 }
               });
             }, 'text').fail (function () {
               alert ('Form submission failed')
               strictError (new Error ('Error: an error occured while trying to submit a form using the Simple Form module. The backend returned an error code.'));
             });
           
         }
       );
     });

  simple_form_CALLBACKS.register (formId);

  done (null);
}
