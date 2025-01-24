/*
  This Read More Module provides the Read More block which allows users
  to expand a long text passage.

  TODO: integrate with Google Analytics to record when users click to
  read more.
*/

MODULE_LOAD_HANDLERS.add (
  function (done) {
    $.getCSS ('modules/read_more/css/style.css');
    block_HANDLERS.add ('read_more_block', read_more_block);
    done (null);
});

/*
  Note: Use CSS to control the collapsed and expanded height based on 
  the "read_more_expanded" class.
*/
function read_more_block (context, done) {
  var contentElement = $('<div></div>')
    .addClass ('read_more_content')
    .append ($('<div></div>')
      .addClass ('read_more_content_inner')
      .append (context.element.contents ()));

  var buttonElement = $('<div></div>')
    .addClass ('read_more_button')
    .append ($('<div></div>')
      .addClass ('read_more_button_link')
      .text ("READ MORE")
      .click (function () {
        contentElement.addClass ('read_more_expanded');
        buttonElement.remove ();
      }));

  setInterval (function () {
    if (contentElement.height () < 400) {
      buttonElement.hide ();
    } else {
      buttonElement.show ();
    }
  }, 1000);

  context.element
    .addClass ('read_more')
    .append (contentElement)
    .append (buttonElement)

  done (null);
}
