/*
 * InlineEditor for FlexFormPlugin 
 *
 * Copyright (c) 2022-2024 Michael Daum
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
      buttonSelector: ".inlineEditButton",
      activeClass: "inlineEditActive"
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
      var self = this, valueEdit;

      self.id = self.elem.attr("id") || "inlineEditor_"+foswiki.getUniqueID();
      self.elem.attr("id", self.id);
      self.editInProgress = false;
      self.isBlocked = false;

      valueEdit = self.elem.find(self.opts.valueSelector);
      valueEdit.parent().addClass("inlineEditValueContainer");
      valueEdit.on("dblclick", function() {
        var elem = $(this);

        if (self.editInProgress) {
          //console.log("edit already in progress");
        } else {
          self.clearSelection();
          self.loadEditor(elem);
          return false;
        }
      });

      valueEdit.each(function() {
        var elem = $(this);
        self.initEditButton(elem);
      });

      $(window).on("beforeunload", function() {
        //console.log("got beforeunload event for ",self.id);

        if (self.editInProgress) {
          return "Are you sure?"; // dummy text
        }

        return;
      });
  };

  InlineEditor.prototype.initForm = function(elem) {
    var self = this,
        form = elem.find("form:first"),
        opts = $.extend({}, self.opts, elem.data());

    form.data("ajaxForm", new AjaxForm(form, {
      beforeSubmit: function() {
        return form.valid();;
      },
      beforeSerialize: function() {
        //console.log("beforeSerialize");
        elem.find("textarea.natedit").each(function() {
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
            self.loadView(elem);
          }
        });
      }
    })).validate({
      ignore: "div, .foswikiIgnoreValidation",
      onsubmit: false,
      ignoreTitle: true
    });

    form.find(".inlineEditCancel").on("click", function() {
      self.unlock().done(function() {
        self.loadView(elem);
      });
      return false;
    });

    form.find("input[type=text]").on("keydown", function(ev) {
      if (ev.key === 'Escape') {
        self.unlock().done(function() {
          self.loadView(elem);
        });
      }
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
      //console.log("... blocking");
      self.isBlocked = true;
      if (txt) {
        msg = "<h1>"+txt+"</h1>";
      }
      //console.log("... msg=",msg);
      $.blockUI({message: msg});
    } else {
      //console.log("... already blocked");
    }
  };

  InlineEditor.prototype.unblock = function() {
    var self = this;

    self.isBlocked = false;
    $.unblockUI();
  };

  InlineEditor.prototype.initEditButton = function(elem) {
    var self = this;

    elem.find(self.opts.buttonSelector).not(".inited").on("click", function() {
      $(this).addClass("inited");
      self.loadEditor(elem);
      return false;
    });
  };

   InlineEditor.prototype.loadTemplate = function(elem, opts) {
      var self = this;

      //console.log("loadTemplate opts=",opts);
      self.block();

      return foswiki.loadTemplate(opts).done(function(data) {
         elem.html(data.expand); //.hide().fadeIn();
      }).always(function() {
         self.unblock();
      });
   };

   InlineEditor.prototype.loadEditor = function (elem) {
      var self = this,
          dfd = $.Deferred();

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
           name: elem.data("template") || self.opts.template,
           expand: elem.data("editorDef") || self.opts.editorDef,
           topic: self.opts.topic
        }, elem.data());

        self.loadTemplate(elem, opts).done(function() {
          elem.parent().addClass(self.opts.activeClass);

          self.elem.addClass("inlineEditorLocked");
          self.elem.trigger("editLoaded", opts);
          self.editInProgress = true;
          elem.find("input[type=text], input[type=password], textarea").first().focus();
          dfd.resolve();
        }).done(function() {
          self.initForm(elem);
        }).fail(failHandler);
      }).fail(failHandler);

      return dfd.promise();
   };

   InlineEditor.prototype.loadView = function (elem) {
      var self = this,
         opts = $.extend({}, {
           name: elem.data("template") || self.opts.template,
           expand: elem.data("viewDef") || self.opts.viewDef,
           topic: self.opts.topic
        }, elem.data());

      delete opts.template;
      delete opts.viewDef;

      return self.loadTemplate(elem, opts).done(function() {
        elem.parent().removeClass(self.opts.activeClass);
        self.elem.removeClass("inlineEditorLocked");
        self.initEditButton(elem);
        self.elem.trigger("viewLoaded", opts);
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
