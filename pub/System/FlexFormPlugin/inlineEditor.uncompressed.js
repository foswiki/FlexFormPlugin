/*
 * InlineEditor for FlexFormPlugin 
 *
 * Copyright (c) 2022 Michael Daum
 *
 * Licensed under the GPL licenses http://www.gnu.org/licenses/gpl.html
 *
 */

/*global AjaxForm:false  */

"use strict";

(function($) {

   var defaults = {
      template: "inlineedit",
      editorDef: "renderForEdit",
      viewDef: "renderForDisplay",
      valueSelector: ".inlineEditValue",
      buttonSelector: ".inlineEditButton"
   };

   function InlineEditor(elem, opts) {
      var self = this;

      //console.log("new InlineEditor for ",elem);
      self.elem = $(elem);
      self.opts = $.extend({
         topic: foswiki.getPreference("WEB") + "." + foswiki.getPreference("TOPIC")
      }, defaults, this.elem.data(), opts);
      self.init();     
   }

   InlineEditor.prototype.init = function() {
      var self = this;

      self.id = self.elem.attr("id") || "inlineEditor_"+foswiki.getUniqueID();
      self.elem.attr("id", self.id);
      self.editInProgress = false;
      self.isBlocked = false;

      self.valueContainer = self.elem.find(self.opts.valueSelector);
      self.valueContainer.parent().addClass("inlineEditValueContainer");

      self.valueContainer.on("dblclick", function() {
        var container = $(this);

        if (self.editInProgress) {
          //console.log("edit already in progress");
        } else {
          self.clearSelection();
          self.loadEditor(container);
          return false;
        }
      });

      self.valueContainer.each(function() {
        var container = $(this);
        self.initEditButton(container);
      });

      $(window).on("beforeunload", function() {
        //console.log("got beforeunload event.");

        if (self.editInProgress) {
          return "Are you sure?"; // dummy text
        }

        return;
      });
  };

  InlineEditor.prototype.initForm = function(container) {
    var self = this,
        form = container.find("form:first"),
        opts = $.extend({}, self.opts, container.data());

    form.data("ajaxForm", new AjaxForm(form, {
      beforeSubmit: function() {
        return form.valid();;
      },
      beforeSerialize: function() {
        //console.log("beforeSerialize");
        container.find("textarea.natedit").each(function() {
          var natEdit = $(this).data("natedit");
          if (natEdit) {
            natEdit.beforeSubmit();
          }
        });
      },
      complete: function() {
        //console.log("complete");
        self.unlock().done(function() {
          if (opts.reload) {
            window.location.reload();
          } else {
            self.loadView(container);
          }
        });
      }
    })).validate({
      ignore: ":hidden:not(.jqSelect2,.foswikiAttachmentField), div, .foswikiIgnoreValidation",
      onsubmit: false,
      ignoreTitle: true
    });

    form.find(".inlineEditCancel").on("click", function() {
      self.unlock().done(function() {
        self.loadView(container);
      });
      return false;
    });
  };

  InlineEditor.prototype.lock = function() {
    var self = this;

    return foswiki.jsonRpc({
      namespace: "FlexFormPlugin",
      method: "lock",
      params: {
        topic: self.opts.topic
      }
    });
  };

  InlineEditor.prototype.unlock = function() {
    var self = this;

    self.editInProgress = false;

    return foswiki.jsonRpc({
      namespace: "FlexFormPlugin",
      method: "unlock",
      params: {
        topic: self.opts.topic
      }
    });
  };

  InlineEditor.prototype.block = function(txt) {
    var self = this,
        msg = "";

    if (!self.isBlocked) {
      console.log("... blocking");
      self.isBlocked = true;
      if (txt) {
        msg = "<h1>"+txt+"</h1>";
      }
      console.log("... msg=",msg);
      $.blockUI({message: msg});
    } else {
      console.log("... already blocked");
    }
  };

  InlineEditor.prototype.unblock = function() {
    var self = this;

    self.isBlocked = false;
    $.unblockUI();
  };

  InlineEditor.prototype.initEditButton = function(container) {
    var self = this;

    container.find(self.opts.buttonSelector).not(".inited").on("click", function() {
      $(this).addClass("inited");
      self.loadEditor(container);
      return false;
    });
  };

   InlineEditor.prototype.loadTemplate = function(container, opts) {
      var self = this;

      //console.log("loadTemplate opts=",opts);
      self.block();

      return foswiki.loadTemplate(opts).done(function(data) {
         container.html(data.expand); //.hide().fadeIn();
      }).always(function() {
         self.unblock();
      });
   };

   InlineEditor.prototype.loadEditor = function (container) {
      var self = this,
          dfd = $.Deferred();

      container.addClass("inlineEditActive");

      // close any user tooltip
      $(".jqUserTooltip").each(function() {
        $(this).tooltip("close");
      });

      function failHandler(xhr) {
        var json = $.parseJSON(xhr.responseText);

        $.pnotify({
          type: "error",
          title: "Error",
          text: json.error.message
        });

        dfd.fail();
      } 

      self.lock().done(function() {
        var opts = $.extend({}, {
           name: container.data("template") || self.opts.template,
           expand: container.data("editorDef") || self.opts.editorDef,
           topic: self.opts.topic
        }, container.data());

        self.loadTemplate(container, opts).done(function() {
          self.elem.trigger("editLoaded");
          self.editInProgress = true;
          container.find("input[type=text], input[type=password], textarea").first().focus();
          dfd.resolve();
        }).done(function() {
          self.initForm(container);
        }).fail(failHandler);
      }).fail(failHandler);

      return dfd.promise();
   };

   InlineEditor.prototype.loadView = function (container) {
      var self = this,
         opts = $.extend({}, {
           name: container.data("template") || self.opts.template,
           expand: container.data("viewDef") || self.opts.viewDef,
           topic: self.opts.topic
        }, container.data());

      return self.loadTemplate(container, opts).done(function() {
        container.removeClass("inlineEditActive");
        self.initEditButton(container);
        self.elem.trigger("viewLoaded");
      });
   };

  InlineEditor.prototype.clearSelection = function() {
    if (document.selection && document.selection.empty) {
      document.selection.empty();
    } else if (window.getSelection) {
      var sel = window.getSelection();
      sel.removeAllRanges();
    }
  };


   $.fn.inlineEditor = function (opts) {
     return this.each(function () {
       if (!$.data(this, "InlineEditor")) {
         $.data(this, "InlineEditor", new InlineEditor(this, opts));
       }
     });
   };

  $(function() {
    $(".inlineEditor").livequery(function() {
      $(this).inlineEditor();
    });
  });

})(jQuery);
