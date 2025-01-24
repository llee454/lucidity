Simple Form Module
==================

The Simple Form module provides a way to create simple AJAX forms that send JSON POST requests.

The module defines a set of input element blocks that are connected to a single form block. When the submit button registered with the form is clicked, this module generates a JSON object with all of the input values and sends it to the specified URL.

```javascript
/*
  The Simple Form module provides a way to create simple AJAX forms
  that send JSON POST requests.
*/
```

Callback Store
--------------

Whenever Simple Form submits a form, it calls the functions associated with the form that are stored in the callback store.

```javascript
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
```

The Load Event Handler
----------------------

The load event handler registers the block elements.

```javascript
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
```

Block Handlers
--------------

The Simple Form module allows us to create forms simpler than
traditional HTML forms.  Rather than wrap our forms inside HTML
`<form>` elements, we instead create one or more HTML form elements
(input, select, button, etc) and ensure that all of them have a
matching form id using `data-simple-form-id`.  One of the form
elements should be a button that has the `simple_form_block` class
and includes the `data-simple-form-url` attribute to tell the module
where to send the form data.  Simple Form will then find all of the
form elements that have the same form ID, store the form element
values into a JSON string, and send the JSON string to the given URL.

You can use Simple Form to send images and other files. Create an
input element with type "file". The input element must only accept a
single file. Simple Form will convert the file content to a base64
encoded string and send this string to the backend URL within the
JSON object along with all the other form elements.


```javascript
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

           if ($(element).attr ('type') == 'file' && element.files.length > 0) {
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
```

Generating Source Files
-----------------------

You can generate the Mustache module's source files using [Literate Programming](https://github.com/jostylr/literate-programming), simply execute:
`node node_modules/litpro/litpro.js Readme.md -b .`
from the command line.

Simple_form.js
--------------
```
_"Simple Form Module"

_"Callback Store"

_"The Load Event Handler"

_"Block Handlers"
```
[simple_form.js](#Simple_form.js "save:")
