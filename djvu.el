;;; djvu.el --- Edit and view Djvu files via djvused -*- lexical-binding: t -*-

;; Copyright (C) 2011-2020  Free Software Foundation, Inc.

;; Author: Roland Winkler <winkler@gnu.org>
;;   Daniel Nicolai <dalanicolai@gmail.com>
;; Keywords: files, wp
;; Version: 2.0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package is a front end for the command-line program djvused
;; from DjVuLibre, see http://djvu.sourceforge.net/.  It assumes you
;; have the programs djvused, djview, ddjvu, and djvm installed.
;;
;; A Djvu document contains an image layer (typically scanned page images)
;; as well as multiple textual layers [text (for scanned documents from OCR),
;; annotations, shared annotations, and bookmarks].  The command-line
;; program djvused allows one to edit these textual layers via suitable
;; scripts.  With Djvu mode you can edit and apply these djvused scripts
;; as if you were directly editing the textual layers of a Djvu document
;; (though Emacs never visits the Djvu document in the usual Emacs sense
;; of copying the content of a file into a buffer to manipulate it).
;; With Djvu mode you can also view the page images of a Djvu document,
;; yet Djvu mode does not attempt to reinvent the functionality of the
;; native viewer djview for Djvu documents.  (I find djview very efficient
;; / fast for its purposes that also include features like searching the
;; text layer.)  So Djvu mode assumes that you use djview to view the
;; Djvu document while editing its textual layers.  Djview and Djvu mode
;; complement each other.
;;
;; A normal work flow is as follows:
;;
;; Djvu files are assumed to have the file extension ".djvu".
;; When you visit the file foo.djvu, it puts you into the (read-only)
;; buffer foo.djvu.  Normally, this buffer (plus possibly the outline buffer)
;; is all you need.
;;
;; The menu bar of this buffer lists most of the commands with their
;; respective key bindings.  For example, you can:
;;
;; - Use `g' to go to the page you want.  (Yes, Djvu mode operates on one
;;   page at a time.  Anything else would be too slow for large documents.)
;;
;; - Use `v' to (re)start djview using the position in the file foo.djvu
;;   matching where point is in the buffer foo.djvu.  (I find djview
;;   fast enough for this, even for larger documents.)
;;
;;   Yet note also that, starting from its version 4.9, djview reloads
;;   djvu documents automatically when the djvu file changed on disk.
;;   So you need not restart it anymore while editing a Djvu document
;;   with Djvu mode.  (Thank you, Leon Bottou!)
;;
;;   Djvu mode likewise detects when the file changed on disk
;;   (say, because the file was modified by some other application),
;;   so that you can revert the buffers visiting this file.
;;
;; - To highlight a region in foo.djvu mark the corresponding region
;;   in the buffer foo.djvu (as usual, `transient-mark-mode' comes handy
;;   for this).  Then type `h' and add a comment in the minibuffer if you
;;   like.  Type C-x C-s to save this editing.  View your changes with
;;   djview.
;;
;; - Type `i' to enable `djvu-image-mode', a minor mode displaying the
;;   current page as an image.  Then
;;     drag-mouse-1 defines a rect area
;;     S-drag-mouse-1 defines an area where to put a text area,
;;     C-drag-mouse-1 defines an area where to put a text area w/pushpin.
;;
;; - Use `o' to switch to the buffer foo.djvu-o displaying the outline
;;   of the document (provided the document contains bookmarks that you
;;   can add with Djvu mode).  You can move through a multi-page document
;;   by selecting a bookmark in the outline buffer.
;;
;; - The editing of the text, annotation, shared annotation and outline
;;   (bookmarks) layers really happens in the buffers foo.djvu-t,
;;   foo.djvu-a, foo-djvu-s, and foo.djvu-b.  The djvused script syntax
;;   used in these buffers is so close to Lisp that it was natural to give
;;   these buffers a `djvu-script-mode' that is derived from `lisp-mode'.
;;
;;   You can check what is happening by switching to these buffers.
;;   The respective switching commands put point in these buffers
;;   such that it matches where you were in the main buffer foo.djvu.
;;
;;   In these buffers, the menu bar lists a few low-level commands
;;   available for editing these buffers directly.  If you know the
;;   djvused script syntax, sometimes it can also be helpful to do
;;   such editing "by hand".
;;
;; But wait: the syntax in the annotations buffer foo.djvu-a is a
;; slightly modified djvused script syntax.
;;
;; - djvused can only highlight rectangles.  So the highlighting of
;;   larger areas of text must use multiple rectangles (i.e.,
;;   multiple djvused "mapareas").  To make editing easier, these
;;   are combined in the buffer foo.djvu-a.  (Before saving these
;;   things, they are converted using the proper djvused syntax.)
;;
;;   When you visit a djvu file, Djvu mode recognizes mapareas
;;   belonging together by checking that "everything else in these
;;   mapareas except for the rects" is the same.  So if you entered
;;   a (unique) comment, this allows Djvu mode to combine all the
;;   mapareas when you visit such a file the second time.  Without a
;;   comment, this fails!
;;
;; - djvused uses two different ways of specifying coordinates for
;;   rectangles
;;     (1) hidden text uses quadrupels (xmin ymin xmax ymax)
;;     (2) maparea annotations use (xmin ymin width height)
;;   Djvu mode always uses quadrupels (xmin ymin xmax ymax)
;;   Thus maparea coordinates are converted from and to djvused's format
;;   when reading and writing djvu files.
;;
;; - Usually Djvu mode operates on the text and annotations layers
;;   for one page of a Djvu document.  If you really (I mean: REALLY)
;;   want to edit a raw djvused script for the complete text or
;;   annotations layer of a djvu document, use `djvu-text-script' or
;;   `djvu-annot-script' to generate these raw scripts.  When you have
;;   finished editing, you can re-apply the script by calling
;;   `djvu-process-script'.  Use this at your own risk.  This code does
;;   not check whether the raw script is meaningful.  You can loose the
;;   text or annotations layer if the script is messed up.

;;; News:

;; v1.1:
;; - Use `auto-mode-alist' with file extension ".djvu".
;;
;; - Support bookmarks.
;;
;; - Display total number of pages in mode line.
;;
;; - New option `djvu-rect-area-nodups'.
;;
;; - User options `djvu-save-after-edit' and `djvu-region-history' removed
;;   (obsolete).
;;
;; - More robust code for merging lines in text layer.
;;
;; - Clean up handling of editing positions in a djvu document.
;;
;; - Bug fixes.
;;
;; v1.0.1:
;; - Use `create-file-buffer' instead of `generate-new-buffer'
;;   for compatibility with uniquify.
;;
;; v1.0:
;; - New commands `djvu-revert-buffer', `djvu-re-search-forward',
;;   `djvu-re-search-forward-continue', `djvu-history-backward',
;;   `djvu-history-forward', `djvu-dpi', `djvu-dpi-unify', `djvu-rotate',
;;   `djvu-page-title', `djvu-ls', `djvu-inspect-file', `djvu-delete-page',
;;   and `djvu-remove-annot'.
;;
;; - New commands for editing the text layer `djvu-edit-word',
;;   `djvu-split-word', `djvu-merge-words', and `djvu-merge-lines'.
;;
;; - Make backups when editing Djvu documents.
;;
;; - Pretty-printed outline buffer for bookmarks.
;;
;; - Shared annotations buffer.
;;
;; - Font locking.

;;; To do:

;; - Auto-save script buffers.  How can we recover these buffers
;;   in a meaningful way?
;;
;; - Use `replace-buffer-contents'?
;;
;; - New command that makes line breaks in text layer better searchable:
;;   Scan text layer for lines ending with hyphenated words "xxx-".
;;   If the first word of the next line is "yyy" and ispell knows
;;   the word "xxxyyy", replace "yyy" with that string.  A search
;;   for the word "xxxyyy" will then succeed.

;;; Code:

;;; Djvu internals (see Sec. 8.3.4.2.3.1 of djvu3spec.djvu)
;;
;; Supported area attributes             rect  oval  poly  line  text
;; (none)/(xor)/(border c)                X     X     X     X     X
;; (shadow_* t)                           X
;; (border_avis)                          X     X     X
;; (hilite color) / (opacity o)           X
;; (arrow) / (width w) / (lineclr c)                        X
;; (backclr c) / (textclr c) / (pushpin)                          X
;;
;; c = #RRGGBB   t = thickness (1..32)
;; o = opacity = 0..200 (yes)
;;
;; zones: page, column, region, para, line, word, and char

(require 'button)
(eval-when-compile
  (require 'cl-lib))

(defgroup djvu nil
  "Djvu mode."
  :group 'wp
  :prefix "djvu-")

(defcustom djvu-color-highlight "yellow"
  "Default color for highlighting."
  :group 'djvu
  :type 'string)

(defcustom djvu-color-himark "red"
  "Default color for highmarking."
  :group 'djvu
  :type 'string)

(defcustom djvu-color-url "blue"
  "Default color for URLs."
  :group 'djvu
  :type 'string)

(defcustom djvu-color-background "white"
  "Default background."
  :group 'djvu
  :type 'string)

(defcustom djvu-color-line "black"
  "Default line color."
  :group 'djvu
  :type 'string)

(defcustom djvu-color-alist
  ;; If the keys are strings, they are directly compatible with what
  ;; we get back from something like `completing-read'.
  '(("red"     . "#FF0070") ; 0
    ("green"   . "#00FF00") ; 1
    ("blue"    . "#6666FF") ; 2
    ("yellow"  . "#EEFF00") ; 3
    ("orange"  . "#FF7F00") ; 4
    ("magenta" . "#FF00FF") ; 5
    ("purple"  . "#7F60FF") ; 6
    ("cyan"    . "#00FFFF") ; 7
    ("white"   . "#FFFFFF") ; 8
    ("black"   . "#000000")); 9
  "Alist of colors for highlighting."
  :group 'djvu
  :type '(repeat (cons (string) (string))))

(defcustom djvu-line-width 1
  "Default line width."
  :group 'djvu
  :type 'integer)

(defcustom djvu-opacity 50
  "Default opacity for Highlighting."
  :group 'djvu
  :type 'integer)

(defcustom djvu-areas-justify 0.02
  "Upper threshold for justifying area coordinates."
  :group 'djvu
  :type 'number)

(defcustom djvu-fill-column 50
  "Fill column for Djvu annotations."
  :group 'djvu
  :type 'integer)

(defcustom djvu-script-buffer "*djvu*"
  "Default buffer for \"raw\" djvused scripts."
  :group 'djvu
  :type 'string)

(defcustom djvu-buffer-name-extensions
  '("" "-t" "-a" "-s" "-b" "-o")
  "Extensions for Djvu buffer names.
This is a list with six elements (READ TEXT ANNOT SHARED BOOKMARKS OUTLINE)."
  :group 'djvu
  :type '(list (string) (string) (string) (string) (string) (string)))

(defcustom djvu-image-size 1024
  "Size of internally displayed image.  This is MAX (width, height)."
  :group 'djvu
  :type 'integer)

(defcustom djvu-inherit-input-method t
  "If non-nil calls of `read-string' inherit the input method."
  :group 'djvu
  :type 'boolean)

(defcustom djvu-djview-command "djview"
  "Command for the Djvu Viewer."
  :group 'djvu
  :type 'string)

(defcustom djvu-djview-options nil
  "List of command options for the Djvu Viewer."
  :group 'djvu
  :type '(repeat (string)))

(defcustom djvu-file-name-extension-re (regexp-opt '(".djvu" ".djbz" ".iff"))
  "Regular expression for file name extensions in bundled multi-page documents.
These extensions include the period."
  :group 'djvu
  :type 'regexp)

(defcustom djvu-read-prop-newline 2
  "Number of newline characters in Read buffer for consecutive region."
  :group 'djvu
  :type 'integer)

(defcustom djvu-outline-faces
  ;; Same as `outline-font-lock-faces'
  [font-lock-function-name-face font-lock-variable-name-face
  font-lock-keyword-face font-lock-comment-face
  font-lock-type-face font-lock-constant-face
  font-lock-builtin-face font-lock-string-face]
  "Vector of faces for Outline buffer."
  :group 'djvu
  :type '(sexp))

(defcustom djvu-string-replace-list
  '(("-\n+\\([[:lower:]]\\)" . "\\1") ; hyphenation
    ("-\n+" . "-") ; hyphenation
    ("[\n ]+" . " ")) ; white space
  "Replacement list for text strings.
Each element is of the form (REGEXP . REP).
Used by `djvu-region-string'."
  :group 'djvu
  :type '(repeat (cons (regexp) (string))))

(defcustom djvu-rect-area-nodups nil
  "If non-nil `djvu-rect-area' does not create multiple rects for same areas."
  :group 'djvu
  :type 'boolean)

;; Internal variables

(defvar djvu-test nil
  "If non-nil do not process / delete djvused scripts.  Useful for testing.")
;; (setq djvu-test t) (setq djvu-test nil)

(defvar-local djvu-buffer nil
  "Type of Djvu buffer.")

(defvar djvu-rect-list nil
  "Expanded rect list for propertizing the Read buffer.
This is a list with elements (COORDS URL TEXT COLOR ID) stored
in `djvu-doc-rect-list'.")

(defvar djvu-last-rect nil
  "Last rect used for propertizing the Read buffer.
This is a list (BEG END COORDS URL TEXT COLOR).")

;; We use variable `djvu-resolve-url' as an internal flag while we update
;; all internal URLs in a Djvu document via `djvu-resolve-all-urls'.
;; Then we use `djvu-doc-resolve-url' to remember this scheme
;; and for adding new internal URLs consistent with this scheme.
(defvar djvu-resolve-url nil
  "Flag for resolving internal URLs.
If `long' replace short page numbers by long FileIDs.
If `short' replace long FileIDs by short page numbers.
If nil do nothing.
Bind this with `let' to select one of these schemes.")

(defvar djvu-bookmark-level nil
  "Counter for bookmark level.")

(defvar djvu-image-mode) ; fully defined by `define-minor-mode' (buffer-local)

;; See `ediff-defvar-local'
(defmacro djvu-defvar-local (var &optional val doc)
  "Define VAR as a permanent-local variable, and return VAR."
  (declare (doc-string 3))
  `(progn
     (defvar ,var ,val ,doc)
     (make-variable-buffer-local ',var)
     (put ',var 'permanent-local t)
     ,var))

(djvu-defvar-local djvu-doc nil
  "The \"ID\" of a Djvu document.
This is actually the Read buffer acting as the master buffer
of the Djvu document.  This buffer holds all buffer-local values
of variables for a Djvu document.")

;; permanent-local like `buffer-file-name'
(djvu-defvar-local djvu-doc-file nil
  "File name of a Djvu document.")

(djvu-defvar-local djvu-doc-text-buf nil
  "Text buffer of a Djvu document.")

;; "read" refers to the text-only display of djvu files inside emacs
;; "view" refers to external graphical viewers (default djview)

(djvu-defvar-local djvu-doc-read-buf nil
  "Read buffer of a Djvu document.")

(djvu-defvar-local djvu-doc-annot-buf nil
  "Annotation buffer of a Djvu document.")

(djvu-defvar-local djvu-doc-shared-buf nil
  "Shared annotation buffer of a Djvu document.")

(djvu-defvar-local djvu-doc-bookmarks-buf nil
  "Bookmarks buffer of a Djvu document.")

(djvu-defvar-local djvu-doc-outline-buf nil
  "Outline buffer of a Djvu document.")

(djvu-defvar-local djvu-doc-view-proc nil
  "List of djview processes for a Djvu document.")

(defvar-local djvu-doc-resolve-url nil
  "Resolve URLs of a Djvu document.")

(defvar-local djvu-doc-rect-list nil
  "Rect list of a Djvu document.")

(defvar-local djvu-doc-history-backward nil
  "Backward history of a Djvu document.
This is a stack of pages visited previously.")

(defvar-local djvu-doc-history-forward nil
  "Forward history of a Djvu document.")

(defvar-local djvu-doc-page nil
  "Current page number of a Djvu document.")

(defvar-local djvu-doc-pagemax nil
  "Total number of pages of a Djvu document.")

(defvar-local djvu-doc-page-id nil
  "Alist of page IDs of a Djvu document.
Each element is a cons pair (PAGE-NUM . FILE-ID).")

(defvar-local djvu-doc-pagesize nil
  "Size of current page of a Djvu document.")

(defvar-local djvu-doc-read-pos nil
  "The current editing position in the Read buffer (image coordinates).
This is either a list (X Y) or a list or vector (XMIN YMIN XMAX YMAX).
Used in `djvu-image-mode' when we cannot go to this position.")

(defvar-local djvu-doc-image nil
  "Image of current page of a Djvu document.
This is a list (PAGE-NUM MAGNIFICATION IMAGE).")

;;; Helper functions and macros

;; For each Djvu document we have six buffers associated with this document
;; (read, text, annotations, shared annotations, bookmarks and outline buffers).
;; To have document-local variables, `djvu-doc' defines a master buffer
;; that shares the buffer-local values of its variables with the other buffers
;; via the macros `djvu-set' and `djvu-ref'.  We make the read buffer the
;; master buffer.  This choice is rather arbitrary.  The main reason for
;; this choice is that the read buffer is usually the main buffer to work
;; with.  So it becomes easier to inspect the document-local variables.

(defmacro djvu-set (var val &optional doc)
  "Set VAR's value to VAL in Djvu document DOC, and return VAL.
DOC defaults to `djvu-doc'."
  ;; `intern' VAR only once upon compilation
  (let ((var (intern (format "djvu-doc-%s" var)))
        (tmpval (make-symbol "tmpval")))
    ;; There is no equivalent of `buffer-local-value' for setting VAR.
    ;; Therefore, we need to make buffer DOC current before we can set VAR.
    ;; But we evaluate VAL in the current buffer before making DOC current.
    `(let ((,tmpval ,val))
       (with-current-buffer (or ,doc djvu-doc)
         (set ',var ,tmpval)))))

(defmacro djvu-ref (var &optional doc)
  "Return VAR's value in Djvu document DOC.
DOC defaults to `djvu-doc'."
  ;; `intern' VAR only once upon compilation
  (let ((var (intern (format "djvu-doc-%s" var))))
   `(buffer-local-value ',var (or ,doc djvu-doc))))

(defun djvu-header-line (identifier)
  (list (propertize " " 'display '(space :align-to 0))
        ;; Emacs >= 26: compare `proced-header-line'
        (format "%s -- %s (p%d)" (buffer-name (djvu-ref read-buf))
                identifier (djvu-ref page))))

(defsubst djvu-substring-number (string &optional from to base)
  "Parse substring of STRING as a decimal number and return the number.
If BASE, interpret STRING as a number in that base."
  (string-to-number (substring-no-properties string from to) base))

(defsubst djvu-match-number (num &optional string base)
  "Return string of text matched by last search, as a number.
If BASE, interpret match as a number in that base."
  (string-to-number (match-string num string) base))

(defsubst djvu-buffers (&optional doc)
  "Return a list of all buffers for DOC."
  (list (djvu-ref read-buf doc) (djvu-ref text-buf doc)
        (djvu-ref annot-buf doc) (djvu-ref shared-buf doc)
        (djvu-ref bookmarks-buf doc) (djvu-ref outline-buf doc)))

(defmacro djvu-all-buffers (doc &rest body)
  "Evaluate BODY in all buffers of Djvu DOC."
  (declare (indent 1))
  `(dolist (buf (djvu-buffers ,doc))
     (with-current-buffer buf
       ,@body)))

(defmacro djvu-with-temp-file (file &rest body)
  "Evaluate BODY with temp file FILE deleted at the end.
Preserve FILE if `djvu-test' is non-nil."
  (declare (indent 1) (debug (symbolp body)))
  `(let ((,file (make-temp-file "djvu-")))
     (unwind-protect
         (progn ,@body)
       (unless djvu-test (delete-file ,file)))))

(defun djvu-switch-read (&optional doc dpos)
  "Switch to Djvu Read buffer."
  (interactive (list nil (djvu-dpos)))
  (switch-to-buffer (djvu-ref read-buf doc))
  (djvu-goto-read dpos))

(defun djvu-switch-text (&optional doc dpos)
  "Switch to Djvu Text buffer."
  (interactive (list nil (djvu-dpos)))
  (switch-to-buffer (djvu-ref text-buf doc))
  (djvu-goto-dpos 'word dpos))

(defun djvu-switch-annot (&optional doc dpos)
  "Switch to Djvu Annotations buffer."
  (interactive (list nil (djvu-dpos)))
  (switch-to-buffer (djvu-ref annot-buf doc))
  (if (djvu-goto-dpos "\\(?:rect\\|text\\)" dpos)
      ;; If we have matching buffer position in the annotations buffer,
      ;; put point at the end of the annotations string.
      (re-search-backward "\"")))

(defun djvu-switch-shared (&optional doc)
  "Switch to Djvu Shared Annotations buffer."
  (interactive)
  (switch-to-buffer (djvu-ref shared-buf doc)))

(defun djvu-switch-bookmarks (&optional doc page)
  "Switch to Djvu Bookmarks buffer."
  (interactive (list nil (if (eq djvu-buffer 'outline)
                             (djvu-outline-page)
                           (djvu-ref page))))
  ;; Try to go to the current page in the bookmarks buffer.
  ;; If this page is not defined, try to go to the nearest preceding page.
  (switch-to-buffer (djvu-ref bookmarks-buf doc))
  (when page
    (goto-char (point-min))
    (if (looking-at "(bookmarks")
        (while (and (< 0 page)
                    (not (re-search-forward
                          (format "\"#\\(%d\\|%s\\)\"" page
                                  (cdr (assq page (djvu-ref page-id doc))))
                          nil t)))
          (setq page (1- page))))))

(defun djvu-switch-outline (&optional doc page)
  "Switch to Djvu Outline buffer."
  (interactive (list nil (if (eq djvu-buffer 'bookmarks)
                             (djvu-bookmarks-page)
                           (djvu-ref page))))
  (switch-to-buffer (djvu-ref outline-buf doc))
  (if page (djvu-goto-outline page)))

(defun djvu-dpos (&optional doc)
  "Djvu position in current Djvu buffer."
  (cond ((eq djvu-buffer 'read)
         (djvu-read-dpos nil doc))
        ((eq djvu-buffer 'text)
         (djvu-text-dpos nil doc))
        ((eq djvu-buffer 'annot)
         (djvu-annot-dpos nil doc))))

(defun djvu-read-page ()
  "Read page number interactively."
  (let ((str (read-string (format "Page (f, 1-%d, l): " (djvu-ref pagemax)))))
    (cond ((string-match "\\`f" str) 1)
          ((string-match "\\`l" str) (djvu-ref pagemax))
          ((string-match "\\`[[:digit:]]+\\'" str)
           (string-to-number str))
          (t (user-error "Page `%s' invalid" str)))))

(defun djvu-next-page (n)
  "Go to the next page of this Djvu document."
  (interactive "p")
  (djvu-goto-page (+ (djvu-ref page) n)))

(defun djvu-prev-page (n)
  "Go to the previous page of this Djvu document."
  (interactive "p")
  (djvu-goto-page (- (djvu-ref page) n)))

(defun djvu-history-backward ()
  "Go backward in the history of visited pages."
  (interactive)
  (let ((history-backward (djvu-ref history-backward))
        (history-forward (cons (djvu-ref page)
                               (djvu-ref history-forward))))
    (unless history-backward
      (user-error "This is the first page you looked at"))
    (djvu-goto-page (car history-backward))
    (djvu-set history-backward (cdr history-backward))
    (djvu-set history-forward history-forward)))

(defun djvu-history-forward ()
  "Go forward in the history of visited pages."
  (interactive)
  (let ((history-forward (djvu-ref history-forward)))
    (unless history-forward
      (user-error "This is the last page you looked at"))
    (djvu-goto-page (car history-forward))
    (djvu-set history-forward (cdr history-forward))))

(defun djvu-set-color-highlight (color)
  "Set color for highlighting based on `djvu-color-alist'."
  (interactive (list (completing-read "Color: " djvu-color-alist nil t)))
  (setq djvu-color-highlight color))

(defun djvu-kill-view (&optional doc all)
  "Kill most recent Djview process for DOC.
If ALL is non-nil, kill all Djview processes."
  (interactive (list nil current-prefix-arg))
  (let ((proc-list (djvu-ref view-proc doc)) proc nproc-list)
    ;; Clean up process list
    (while (setq proc (pop proc-list))
      (unless (memq (process-status proc) '(exit signal))
        (push proc nproc-list)))
    (setq proc-list (nreverse nproc-list))
    (while (setq proc (pop proc-list))
      (quit-process proc)
      (djvu-set view-proc proc-list)
      (unless all (setq proc-list nil)))))

(defun djvu-kill-doc (&optional doc)
  "Kill all buffers visiting DOC.
This relies on `djvu-kill-doc-all' for doing the real work."
  (interactive)
  ;; `djvu-kill-doc-all' will try to save our work and kill all djview
  ;; processes.
  (mapc 'kill-buffer (djvu-buffers doc)))

(defvar djvu-in-kill-doc nil
  "Non-nil if we are running `djvu-kill-doc-all'.")

(defun djvu-kill-doc-all ()
  "Kill all buffers visiting `djvu-doc' except for the current buffer.
This function is added to `kill-buffer-hook' of all buffers visiting `djvu-doc'
so that killing the current buffer kills all buffers visiting `djvu-doc'."
  (unless djvu-in-kill-doc
    (let ((djvu-in-kill-doc t)
          buffers)
      ;; Sometimes we choke on broken djvu files so that many things
      ;; do not work anymore the way they should.  At least, we want to
      ;; be able to kill the relevant buffers.  So do not bail out here.
      (condition-case nil
          (let ((doc djvu-doc))
            (setq buffers (djvu-buffers doc))
            (unless (memq nil (mapcar 'buffer-live-p buffers))
                (djvu-save doc t))
            (djvu-kill-view doc t))
        (error nil))
      ;; A function in `kill-buffer-hook' should not kill the buffer
      ;; for which we called this hook in the first place, so that
      ;; other functions in this hook can do their job, too.
      (mapc 'kill-buffer (delq (current-buffer) buffers)))))

(defun djvu-save (&optional doc query)
  "Save Djvu DOC."
  (interactive)
  (unless doc (setq doc djvu-doc))
  (let ((afile (abbreviate-file-name (djvu-ref file doc)))
        (text-modified  (buffer-modified-p (djvu-ref text-buf doc)))
        (annot-modified (buffer-modified-p (djvu-ref annot-buf doc)))
        (shared-modified (buffer-modified-p (djvu-ref shared-buf doc)))
        (bookmarks-modified (buffer-modified-p (djvu-ref bookmarks-buf doc))))
    (when (and (or text-modified annot-modified shared-modified bookmarks-modified)
               (or (and (verify-visited-file-modtime doc)
                        (or (not query)
                            (yes-or-no-p (format "Save %s? " afile))))
                   (yes-or-no-p (format "%s has changed since visited or saved.  Save anyway? "
                                        afile))))
      (djvu-with-temp-file script
        (if annot-modified (djvu-save-annot script doc))
        (if shared-modified (djvu-save-annot script doc t))
        (if text-modified (djvu-save-text doc script)) ; updates Read buffer
        (if bookmarks-modified (djvu-save-bookmarks script doc))
        (djvu-djvused doc nil "-f" script "-s"))
      (if (and annot-modified (not text-modified))
          (djvu-init-read (djvu-read-text doc) doc))
      (djvu-all-buffers doc
        (set-buffer-modified-p nil)))))

(defun djvu-modified ()
  "Mark Djvu Read and Outline buffers as modified if necessary.
Used in `post-command-hook' of the Djvu Read, Text, Annotations,
Bookmarks and Outline buffers."
  (let ((modified (or (buffer-modified-p (djvu-ref bookmarks-buf))
                      (buffer-modified-p (djvu-ref text-buf))
                      (buffer-modified-p (djvu-ref annot-buf))
                      (buffer-modified-p (djvu-ref shared-buf)))))
    (with-current-buffer (djvu-ref read-buf)
      (set-buffer-modified-p modified))
    (with-current-buffer (djvu-ref outline-buf)
      (set-buffer-modified-p modified))))

(defun djvu-quit-window (&optional kill doc)
  "Quit all windows of Djvu document DOC and bury its buffers.
With prefix KILL non-nil, kill the buffers instead of burying them."
  (interactive "P")
  (unless doc (setq doc djvu-doc))
  (dolist (buf (djvu-buffers doc))
    (let ((window (get-buffer-window buf t)))
      (cond (window
             ;; Quitting one Djvu window may bring up again the Djvu window
             ;; of another Djvu buffer for the same Djvu document.
             ;; So we first remove these Djvu buffers from the list
             ;; of buffers previously displayed in this window.
             (let ((prev-buffers (window-prev-buffers window)))
               (dolist (b (djvu-buffers doc))
                 (setq prev-buffers (assq-delete-all b prev-buffers)))
               (set-window-prev-buffers window prev-buffers))
             (quit-window kill window))
            (kill
             (kill-buffer buf))
            (t
             (bury-buffer buf))))))

(defun djvu-djvused (doc buffer &rest args)
  "Process Djvu DOC by running the command djvused with ARGS.
BUFFER receives the process output, t means current buffer.
If BUFFER is nil, discard the process output, assuming that
the purpose of calling djvused is to update the Djvu file."
  (unless doc (setq doc djvu-doc))
  (unless (or buffer (file-writable-p (djvu-ref file doc)))
    (user-error "File `%s' not writable"
                (abbreviate-file-name (djvu-ref file doc))))
  (when (or buffer (not djvu-test))
    (unless buffer
      (djvu-backup doc))
    ;; We could separately preserve the error stream.  Yet this must go
    ;; into a file; it cannot go into a buffer.  So we'd have to check
    ;; in the end whether the file was non-empty and then delete it.
    (let* ((inhibit-quit t)
           (coding-system-for-read 'utf-8)
           (status (apply 'call-process "djvused" nil buffer nil
                          "-u" (djvu-ref file doc) args)))
      (unless (zerop status)
        (error "Djvused error %s (args: %s)" status args))
      (unless buffer
        (djvu-all-buffers doc
          (set-visited-file-modtime))))))

(defun djvu-backup (doc)
  "Make a backup of the disk file for Djvu document DOC, if appropriate."
  (with-current-buffer doc
    (unless buffer-backed-up
      (let* ((file (djvu-ref file doc))
             (real-file (file-chase-links file))
             (val (backup-buffer)))
        (when buffer-backed-up
          ;; Propagate the news
          (djvu-all-buffers doc
            (setq buffer-backed-up t))
          ;; Honor `backup-by-copying' and friends.
          ;; Yet if FILE does not exist anymore because `backup-buffer'
          ;; renamed it, we need to recreate FILE for djvused.
          ;; Strictly speaking, we recreate REAL-FILE because that is
          ;; the file that `backup-buffer' has renamed.
          ;; Then we also update the file-number for FILE.  Yet we
          ;; need not worry here about the modification time because
          ;; we called `djvu-backup' from something like `djvu-djvused',
          ;; which anyway needs to update the recorded modification time.
          (unless (file-exists-p real-file)
            (backup-buffer-copy (nth 2 val) real-file
                                (nth 0 val) (nth 1 val))
            (let ((file-number (nthcdr 10 (file-attributes file))))
              (djvu-all-buffers doc
                (setq buffer-file-number file-number)))))))))

(defvar djvu-color-attributes '(border hilite lineclr backclr textclr)
  "List of color attributes known to Djvu.")

(defvar djvu-color-re
  (concat "(" (regexp-opt (mapcar 'symbol-name djvu-color-attributes) t)
          "[ \t\n]+\\(%s\\(%s[[:xdigit:]][[:xdigit:]]"
          "[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\\)%s\\)[ \t\n]*)")
  "Format string to create a regular expression matching color attributes.")

;; The Emacs lisp reader gets confused by the Djvu color syntax with
;; symbols '#000000.  So we temporarily convert these these symbols to strings.
(defun djvu-convert-hash (&optional reverse)
  "Convert color symbols #000000 to strings \"#000000\".
Perform inverse transformation if REVERSE is non-nil."
  (if reverse
      (let ((re (format djvu-color-re "\"" "#" "\"")))
        (goto-char (point-min))
        (while (re-search-forward re nil t)
          (replace-match (match-string 3) nil nil nil 2)))
    (let ((re (format djvu-color-re "#" "" "")))
      (goto-char (point-min))
      (while (re-search-forward re nil t)
        (replace-match (format "\"%s\"" (match-string 2)) nil nil nil 2)))))

;; Without this macro, we'd have to deactivate the region immediately,
;; before we have decided what to do with it.  That would be annoying.
;; Or leave the region active - equally annoying.
;; Also useful now: the region remains active if we abort the command
;; prematurely.
(defmacro djvu-with-region (region &rest body)
  "Provide REGION while executing BODY, deactivating REGION afterwards.
This is useful for the interactive spec of commands operating on REGION."
  (declare (indent 1) (debug (symbolp body)))
  `(let ((,region (let (beg end)
                    (if (use-region-p)
                        (setq beg (region-beginning)
                              end (region-end))
                      (setq beg (point) end beg))
                    (setq beg (djvu-property-beg beg 'word)
                          end (djvu-property-end end 'word))
                    (cons beg end))))
     (prog1 (progn ,@body)
       (if (and transient-mark-mode mark-active) (deactivate-mark)))))

(defun djvu-region-string (region &optional list)
  "Return REGION of current buffer as string.  REGION is a cons (BEG . END).
Apply replacements LIST to the buffer substring defined by REGION.
Each element in LIST is a cons (REGEXP . REP).
LIST defaults to `djvu-string-replace-list'.  Return the resulting string."
  (let ((string (buffer-substring-no-properties (car region)
                                                (cdr region)))
        case-fold-search)
    (dolist (elt (or list djvu-string-replace-list))
      (setq string (replace-regexp-in-string (car elt) (cdr elt) string)))
    string))

(defun djvu-read-string (prompt region &optional initial-input)
  "Read a string from the minibuffer, prompting with string PROMPT.
REGION is a cons (BEG . END) that defines the default.
If INITIAL-INPUT is non-nil use string from REGION as initial input."
  (if initial-input
      ;; Make the string in REGION the initial input.
      (read-string prompt (djvu-region-string region)
                   nil nil djvu-inherit-input-method)
    (read-string prompt nil nil (djvu-region-string region)
                 djvu-inherit-input-method)))

(defun djvu-interactive-color (color)
  "Return color specification for use in interactive calls.
The color is the Nth element of `djvu-color-alist'.
Here N is `current-prefix-arg' if this is a number.
N is 1 - `current-prefix-arg' / 4 if the prefix is a cons,
that is, `C-u' yields N = 0.
Arg COLOR defines the default when there is no prefix arg."
  (let ((colnum (or (and (consp current-prefix-arg)
                         (1- (/ (car current-prefix-arg) 4)))
                    (and (integerp current-prefix-arg)
                         current-prefix-arg))))
    (if (and colnum (>= colnum (length djvu-color-alist)))
        (user-error "Color undefined"))
    (if colnum (car (nth colnum djvu-color-alist)) color)))

(defun djvu-page-url (&optional page dir doc)
  "For Djvu DOC return the internal url for PAGE.
This is the inverse of `djvu-url-page'."
  (let ((page (or page (djvu-ref page doc))))
    (format "#%s" (if (eq 'long (or dir (djvu-ref resolve-url doc)))
                      (cdr (assq page (djvu-ref page-id doc)))
                    page))))

(defun djvu-interactive-url (&optional color)
  "Return URL specification for use in interactive calls."
  (let ((fmt (format "(%s) URL: " (or color djvu-color-url)))
        val)
    (while (not val)
      (setq val (read-string fmt))
      (cond ((string-match "\\`#?\\([0-9]+\\)\\'" val)
             (setq val (djvu-match-number 1 val))
             (if (<= 1 val (djvu-ref pagemax))
                 (setq val (djvu-page-url val))
               (message "Page number %d out of range (1-%d)"
                        val (djvu-ref pagemax))
               (sit-for 1)
               (setq val nil)))
            ((not (string-match "\\`[a-z]+://" val))
             (message "URL `%s' not recognized" val)
             (sit-for 1)
             (setq val nil))))
    val))

(defun djvu-color-background (color &optional background opacity invert)
  "For rgb COLOR and BACKGROUND apply OPACITY.
Return the new rgb color string.
If BACKGROUND is nil, use `djvu-color-background'.
If OPACITY is nil, use `djvu-opacity'.
If INVERT is non-nil apply inverse transformation."
  (let* ((color (if (string-match "\\`#" color) color
                  (cdr (assoc color djvu-color-alist))))
         (background (if (and background (string-match "\\`#" background))
                         background
                       (cdr (assoc (or background djvu-color-background)
                                   djvu-color-alist))))
         (a (/ (float (or opacity djvu-opacity)) 200)) ; foreground
         (b (- 1 a))) ; background
    (if invert
        (cl-flet ((mix (beg end)
                       (max 0 (min #xFF
                       (round (/ (- (djvu-substring-number color beg end 16)
                                    (* b (djvu-substring-number background beg end 16)))
                                 a))))))
          (format "#%02X%02X%02X"
                  (mix 1 3) (mix 3 5) (mix 5 7)))
      (cl-flet ((mix (beg end)
                     (max 0 (min #xFF
                     (round (+ (* a (djvu-substring-number color beg end 16))
                               (* b (djvu-substring-number background beg end 16))))))))
        (format "#%02X%02X%02X"
                (mix 1 3) (mix 3 5) (mix 5 7))))))

;;; Djvu annotations draw
(defun djvu-annots-listify ()
  (interactive)
  (let ((buffer (get-buffer-create "*annot-list*")))
    (with-current-buffer (djvu-ref annot-buf)
      (copy-to-buffer "*annot-list*" (point-min) (point-max)))
    (with-current-buffer buffer
      (while (re-search-forward " \\(#[[:alnum:]]+\\)" nil t)
        (replace-match " \"\\1\""))
      (goto-char (point-min))
      (insert "(setq djvu-annots '(")
      (goto-char (point-max))
      (insert "))")
      (emacs-lisp-mode)
      (indent-region (point-min) (point-max))
      (eval-buffer))))

(defun djvu-annot-area (annot-geom-list image-size scaling-factor &optional caption)
  (let* ((scaled-list (mapcar (lambda (x) (* x scaling-factor)) (cdr annot-geom-list)))
         (x1 (nth 0 scaled-list))
         (y1 (- image-size (nth 1 scaled-list)))
         (x2 (nth 2 scaled-list))
         (y2 (- image-size (nth 3 scaled-list))))
    (if (equal (car annot-geom-list) 'text)
        (if caption
            (format "%sx%s" (- x2 x1) (- y1 y2))
          (format "+%s+%s" x1 y2))
      (format (cond ((equal (car annot-geom-list) 'rect) "%s,%s,%s,%s")
                    ((equal (car annot-geom-list) 'line) "%s,%s %s,%s"))
              x1
              y1
              x2
              y2))))

(defun djvu-annot-arrow-head (annot-geom-list image-size scaling-factor color)
  (let* ((scaled-list (mapcar (lambda (x) (* x scaling-factor)) (cdr annot-geom-list)))
         (rot-rad (let* ((dy (- (- image-size (nth 3 scaled-list)) (- image-size (nth 1 scaled-list))))
                         (dx (- (nth 2 scaled-list) (nth 0 scaled-list)))
                         (angle (atan (/ dy dx))))
                    (if (< dx 0)
                        (+ angle 3.14)
                      angle)))
         (rot-deg (/ (* rot-rad 180) 3.14)))
    (format " -draw \"stroke %s fill %s translate %s,%s rotate %s path 'M 0,0  l -15,-5  -0,+10  +15,-5 z'\""
            color
            color
            (nth 2 scaled-list)
            (- image-size (nth 3 scaled-list))
            rot-deg)))

(defun djvu-annots-draw (image-size scaling-factor)
  (let ((convert-args ""))
    (dolist (x djvu-annots)
      (when (equal (car x) 'maparea)
        (let* ((annot-geom-lists (nth 3 x))
               (annot-geom-list (if (listp (car annot-geom-lists))
                                    (car annot-geom-lists)
                                  annot-geom-lists))
               (text (nth 2 x)))
          (let ((arg ""))
            (cond ((equal (car annot-geom-list) 'line)
                   (let ((stroke (car (alist-get 'lineclr x)))
                         (width (car (alist-get 'width x))))
                     (setq convert-args
                           (concat convert-args
                                   " -stroke " (if (stringp stroke)
                                                   (concat "'" stroke "' ")
                                                 (if stroke
                                                     (format "%s " stroke))
                                                 "Black ")
                                   "-strokewidth " (if width
                                                       (number-to-string width)
                                                     "2")
                                   " -draw 'line " (djvu-annot-area annot-geom-list image-size scaling-factor)
                                   "'"
                                   (when (assoc 'arrow x)
                                     (djvu-annot-arrow-head annot-geom-list
                                                            image-size scaling-factor
                                                            stroke))))))
                  ((equal (car annot-geom-list) 'text)
                   (let* ((background (car (alist-get 'backclr x)))
                          (fill (car (alist-get 'hilite x)))
                          (opacity (car (alist-get 'opacity x)))
                          (caption (make-temp-file "caption" nil ".ppm" (shell-command-to-string (concat "convert"
                                                                                               " -background " (if (stringp background)
                                                                                                                   (concat "'" background "' ")
                                                                                                                 (if background
                                                                                                                     (format "%s " background))
                                                                                                                 "LightGoldenrod ")
                                                                                               " -fill " (if (stringp fill)
                                                                                                             (concat "'" fill "' ")
                                                                                                           (if fill
                                                                                                               (format "%s " fill))
                                                                                                           "Black ")
                                                                                               " -font Cantarell-Regular"
                                                                                               " -size " (djvu-annot-area annot-geom-list image-size scaling-factor t)
                                                                                               " caption:'" text "'"
                                                                                               " ppm:-")))))
                  (call-shell-region
                   (point-min)
                   (point-max)
                   (concat "composite" ; -gravity northwest"
                           " -geometry "
                           (djvu-annot-area annot-geom-list image-size scaling-factor)
                           " "
                           caption
                           " -"
                           " -")
                   t
                   t)))
                  ((equal (car annot-geom-list) 'rect)
                   (let ((fill (car (alist-get 'hilite x)))
                         (opacity (car (alist-get 'opacity x))))
                     (setq convert-args
                           (concat convert-args
                                   " -fill " (if (stringp fill)
                                                 (concat "'" fill "' ")
                                               (if fill
                                                   (format "%s " fill))
                                               "LightGoldenrod ")
                                   " -stroke " (if (stringp fill)
                                                 (concat "'" fill "' ")
                                               (if fill
                                                   (format "%s " fill))
                                               "Black ")
                                   " -strokewidth 1 "
                                   "-draw 'fill-opacity " (if opacity
                                                              (number-to-string (/ (car (alist-get 'opacity x)) 100.0))
                                                            "0.3")
                                   (when (not fill)
                                     " stroke-opacity 0.5 stroke-dasharray 5 3")
                                   " rectangle " (djvu-annot-area annot-geom-list image-size scaling-factor)
                                   "'"))))
                  )))))
    ;; )))
    (when convert-args
      (call-shell-region
       (point-min)
       (point-max)
       (concat "convert -" convert-args " -")
       ;; (message (concat "convert -" convert-args " -"))
       t
       t))))

;;; Djvu modes

(defvar djvu-read-mode-map
  (let ((km (make-sparse-keymap)))
    ;; `special-mode-map'
    ; (define-key km " " 'scroll-up-command)
    ; (define-key km [?\S-\ ] 'scroll-down-command)
    ; (define-key km "\C-?" 'scroll-down-command)
    ; (define-key km "?" 'describe-mode)
    ; (define-key km ">" 'end-of-buffer)
    ; (define-key km "<" 'beginning-of-buffer)

    (define-key km "i"           'djvu-image-toggle)
    (define-key km "v"           'djvu-view)
    (define-key km "\C-c\C-v"    'djvu-view)
    (define-key km "n"           'djvu-next-page)
    (define-key km "p"           'djvu-prev-page)
    (define-key km "g"           'djvu-goto-page)
    (define-key km "f"           'djvu-history-forward)
    (define-key km "r"           'djvu-history-backward) ; "return"
    (define-key km "k"           'djvu-kill-doc)
    (define-key km "s"           'djvu-save)
    (define-key km "\C-x\C-s"    'djvu-save)
    (define-key km "q"           'djvu-quit-window)
    (define-key km "G"           'djvu-revert-buffer)
    (define-key km (kbd "C-c C-S-g") 'djvu-revert-buffer) ; [?\C-c ?\C-\S-g]

    ;; For switch commands we give short key bindings,
    ;; but for consistency we also provide the long bindings
    ;; used by `djvu-script-mode'.
    (define-key km "t"           'djvu-switch-text)
    (define-key km "\C-c\C-t"    'djvu-switch-text)
    (define-key km "\C-c\C-s"    'djvu-re-search-forward)
    (define-key km "\M-,"        'djvu-re-search-forward-continue)
    (define-key km "ee"          'djvu-edit-word)
    (define-key km "es"          'djvu-split-word)
    (define-key km "ew"          'djvu-merge-words)
    (define-key km "el"          'djvu-merge-lines)
    (define-key km "T"           'djvu-text-script)
    (define-key km "P"           'djvu-process-script)

    (define-key km "a"           'djvu-switch-annot)
    (define-key km "\C-c\C-a"    'djvu-switch-annot)
    (define-key km "S"           'djvu-switch-shared)
    (define-key km (kbd "C-c C-S-S") 'djvu-switch-shared)
    (define-key km "h"           'djvu-rect-region) ; highlight
    (define-key km "u"           'djvu-rect-region-url)
    (define-key km "A"           'djvu-annot-script)
    (define-key km "\C-c\C-c"    'djvu-update-color)
    (define-key km "\C-c\C-u"    'djvu-update-url)

    (define-key km "o"           'djvu-switch-outline)
    (define-key km "\C-c\C-o"    'djvu-switch-outline)
    (define-key km "b"           'djvu-switch-bookmarks)
    (define-key km "\C-c\C-b"    'djvu-switch-bookmarks)
    (define-key km "l"           'djvu-mark-line-beg)
    (define-key km "B"           'djvu-bookmark)
    (define-key km "m"           'djvu-himark)

    (define-key km "D"           'djvu-delete-page)
    (define-key km "U"           'djvu-resolve-all-urls)

    ;; unused: c j w x y z
    km)
  "Keymap for Djvu Read Mode.
This is a child of `special-mode-map'.")

(easy-menu-define
  djvu-read-menu djvu-read-mode-map "Djvu Menu"
  '("Djvu"
    ["Djview File" djvu-view t]
    ["Toggle Image mode" djvu-image-toggle t]
    ["Go to Page" djvu-goto-page t]
    ["Save Doc" djvu-save t]
    ["Revert Doc" djvu-revert-buffer t]
    "---"
    ["Search Regexp Forward" djvu-re-search-forward t]
    ["Continue Search Re Forward" djvu-re-search-forward-continue t]
    "---"
    ("Operate on text layer"
     ["Edit Word" djvu-edit-word t]
     ["Split Word" djvu-split-word t]
     ["Merge Words" djvu-merge-words t]
     ["Merge Lines" djvu-merge-lines t]
     ["Switch to Text" djvu-switch-text t])
    ("Operate on annotations layer"
     ["Highlight Region" djvu-rect-region t]
     ["Page URL over Region" djvu-rect-region-url t]
     ["Himark Region" djvu-himark t]
     ["Mark point" djvu-mark-line-beg t]
     ["Update color" djvu-update-color t]
     ["Update url" djvu-update-url t]
     ["Switch to Annotations" djvu-switch-annot t]
     ["Switch to Shared Annotations" djvu-switch-shared t])
    ("Operate on bookmarks layer"
     ["Add Bookmark" djvu-bookmark t]
     ["Switch to Bookmarks" djvu-switch-bookmarks t]
     ["Switch to Outline" djvu-switch-outline t])
    ("Editing multiple pages"
     ["Resolve internal URLs" djvu-resolve-all-urls t]
     ["Text as Script" djvu-text-script t]
     ["Annotations as Script" djvu-annot-script t]
     ["Process Djvused Script" djvu-process-script t])
    ("Destructive commands"
     ["Delete current page" djvu-delete-page t]
     ["Remove Annot / Bookmarks" djvu-make-clean t])
    "---"
    ["Quit Viewing" djvu-quit-window t]
    ["Kill Djvu buffers" djvu-kill-doc t]))

(defvar bookmark-make-record-function)

(define-derived-mode djvu-read-mode special-mode "Djview"
  "Mode for reading Djvu files."
  ;; The Read buffer is not editable.  So do not create auto-save files.
  (setq buffer-auto-save-file-name nil ; permanent buffer-local
        djvu-buffer 'read
        buffer-undo-list t)
  (let ((fmt (concat (car (propertized-buffer-identification "%s"))
                     "  p%d/%d")))
    (setq mode-line-buffer-identification
          `(24 (:eval (format ,fmt (buffer-name) (djvu-ref page)
                              (djvu-ref pagemax))))))
  (setq-local revert-buffer-function #'djvu-revert-buffer)
  (setq-local bookmark-make-record-function #'djvu-bookmark-make-record))

(defvar djvu-script-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km "\C-c\C-r"    'djvu-switch-read)
    (define-key km "\C-c\C-t"    'djvu-switch-text)
    (define-key km "\C-c\C-a"    'djvu-switch-annot)
    (define-key km (kbd "C-c C-S-S") 'djvu-switch-shared)
    (define-key km "\C-c\C-b"    'djvu-switch-bookmarks)
    (define-key km "\C-c\C-o"    'djvu-switch-outline)
    (define-key km "\C-c\C-g"    'djvu-goto-page)
    (define-key km "\C-c\C-p"    'djvu-prev-page)
    (define-key km "\C-c\C-n"    'djvu-next-page)
    (define-key km "\C-c\C-es"   'djvu-split-word-internal)
    (define-key km "\C-c\C-ew"   'djvu-merge-words-internal)
    (define-key km "\C-c\C-el"   'djvu-merge-lines-internal)
    (define-key km "\C-c\C-m"    'djvu-merge-mapareas)
    (define-key km "\C-c\C-c"    'djvu-update-color-internal)
    (define-key km "\C-c\C-u"    'djvu-update-url-internal)
    (define-key km "\C-c\C-z"    'djvu-resize-internal)
    (define-key km "\C-c\C-l"    'djvu-remove-linebreaks-internal)
    (define-key km "\C-x\C-s"    'djvu-save)
    (define-key km "\C-c\C-v"    'djvu-view)
    (define-key km "\C-c\C-q"    'djvu-quit-window)
    (define-key km "\C-c\C-k"    'djvu-kill-doc)
    (define-key km (kbd "C-c C-S-g") 'djvu-revert-buffer) ; [?\C-c ?\C-\S-g]
    km)
  "Keymap for Djvu Script Mode.
This is a child of `lisp-mode-map'.")

(easy-menu-define
  djvu-annot-menu djvu-script-mode-map "Djvu Menu"
  '("Djvu"
    ["Go to Page" djvu-goto-page t]
    ["Switch to Read" djvu-switch-read t]
    ["Switch to Text" djvu-switch-text (not (eq djvu-buffer 'text))]
    ["Switch to Annotations" djvu-switch-annot (not (eq djvu-buffer 'annot))]
    ["Switch to Shared Annotations" djvu-switch-shared (not (eq djvu-buffer 'shared))]
    ["Switch to Bookmarks" djvu-switch-bookmarks t]
    ["Switch to Outline" djvu-switch-outline t]
    ["Save Doc" djvu-save t]
    ["Revert Doc" djvu-revert-buffer t]
    "---"
    ;; These commands make sense only in the annotations buffer
    ["Merge Mapareas" djvu-merge-mapareas (eq djvu-buffer 'annot)]
    ["Update Color" djvu-update-color-internal (eq djvu-buffer 'annot)]
    ["Update URL" djvu-update-url-internal (eq djvu-buffer 'annot)]
    ["Resize Maparea" djvu-resize-internal (eq djvu-buffer 'annot)]
    ["Remove Linebreaks" djvu-remove-linebreaks-internal (eq djvu-buffer 'annot)]
    "---"
    ;; These commands make sense only in the text buffer
    ["Split Word" djvu-split-word-internal (eq djvu-buffer 'text)]
    ["Merge Words" djvu-merge-words-internal (eq djvu-buffer 'text)]
    ["Merge Lines" djvu-merge-lines-internal (eq djvu-buffer 'text)]
    "---"
    ["Quit Djvu" djvu-quit-window t]
    ["Kill Djvu buffers" djvu-kill-doc t]))

(defvar djvu-font-lock-keywords
  `((,(concat "^[ \t]*("
              (regexp-opt '("background" "zoom" "mode" "align"
                            "maparea" "metadata" "bookmarks" "xmp")
                          t))
     1 font-lock-keyword-face)
    (,(concat "\\(?:[ \t]+\\|^\\|(\\)("
              (regexp-opt '("url" "rect" "oval" "poly" "text" "line"
                            "none" "xor" "border" "shadow_in"
                            "shadow_out" "shadow_ein" "shadow_eout"
                            "border_avis" "hilite" "opacity"
                            "arrow" "width" "lineclr"
                            "backclr" "textclr" "pushpin"
                            "page" "column" "region" "para" "line"
                            "word" "char") t) ")")
     1 font-lock-function-name-face)
    ;; url
    (djvu-font-lock-url))
  "Font lock keywords for Djvu buffers.")

(define-derived-mode djvu-script-mode lisp-mode "Djvu Script"
  "Mode for editing Djvu scripts.
The annotations, shared annotations and bookmark buffers use this mode."
  ;; Fixme: we should create auto-save files for the script buffers.
  ;; This requires suitable names for the auto-save files that should
  ;; be derived from `buffer-file-name'.
  (setq buffer-auto-save-file-name nil ; permanent buffer-local
        fill-column djvu-fill-column
        font-lock-defaults '(djvu-font-lock-keywords))
  (let* ((fmt1 (car (propertized-buffer-identification "%s")))
         (fmt2 (concat fmt1 "  p%d/%d")))
    (setq mode-line-buffer-identification
          `(24 (:eval (if djvu-doc
                          (format ,fmt2 (buffer-name) (djvu-ref page)
                                  (djvu-ref pagemax))
                        (format ,fmt1 (buffer-name)))))))
  (setq-local revert-buffer-function #'djvu-revert-buffer)
  (setq-local bookmark-make-record-function #'djvu-bookmark-make-record))

(defvar djvu-outline-mode-map
  (let ((km (make-sparse-keymap)))
    ;; `special-mode-map'
    ; (define-key km " " 'scroll-up-command)
    ; (define-key km [?\S-\ ] 'scroll-down-command)
    ; (define-key km "\C-?" 'scroll-down-command)
    ; (define-key km "?" 'describe-mode)
    ; (define-key km ">" 'end-of-buffer)
    ; (define-key km "<" 'beginning-of-buffer)

    (define-key km "v"           'djvu-view-page)
    (define-key km "\C-c\C-v"    'djvu-view-page)
    (define-key km "n"           'djvu-next-page)
    (define-key km "p"           'djvu-prev-page)
    (define-key km "g"           'djvu-goto-page)
    (define-key km "k"           'djvu-kill-doc)
    (define-key km "s"           'djvu-save)
    (define-key km "\C-x\C-s"    'djvu-save)
    (define-key km "q"           'djvu-quit-window)
    (define-key km "G"           'djvu-revert-buffer)
    (define-key km (kbd "C-c C-S-g") 'djvu-revert-buffer) ; [?\C-c ?\C-\S-g]

    ;; For switch commands we give short key bindings,
    ;; but for consistency we also provide the long bindings
    ;; used by `djvu-script-mode'.
    (define-key km "a"           'djvu-switch-annot)
    (define-key km "\C-c\C-a"    'djvu-switch-annot)
    (define-key km "S"           'djvu-switch-shared)
    (define-key km (kbd "C-c C-S-S") 'djvu-switch-shared)
    (define-key km "b"           'djvu-switch-bookmarks)
    (define-key km "\C-c\C-b"    'djvu-switch-bookmarks)
    (define-key km "t"           'djvu-switch-text)
    (define-key km "\C-c\C-t"    'djvu-switch-text)
    (define-key km "r"           'djvu-switch-read)
    (define-key km "\C-c\C-r"    'djvu-switch-read)

    km)
  "Keymap for Djvu Outline Mode.
This is a child of `special-mode-map'.")

(easy-menu-define
  djvu-outline-menu djvu-outline-mode-map "Djvu Menu"
  '("Djvu"
    ["Djview File" djvu-view-page t]
    ["Go to Page" djvu-goto-page t]
    ["Save Doc" djvu-save t]
    ["Revert Doc" djvu-revert-buffer t]
    "---"
    ["Switch to Read" djvu-switch-read t]
    ["Switch to Text" djvu-switch-text t]
    ["Switch to Annotations" djvu-switch-annot t]
    ["Switch to Shared Annotations" djvu-switch-shared t]
    ["Switch to Bookmarks" djvu-switch-bookmarks t]
    "---"
    ["Quit Viewing" djvu-quit-window t]
    ["Kill Djvu buffers" djvu-kill-doc t]))

(define-derived-mode djvu-outline-mode special-mode "Djvu OL"
  "Mode for reading the outline of Djvu files."
  ;; The Outline buffer is not editable.  So do not create auto-save files.
  (setq buffer-auto-save-file-name nil ; permanent buffer-local
        djvu-buffer 'outline
        buffer-undo-list t)
  (let ((fmt (concat (car (propertized-buffer-identification "%s"))
                     "  p%d/%d")))
    (setq mode-line-buffer-identification
          `(24 (:eval (format ,fmt (buffer-name) (djvu-ref page)
                              (djvu-ref pagemax))))))
  (setq-local revert-buffer-function #'djvu-revert-buffer)
  (setq-local bookmark-make-record-function #'djvu-bookmark-make-record))

;;; General Setup

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.djvu\\'" . djvu-dummy-mode))

;;;###autoload
(defun djvu-dummy-mode ()
  "Djvu dummy mode for `auto-mode-alist'."
  (djvu-find-file buffer-file-name nil nil t))

;; FIXME: Add entry for `change-major-mode-hook'.
;; How should this handle the plethora of buffers per djvu document?

(defun djvu-read-file-name ()
  "Read file name of Djvu file.
The numeric value of `current-prefix-arg' is the page number."
  (let ((page (prefix-numeric-value current-prefix-arg)))
    (list (read-file-name "Find Djvu file: " nil nil nil nil
                          (lambda (f)
                            (or (equal "djvu" (file-name-extension f))
                                (file-directory-p f))))
          page)))

;;;###autoload
(defun djvu-find-file (file &optional page view noselect noconfirm)
  "Read and edit Djvu FILE on PAGE.  Return Read buffer.
If VIEW is non-nil start external viewer.
If NOSELECT is non-nil visit FILE, but do not make it current.
If NOCONFIRM is non-nil don't ask for confirmation when reverting buffer
from file."
  (interactive (djvu-read-file-name))
  (unless page (setq page 1))
  (setq file (expand-file-name file))
  ;; Djvu mode needs a local file.  If FILE is located on a remote system,
  ;; you can use something like `file-local-copy' to edit FILE.
  (if (file-remote-p file)
    (user-error "Cannot handle remote Djvu file `%s'" file))
  (unless (and (file-regular-p file)
               (file-readable-p file))
    (user-error "Cannot open Djvu file `%s'" file))
  (let* ((inhibit-quit t)
         (buf-basename (file-name-nondirectory file))
         (file-truename (abbreviate-file-name (file-truename file)))
         (file-number (nthcdr 10 (file-attributes file)))
         (dir (file-name-directory file))
         (read-only (not (file-writable-p file)))
         (old-buf (if (equal buffer-file-truename file-truename)
                      (current-buffer)
                    (find-buffer-visiting file-truename)))
         (doc (and old-buf (buffer-local-value 'djvu-doc old-buf)))
         (old-bufs (and doc (mapcar 'buffer-live-p (djvu-buffers doc)))))
    ;; Sanity check.  We should never need this.
    (when (and old-bufs (memq nil old-bufs))
      (message "Killing dangling Djvu buffers...")
      (djvu-kill-doc doc)
      (setq doc nil old-bufs nil)
      (message "Killing dangling Djvu buffers...Done")
      (sit-for 2))
    ;; Do nothing if we are already visiting FILE such that all buffers
    ;; are properly defined and FILE's modtime matches what we expect.
    (unless (and old-bufs
                 (or (and (equal file-number
                                 (buffer-local-value 'buffer-file-number doc))
                          (verify-visited-file-modtime doc))
                     ;; If a file on disk and a Djvu session are out of sync,
                     ;; we can only continue in hairy, limited ways because
                     ;; Emacs does not copy the contents of FILE into a buffer.
                     ;; Instead, we entirely rely on djvused.
                     (not (or noconfirm
                              (yes-or-no-p
                               (format "Revert buffer from file %s? "
                                       (djvu-ref file doc)))))))
      (unless old-bufs
        (cl-flet ((fun (n)
                       ;; Instead of `generate-new-buffer', we take a detour
                       ;; via `create-file-buffer' so that uniquify can do
                       ;; its job, too.  It does not matter that the arg of
                       ;; `create-file-buffer' does not match `buffer-file-name'
                       ;; because `uniquify-buffer-file-name' only cares
                       ;; about DIR.
                       (create-file-buffer ; needed by uniquify
                        (expand-file-name
                         (concat buf-basename
                                 (nth n djvu-buffer-name-extensions))
                         dir))))
          (if old-buf
              ;; This applies if `find-file-noselect' created OLD-BUF
              ;; in order to visit FILE.  Hence recycle OLD-BUF as Read
              ;; buffer so that `find-file-noselect' can do its job.
              ;; FIXME: this ignores `djvu-buffer-name-extensions'
              ;; because renaming OLD-BUF would break `uniquify'.
              (with-current-buffer old-buf
                (let ((inhibit-read-only t)
                      (buffer-undo-list t))
                  (erase-buffer))
                (setq buffer-file-coding-system 'prefer-utf-8)
                (setq doc old-buf))
            (setq doc (fun 0)))
          (djvu-set read-buf doc doc)
          (djvu-set text-buf (fun 1) doc)
          (djvu-set annot-buf (fun 2) doc)
          (djvu-set shared-buf (fun 3) doc)
          (djvu-set bookmarks-buf (fun 4) doc)
          (djvu-set outline-buf (fun 5) doc)))
      ;; Of course, we have
      ;; `djvu-doc-read-buf' = `djvu-doc'
      ;; `djvu-doc-file' = `buffer-file-name'.  Bother?
      ;; It seems Emacs does not like aliases for buffer-local variables.
      (djvu-set file file doc)
      ;; We could set the resolve-url flag heuristically, if the Djvu file
      ;; happens to have bookmarks or internal urls on the current page.
      ;; (djvu-set resolve-url nil doc)

      ;; (Re-)Initialize all buffers.
      (with-current-buffer (djvu-ref read-buf doc)
        (djvu-read-mode))
      (with-current-buffer (djvu-ref outline-buf doc)
        (djvu-outline-mode))
      (with-current-buffer (djvu-ref text-buf doc)
        (djvu-script-mode)
        (setq djvu-buffer 'text))
      (with-current-buffer (djvu-ref annot-buf doc)
        (djvu-script-mode)
        (setq djvu-buffer 'annot
              header-line-format '(:eval (djvu-header-line "page annotations"))))
      (with-current-buffer (djvu-ref shared-buf doc)
        (djvu-script-mode)
        (setq djvu-buffer 'shared
              header-line-format '(:eval (djvu-header-line "shared annotations"))))
      (with-current-buffer (djvu-ref bookmarks-buf doc)
        (djvu-script-mode)
        (setq djvu-buffer 'bookmarks
              header-line-format '(:eval (djvu-header-line "bookmarks"))))
      (djvu-all-buffers doc
        (setq djvu-doc doc ; propagate DOC to all buffers
              buffer-file-name file
              ;; A non-nil value of `buffer-file-truename' enables file-locking,
              ;; see call of `lock_file' in `prepare_to_modify_buffer_1'
              buffer-file-truename file-truename
              buffer-file-number file-number
              buffer-file-read-only read-only
              ;; We assume that all buffers for a Djvu document have the same
              ;; read-only status.  Should we allow different values for the
              ;; buffers of one document?  Or do we need a `djvu-read-only-mode'?
              buffer-read-only read-only
              default-directory dir)
        (set-visited-file-modtime)
        (add-hook 'post-command-hook 'djvu-modified nil t)
        (add-hook 'kill-buffer-hook 'djvu-kill-doc-all nil t))

      (with-temp-buffer
        (djvu-djvused doc t "-e"
                      "create-shared-ant; print-ant; n; ls; print-outline;")
        (goto-char (point-min))

        ;; shared annotations
        (save-restriction
          (narrow-to-region
           (point)
           ;; There is no delimiter in between the output strings
           ;; of multiple djvused commands indicating something like
           ;; the last shared annotation.
           ;; So we simply rely on the fact that annotations have a
           ;; parsable lisp-like syntax surrounded by braces,
           ;; whereas the next djvused command is `n', the output
           ;; of which is a plain number.
           (save-excursion
             (while (progn (skip-chars-forward " \t\n")
                           (looking-at "("))
               (forward-sexp))
             (point)))
          (djvu-init-annot (djvu-ref shared-buf doc) doc t))

        ;; page max
        (djvu-set pagemax (read (current-buffer)) doc)

        ;; page id:
        ;; The output lines of djvused -e "ls;" consists of several parts
        (let ((regexp (concat "\\(?:\\([0-9]+\\)[ \t]+\\)?" ; page number
                              "\\([PIAT]\\)[ \t]+"          ; file identifier
                              "\\([0-9]+\\)[ \t]+"          ; file size
                              ;; We have a problem when parsing the
                              ;; component file name followed by the optional
                              ;; page title: there is no unambiguous separator
                              ;; in between the two.  Note that the component
                              ;; file name may contain whitespace characters
                              ;; and its file name extension is not unique
                              ;; (if present at all).
                              "\\([^=\n]+\\)"
                              "\\(?:[ \t]+T=[^\t\n]+\\)?"  ; title (optional)
                              "$")) ; match a single line
              page-id)
          (while (progn (skip-chars-forward " \t\n")
                        (looking-at regexp))
            (if (match-string 1)
                ;; page-id is an alist with elements (PAGE-NUM . FILE-ID).
                ;; The remainder of the code assumes that djvused sets up
                ;; this association list properly.
                (push (cons (djvu-match-number 1)
                            (match-string 4))
                      page-id))
            (goto-char (match-end 0)))
          (unless (eq (djvu-ref pagemax doc) (length page-id))
            (error "Page id list broken %s - %s"
                   (djvu-ref pagemax doc) (length page-id)))
          (djvu-set page-id (nreverse page-id) doc))

        ;; bookmarks
        (skip-chars-forward " \t\n")
        (when (looking-at "(bookmarks")
          (let ((object (read (current-buffer))))
            (with-current-buffer (djvu-ref bookmarks-buf doc)
              (let (buffer-read-only)
                (insert "(bookmarks")
                (djvu-insert-bookmarks (cdr object) " ")
                (insert ")\n")
                (goto-char (point-min))
                (set-buffer-modified-p nil)
                (setq buffer-undo-list nil)))
            (djvu-init-outline (cdr object) doc))))

      (djvu-init-page page doc))

    (if view (djvu-view doc))
    (unless noselect (switch-to-buffer (djvu-ref read-buf doc)))
    (djvu-ref read-buf doc)))

(defun djvu-revert-buffer (&optional _ignore-auto noconfirm _preserve-modes)
  "Revert buffers for the current Djvu document.
Note: Djvu mode never visits the Djvu document in the usual Emacs sense of
copying the contents of the file into a buffer to manipulate it.  Instead,
djvu mode completely relies on djvused and the file on disk.  Therefore,
we are in trouble if the file on disk happens to be not in sync anymore
with what Djvu mode believes it is.  Reverting the buffers for the Djvu
document is usually the only way out."
  (interactive)
  (unless djvu-doc (user-error "No djvu-doc"))
  ;; Force reversal.  Is there a better way to achieve this?
  ;; Emacs will ask a few questions if some buffers are modified.
  (with-current-buffer djvu-doc
    (setq buffer-file-number nil))
  (djvu-find-file (djvu-ref file djvu-doc)
                  (djvu-ref page djvu-doc) nil nil noconfirm))

(defun djvu-init-page (&optional page doc)
  "Initialize PAGE for Djvu DOC.
PAGE is re-initialized if we are already viewing it."
  (interactive (list (djvu-read-page)))
  (unless doc (setq doc djvu-doc))
  ;; No need to save if only the bookmarks buffer
  ;; or shared annotations buffer got modified.
  (if (or (buffer-modified-p (djvu-ref text-buf doc))
          (buffer-modified-p (djvu-ref annot-buf doc)))
      (djvu-save doc t))
  ;; We process PAGE unconditionally, even if it equals the page
  ;; currently displayed.  Most often, PAGE equals the current page
  ;; if we want to redisplay PAGE.
  (unless (integerp page)
    (setq page (or (djvu-ref page doc) 1)))
  (if (or (< page 1)
          (< (djvu-ref pagemax doc) page))
      (user-error "Page `%s' out of range" page))

  (let ((inhibit-quit t))
    (if (and (djvu-ref page doc)
             (not (equal page (djvu-ref page doc))))
        (djvu-set history-backward (cons (djvu-ref page doc)
                                         (djvu-ref history-backward doc))
                  doc))
    (djvu-set history-forward nil doc)
    (djvu-set page page doc)
    ;; Fix me: Restore buffer positions if we revisit the same page.
    (djvu-set read-pos nil doc)
    (with-temp-buffer
      (djvu-djvused doc t "-e"
                    (format "select %d; size; print-txt; print-ant;"
                            (djvu-ref page doc)))
      (goto-char (point-min))

      ;; page size
      (skip-chars-forward " \t\n")
      (if (looking-at "width=\\([[:digit:]]+\\)[ \t]+height=\\([[:digit:]]+\\)\\(?:[ \t]+rotation=\\([[:digit:]]+\\)\\)?$")
          (djvu-set pagesize (cons (djvu-match-number 1)
                                   (djvu-match-number 2))
                    doc)
        ;; This may fail if the file list we read previously contained
        ;; thumbnails.  We should really ignore these thumbnails.
        (error "No page size"))

      ;; Raw text:
      ;; This is exactly one object that we can swallow in one bite.
      ;; Hence we do this before we swallow the unknown number of annotations.
      (goto-char (match-end 0))
      (skip-chars-forward " \t\n")
      (let ((object (if (looking-at "(\\(page\\|column\\|region\\|para\\|line\\|word\\|char\\)")
                        (read (current-buffer)))))
        ;; Set up annotations buffer.
        ;; This also initializes `djvu-doc-rect-list' that we need
        ;; for propertizing the read buffer.
        (save-restriction
          (narrow-to-region (point) (point-max))
          (djvu-init-annot (djvu-ref annot-buf doc) doc))

        ;; Set up text buffer
        (djvu-init-text object doc t)

        ;; Set up read buffer
        (djvu-init-read object doc t)))))

(defalias 'djvu-goto-page 'djvu-init-page
  "Goto PAGE of Djvu document DOC.")

(defsubst djvu-unresolve-url (url)
  "Unresolve internal URL.
This issues a warning message if URL cannot be resolved.
Yet it does not throw an error that would put the Djvu document
into an undefined state."
  (message "Warning: Page id `%s' broken" url)
  (sit-for 1)
  url)

(defun djvu-resolve-url (url &optional doc)
  "Resolve internal URLs.  See variable `djvu-resolve-url'."
  (cond ((eq 'long djvu-resolve-url)
         ;; Replace page number by file id
         (cond ((string-match "\\`#[0-9]+\\'" url)
                (let ((page-id (assq (djvu-substring-number url 1)
                                     (djvu-ref page-id doc))))
                  (if page-id
                      (format "#%s" (cdr page-id))
                    (djvu-unresolve-url url))))
               ((string-match "\\`#" url)
                (if (rassoc (substring-no-properties url 1)
                            (djvu-ref page-id doc))
                    url
                  (djvu-unresolve-url url)))
               (t url))) ; some other URL
        ((eq 'short djvu-resolve-url)
         ;; Replace file id by page number
         (cond ((string-match "\\`#[0-9]+\\'" url)
                (if (assq (djvu-substring-number url 1)
                          (djvu-ref page-id doc))
                    url
                  (djvu-unresolve-url url)))
               ((string-match "\\`#" url)
                (let ((page-id (rassoc (substring-no-properties url 1)
                                       (djvu-ref page-id doc))))
                  (if page-id
                      (format "#%d" (car page-id))
                    (djvu-unresolve-url url))))
               (t url))) ; some other URL
        (t ; check whether URL can be resolved
         (cond ((string-match "\\`#[0-9]+\\'" url)
                (if (assq (djvu-substring-number url 1)
                          (djvu-ref page-id doc))
                    url
                  (djvu-unresolve-url url)))
               ((string-match "\\`#" url)
                (if (rassoc (substring-no-properties url 1)
                            (djvu-ref page-id doc))
                    url
                  (djvu-unresolve-url url)))
               (t url))))) ; some other URL

(defun djvu-resolve-all-urls (dir &optional doc)
  "Resolve all internal URLs in Djvu document DOC."
  (interactive
   (list (intern (completing-read "Direction: " '((long) (short)) nil t))))
  (unless doc (setq doc djvu-doc))
  (djvu-save doc t)
  (unless (eq dir (djvu-ref resolve-url doc))
    (if (djvu-modified) (user-error "Djvu file should be saved"))
    ;; Resolve annotations
    (with-temp-buffer
      (let ((page-id (djvu-ref page-id doc))
            (djvu-resolve-url dir))
        (djvu-annot-script doc t)
        (goto-char (point-min))
        ;; The following regexp ignores external URLs
        ;; which do not start with "#".
        (while (re-search-forward "^(maparea[ \t]+\"#\\(\\([0-9]+\\)\\|[^\"]*[^0-9\"][^\"]*\\)\"" nil t)
          (let* ((url (match-string 1))
                 (num (and (match-string 2)
                           (djvu-match-number 2)))
                 repl)
            (cond ((eq dir 'long)
                   (if num
                       (if (setq repl (cdr (assq num page-id)))
                           (replace-match repl nil nil nil 1)
                         (djvu-unresolve-url url))
                     ;; We already have a long url
                     (unless (rassoc url page-id)
                       (djvu-unresolve-url url))))

                  ;; (eq dir 'short)
                  (num
                   ;; We already have a short url
                   (unless (assq num page-id)
                     (djvu-unresolve-url url)))
                  ((setq repl (car (rassoc url page-id)))
                   (replace-match (number-to-string repl) nil nil nil 1))
                  (t (djvu-unresolve-url url)))))
        (djvu-process-script doc t)))

    ;; update internal URLs of current page
    (with-temp-buffer
      (djvu-djvused doc t "-e"
                    (format "select %d; print-ant;" (djvu-ref page doc)))
      (djvu-init-annot (djvu-ref annot-buf doc) doc))

    ;; Resolve bookmarks
    (let ((object (djvu-read-bookmarks doc))
          (djvu-resolve-url dir))
      (when object
        (with-current-buffer (djvu-ref bookmarks-buf doc)
          (erase-buffer)
          (insert "(bookmarks")
          (djvu-insert-bookmarks (cdr object) " ")
          (insert ")\n"))
        (djvu-save doc)))
    (djvu-set resolve-url dir doc)))

(defun djvu-area (area &optional back)
  "Convert (area xmin ymin width height) to (area xmin ymin xmax ymax).
If BACK is non-nil do inverse transformation."
  (if back
      (let ((lst (list (nth 0 area) (nth 1 area) (nth 2 area)
                       (- (nth 3 area) (nth 1 area))
                       (- (nth 4 area) (nth 2 area)))))
        ;; Only for back transforms we might get an error...
        (if (or (> 0 (nth 3 lst)) (> 0 (nth 4 lst)))
            (message "Annotation area dimensions %s, %s"
                     (nth 3 lst) (nth 4 lst)))
        lst)
    (list (nth 0 area) (nth 1 area) (nth 2 area)
          (+ (nth 3 area) (nth 1 area))
          (+ (nth 4 area) (nth 2 area)))))

(defun djvu-view (&optional doc new)
  "(Re)Start Djview for DOC.
If prefix NEW is non-nil, always create a new Djview process."
  (interactive (list nil current-prefix-arg))
  (if (not (display-graphic-p))
      (message "No graphic display available")
    (let* ((doc (or doc djvu-doc)) ; needed by process-sentinel
           (dpos (djvu-mean-dpos (djvu-read-dpos nil doc)))
           (px (/ (float (nth 0 dpos))
                  (float (car (djvu-ref pagesize doc)))))
           (py (- 1 (/ (float (nth 1 dpos))
                       (float (cdr (djvu-ref pagesize doc))))))
           process-connection-type)  ; Use a pipe.
      (if (or (< px 0) (< 1 px) (< py 0) (< 1 py))
          (error "px=%s, py=%s out of range" px py))
      (unless new (djvu-kill-view doc))
      (let ((process (apply 'start-process
                    "djview" nil djvu-djview-command
                    (format "-page=%s" (cdr (assq (djvu-ref page doc)
                                                  (djvu-ref page-id doc))))
                    (format "-showposition=%06f,%06f" px py)
                    (append djvu-djview-options (list (djvu-ref file doc))))))
        (set-process-sentinel
         process
         `(lambda (process event)
            (when (string-match "^\\(?:finished\\|exited\\|quit\\|killed\\|terminated\\)" event)
              ;; This code runs asynchronously.  The buffer DOC need not
              ;; be alive anymore when we run `djvu-ref' and `djvu-set'.
              (if (buffer-live-p ,doc)
                  (djvu-set view-proc (delq process (djvu-ref view-proc ,doc))
                            ,doc))
              (message "%s %s: %s" process
                       ,(abbreviate-file-name (djvu-ref file doc))
                       event))))
        (djvu-set view-proc (cons process (djvu-ref view-proc doc)) doc)))))

(defun djvu-view-page (page &optional doc new)
  "(Re)Start Djview on PAGE for DOC.
If prefix NEW is non-nil, always create a new Djview process."
  (interactive (list (if (eq 'outline djvu-buffer)
                         (djvu-outline-page)
                       (djvu-read-page))
                     nil current-prefix-arg))
  (djvu-goto-page page doc)
  (djvu-view doc new))

;;; Djvu Text mode

(defvar djvu-last-search-re nil
  "Last regexp used by `djvu-re-search-forward'.")

(defun djvu-re-search-forward (regexp)
  "Search forward for match for REGEXP.

Search case-sensitivity is determined by the value of the variable
`case-fold-search', which see.

The command `djvu-re-search-forward-continue' continues to search forward."
  (interactive "sSearch (regexp): ")
  (setq djvu-last-search-re regexp)
  (let ((doc djvu-doc))
    (while (not (or (re-search-forward regexp nil t)
                    (eq (djvu-ref page doc) (djvu-ref pagemax doc))))
      (djvu-next-page 1))))

(defun djvu-re-search-forward-continue ()
  "Continue search forward for match for `djvu-last-search-re'."
  (interactive)
  (djvu-re-search-forward djvu-last-search-re))

;; Fixme: New command `djvu-ispell-word' available in the read buffer.
;; To avoid re-inventing the wheel, this command should inherit some
;; functionality from `ispell-word'.  Unfortunately, the latter is a rather
;; monolithic function, making it difficult to adapt ispell to our needs.

(defun djvu-edit-word (bpos)
  "Edit word at buffer position BPOS."
  (interactive "d")
  (let* ((old (buffer-substring-no-properties
               (djvu-property-beg bpos 'word)
               (djvu-property-end bpos 'word)))
         (new (read-string (format "Replace `%s' with: " old) old
                           nil nil djvu-inherit-input-method))
         (dpos (djvu-read-dpos bpos)))
    (with-current-buffer (djvu-ref text-buf)
      ;; As we operate in the raw text buffer, we need to translate
      ;; OLD and NEW into the raw format using `prin1-to-string'.
      (unless (and (djvu-goto-dpos 'word dpos)
                   (progn
                     ;; `djvu-goto-dpos' puts us past the first quote
                     ;; Yet we want to replace this quote, too.
                     (backward-char)
                     (looking-at (regexp-quote (prin1-to-string old)))))
        (error "`%s' not found" old))
      (replace-match (prin1-to-string new) t t)))
  (djvu-save-text))

(defun djvu-split-word (bpos)
  "Split word at buffer position BPOS.
This command operates on the read buffer."
  (interactive "d")
  (let ((beg (djvu-property-beg bpos 'word))
        (dpos (djvu-read-dpos bpos)))
    (with-current-buffer (djvu-ref text-buf)
      (djvu-split-word-internal (djvu-goto-dpos 'word dpos)
                                (- bpos beg))))
  (djvu-save-text))

(defun djvu-split-word-internal (wpos split)
  "Split word at position WPOS at character position SPLIT.
This command operates on the text buffer."
  (interactive
   (let* ((pnt (point))
          (pps (parse-partial-sexp (line-beginning-position) pnt)))
     (unless (nth 3 pps) (user-error "Point not inside string"))
     (list pnt (1- (- pnt (nth 8 pps))))))
  (goto-char wpos)
  (beginning-of-line)
  (skip-chars-forward " \t")
  (setq wpos (point))
  (let ((indent (buffer-substring-no-properties
                 (line-beginning-position) wpos))
        word)
    (condition-case nil
        (progn
          (setq word (read (current-buffer)))
          (unless (eq 'word (car word)) (error "Invalid")))
      (error (error "Syntax error in raw text")))
    (if (or (< split 1) (<= (length (nth 5 word)) split))
        (error "Nothing to split"))
    (delete-region wpos (point))
    ;; To split the bounding box horizontally, we take the fraction
    ;; of the number of characters in each fragment.  This scheme
    ;; is only approximate, but it is better than nothing.
    (let ((frac (round (* (/ (float split) (length (nth 5 word)))
                          (- (nth 3 word) (nth 1 word))))))
      (djvu-insert-text (list 'word (nth 1 word) (nth 2 word)
                              (+ (nth 1 word) frac) (nth 4 word)
                              (substring (nth 5 word) 0 split)) "")
      (insert "\n" indent)
      (djvu-insert-text (list 'word (+ (nth 1 word) frac 1) (nth 2 word)
                              (nth 3 word) (nth 4 word)
                              (substring (nth 5 word) split)) ""))))

(defun djvu-merge-words (beg end)
  "Merge words between positions BEG and END.
This command operates on the read buffer."
  (interactive "r")
  (let ((bpos (djvu-read-dpos beg))
        (epos (djvu-read-dpos (1- end))))
    (with-current-buffer (djvu-ref text-buf)
      (djvu-merge-words-internal (djvu-goto-dpos 'word bpos)
                                 (djvu-goto-dpos 'word epos))))
  (djvu-save-text))

(defun djvu-merge-words-internal (beg end)
  "Merge words between positions BEG and END.
This command operates on the text buffer."
  (interactive "r")
  (let (words)
    (goto-char end)
    (if (bolp) (setq end (1- end)))
    (goto-char beg)
    (beginning-of-line)
    (skip-chars-forward " \t")
    (setq beg (point))
    (while (< (point) end)
      (push (read (current-buffer)) words)
      (unless (eq 'word (caar words))
        (error "Syntax error in raw text")))
    (delete-region beg (point))
    (let ((object (apply 'list 'word 0 0 0 0 (nreverse words))))
      (djvu-text-zone object 0 (make-vector 3 nil))
      (setcdr (nthcdr 4 object) (list (mapconcat (lambda (w) (nth 5 w))
                                                 (nthcdr 5 object) "")))
      (djvu-insert-text object "")))
  (undo-boundary))

(defun djvu-merge-lines (beg end)
  "Merge lines between positions BEG and END.
This command operates on the read buffer."
  (interactive "r")
  ;; Sometimes we have bounding boxes that are screwed up (e.g., a bbox
  ;; for BEG that even includes END).  Then the following fails and we can
  ;; merely run `djvu-merge-lines-internal' in the text buffer.
  (let ((bpos (djvu-read-dpos beg))
        (epos (djvu-read-dpos (1- end))))
    (with-current-buffer (djvu-ref text-buf)
      (djvu-merge-lines-internal (djvu-goto-dpos 'word bpos)
                                 (djvu-goto-dpos 'word epos))))
  (djvu-save-text))

(defun djvu-merge-lines-internal (beg end)
  "Merge lines between positions BEG and END.
This command operates on the text buffer."
  (interactive "r")
  ;; Calculate proper value of END
  (goto-char end)
  (unless (looking-at "[ \t]*(word ")
    (re-search-backward "^[ \t]*(word "))
  (forward-sexp)
  (setq end (point))
  ;; Calculate proper value of BEG
  (goto-char beg)
  (unless (looking-at "[ \t]*(word ")
    (re-search-backward "^[ \t]*(word "))
  (skip-chars-forward " \t")
  (setq beg (point))
  (unless (< beg end) (user-error "Nothing to merge"))
  ;; The following fails if the zone levels of the lines we want to merge
  ;; are different.  For example:
  ;; (line X X X X
  ;;  (word X X X X string)
  ;;  (word X X X X string))
  ;; (para X X X X
  ;;  (line X X X X
  ;;   (word X X X X string)
  ;;   (word X X X X string)))
  (atomic-change-group
    (save-restriction
      (narrow-to-region beg end)
      (mapc (lambda (zone)
              (goto-char (point-min))
              (let ((re (format ")[\n\t\s]+(%s [0-9]+ [0-9]+ [0-9]+ [0-9]+" zone)))
                (while (re-search-forward re nil t)
                  (replace-match ""))))
            '("column" "region" "para" "line"))
      ;; Check that we got what we want.
      (goto-char (point-min))
      (while (> (point-max) (progn (skip-chars-forward "\n\t\s") (point)))
        (if (looking-at "(word ")
            (forward-sexp) ; may signal `scan-error'
          (error "Syntax error: cannot merge"))))))

(defun djvu-init-text (object &optional doc reset)
  "Initialize Text buffer."
  (with-current-buffer (djvu-ref text-buf doc)
    (let ((dpos (unless reset (djvu-text-dpos nil doc)))
          buffer-read-only)
      (erase-buffer)
      (djvu-insert-text object "")
      (insert "\n")
      (if (not reset)
          (djvu-goto-dpos 'word dpos)
        (goto-char (point-min))
        (set-buffer-modified-p nil)
        (setq buffer-undo-list nil)))))

(defun djvu-insert-text (object indent)
  "Insert OBJECT into Djvu text buffer recursively using indentation INDENT."
  (when object
    (insert indent "("
            (mapconcat 'prin1-to-string
                       (list (nth 0 object) (nth 1 object) (nth 2 object)
                             (nth 3 object) (nth 4 object)) " "))
    (let ((tail (nthcdr 5 object))
          (indent (concat indent " ")))
      (if (stringp (car tail))
          (insert (format " %S)" (car tail)))
        (dolist (elt tail)
          (insert "\n")
          (djvu-insert-text elt indent))
        (insert ")")))))

(defvar djvu-zone-re
  (concat "[ \t]*(\\("
          (regexp-opt '("page" "column" "region" "para" "line"
                        "word" "char"))
          "\\)[ \t]+\\([0-9]+\\)[ \t]+\\([0-9]+\\)"
             "[ \t]+\\([0-9]+\\)[ \t]+\\([0-9]+\\)[ \t\n]+")
  "Regexp matching the beginning of a Djvu text zone.")

(defun djvu-text-dpos (&optional point doc)
  "Return Djvu position of POINT in Djvu text buffer."
  (with-current-buffer (djvu-ref text-buf doc)
    (save-excursion
      (if point (goto-char point))
      (beginning-of-line)
      (let (zone)
        (while (not (or (setq zone (looking-at djvu-zone-re))
                        (bobp)))
          (forward-line -1))
        (if zone
            (mapcar 'djvu-match-number '(2 3 4 5)))))))

(defun djvu-read-text (&optional doc)
  "Read text of a Djvu document from text buffer."
  (let (object)
    (with-current-buffer (djvu-ref text-buf doc)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (unless (eobp)
            (condition-case nil
                (setq object (read (current-buffer)))
              (error (error "Syntax error in raw text")))
            (skip-chars-forward " \t\n")
            ;; We should have swallowed all raw text.
            (unless (eobp)
              (error "Syntax error in raw text (end of buffer)"))))))
    object))

(defun djvu-save-text (&optional doc script)
  "Save text of the Djvu document DOC.  This updates the Read buffer for DOC.
DOC defaults to the current Djvu document.
If SCRIPT is non-nil, dump the text buffer into the djvused script file SCRIPT."
  (interactive)
  (unless doc (setq doc djvu-doc))
  (let ((object1 (djvu-read-text doc))
        (object2 (djvu-read-text doc))) ; true recursive copy of OBJECT1
    ;; Re-initializing the text buffer blows up the undo list of this buffer.
    ;; This step is only needed if we changed the text zones (e.g., when
    ;; merging lines).  So we check whether `djvu-text-zone' has changed
    ;; OBJECT.  For this, it is easier to read OBJECT twice than copying it
    ;; recursively.
    (djvu-text-zone object1 0 (make-vector 7 nil))
    (unless (equal object1 object2)
      (djvu-init-text object1 doc))
    ;; Update read buffer.  We do this even if the text buffer is not
    ;; modified, as we may have undone a change in the text buffer that
    ;; previously propagated also into the read buffer.  The Read buffer
    ;; has no undo list.
    (djvu-init-read object1 doc)
    ;; It is a bit of a hack to use this command for two rather different
    ;; purposes.  But we do not want to read OBJECT one more time.
    (if script
        (with-temp-buffer
          (setq buffer-file-coding-system 'utf-8)
          (insert (format "select %d\nremove-txt\nset-txt\n"
                          (djvu-ref page doc)))
          (djvu-insert-text object1 "")
          (insert "\n.\n") ; see djvused command set-txt
          (write-region nil nil script t 0))))) ; append to SCRIPT

(defun djvu-text-zone (object depth zones)
  "Evaluate zones for text OBJECT recursively."
  (cond ((stringp (nth 5 object))
         (aset zones depth (vector (nth 1 object) (nth 2 object)
                                   (nth 3 object) (nth 4 object))))
        (object
         (let ((depth1 (1+ depth))
               zone)
           (aset zones depth nil)
           (dolist (elt (nthcdr 5 object))
             (djvu-text-zone elt depth1 zones)
             (if (setq zone (aref zones depth))
                 (let ((zone1 (aref zones depth1)))
                   (aset zone 0 (min (aref zone 0) (aref zone1 0)))
                   (aset zone 1 (min (aref zone 1) (aref zone1 1)))
                   (aset zone 2 (max (aref zone 2) (aref zone1 2)))
                   (aset zone 3 (max (aref zone 3) (aref zone1 3))))
               (aset zones depth (copy-sequence (aref zones depth1)))))
           (if (setq zone (aref zones depth))
               (setcdr object (apply 'list (aref zone 0) (aref zone 1)
                                     (aref zone 2) (aref zone 3)
                                     (nthcdr 5 object)))
             (error "No zone??"))))))

(defun djvu-script-buffer (buffer)
  "Return buffer for djvu script.
t means current buffer, nil means `djvu-script-buffer'."
  (if (eq t buffer)
      (current-buffer)
    (get-buffer-create (or buffer djvu-script-buffer))))

(defun djvu-text-script (&optional doc buffer page display)
  "Create djvused script for complete text layer of DOC in BUFFER.
If prefix PAGE is non-nil create instead script for only page PAGE.
BUFFER defaults to `djvu-script-buffer'.  If BUFFER is t use current buffer.

You can edit the text script in BUFFER.  Afterwards you can re-apply
this script using `djvu-process-script'.  This code will not (cannot) check
whether the edited script is meaningful for DOC.  Use at your own risk.
You get what you want."
  (interactive (list nil nil (if current-prefix-arg (djvu-ref page)) t))
  (let ((doc (or doc djvu-doc))
        (buffer (djvu-script-buffer buffer)))
    (djvu-save doc t)
    ;; Put this in a separate buffer!
    (with-current-buffer buffer
      (let ((buffer-undo-list t)
            buffer-read-only)
        (djvu-script-mode)
        (erase-buffer)
        ;; Always create a self-contained djvused script.
        (if page (insert (format "select \"%s\" # page %d\n"
                                 (cdr (assq page (djvu-ref page-id doc)))
                                 page)))
        (djvu-djvused doc t "-e" (format "select %s; output-txt;"
                                         (or page "")))
        (goto-char (point-min)))
      (set-buffer-modified-p nil)
      (setq buffer-undo-list nil))
    (if display (switch-to-buffer buffer))))

(defun djvu-process-script (&optional doc buffer obey-restrictions)
  "For Djvu document DOC apply the djvused script in BUFFER.
Use at your own risk.  You get what you want.  This code does not (cannot)
check whether the script is meaningful.  Unless prefix OBEY-RESTRICTIONS
is non-nil, throw an error if BUFFER is narrowed.
DOC defaults to the current Djvu document.
BUFFER defaults to `djvu-script-buffer'.  If BUFFER is t, use current buffer."
  (interactive (list nil nil current-prefix-arg))
  (let ((doc (or doc djvu-doc)))
    (unless doc (user-error "No Djvu doc"))
    (djvu-save doc t)
    (djvu-with-temp-file script
      (with-current-buffer (djvu-script-buffer buffer)
        ;; If BUFFER is narrowed, we process only this part.
        (unless (or obey-restrictions
                    (equal (save-restriction ; not narrowed
                             (widen)
                             (- (point-max) (point-min)))
                           (- (point-max) (point-min))))
          (user-error "Script buffer narrowed"))
        (let ((buffer-file-coding-system 'utf-8))
          (write-region nil nil script nil 0)))
      (djvu-djvused doc nil "-f" script "-s"))
    ;; Redisplay
    (djvu-init-page nil doc)))

;;; Djvu Read mode

(defun djvu-init-read (object &optional doc reset)
  (with-current-buffer (djvu-ref read-buf doc)
    (let ((djvu-rect-list (djvu-ref rect-list doc))
          (dpos (unless reset (djvu-read-dpos nil doc)))
          buffer-read-only djvu-last-rect)
      (erase-buffer)
      (djvu-insert-read object)
      (djvu-insert-read-prop)
      (if reset
          (goto-char (point-min))
        (djvu-goto-read dpos)))
    (set-buffer-modified-p nil)
    (setq buffer-read-only t)
    (djvu-image)))

(defun djvu-insert-read (object)
  "Display text OBJECT recursively."
  (let ((opoint (point))
        (tail (nthcdr 5 object)))
    (if (stringp (car tail))
        (progn
          (insert (car tail))
          ;; Propertize the read buffer according to `djvu-rect-list'
          (if djvu-rect-list
              (let (;; Try last rect first.
                    (rect-list (if djvu-last-rect
                                   (cons (nthcdr 2 djvu-last-rect) djvu-rect-list)
                                 djvu-rect-list))
                    ;; Center position of current object
                    (x (/ (+ (nth 1 object) (nth 3 object)) 2))
                    (y (/ (+ (nth 2 object) (nth 4 object)) 2))
                    rect coords found)
                (while (setq rect (pop rect-list))
                  (setq coords (car rect))
                  (when (and (< (nth 0 coords) x (nth 2 coords))
                             (< (nth 1 coords) y (nth 3 coords)))
                    (setq rect-list nil found t)
                    (if (equal (cdr rect) (nthcdr 3 djvu-last-rect))
                        (setq djvu-last-rect
                              (cons (car djvu-last-rect) (cons (point) rect)))
                      (djvu-insert-read-prop)
                      (setq djvu-last-rect
                            (cons opoint (cons (point) rect))))))
                (unless found
                  (djvu-insert-read-prop)))))
      (let* ((obj (caar tail))
             (sep (cond ((eq 'line obj) "\n")
                        ((eq 'word obj) "\s")
                        ((eq 'char obj) nil)
                        (t "\n\n")))
             elt)
        (while (setq elt (pop tail))
          (djvu-insert-read elt)
          (if (and sep tail) (insert sep)))))
    (put-text-property opoint (point) (car object)
                       (vector (nth 1 object) (nth 2 object)
                               (nth 3 object) (nth 4 object)))))

(defun djvu-insert-read-prop ()
  "Propertize Read buffer according to annotations."
  (when djvu-last-rect
    (let ((beg (nth 0 djvu-last-rect))
          (end (nth 1 djvu-last-rect))
          (face `(face (:background ,(nth 5 djvu-last-rect))
                       help-echo ,(nth 4 djvu-last-rect))))
      (if (or (eq t djvu-read-prop-newline)
              (and (numberp djvu-read-prop-newline)
                   (save-excursion
                     (goto-char beg)
                     (re-search-forward "\n+" end t djvu-read-prop-newline))))
          (add-text-properties beg end face)
        (save-excursion
          (goto-char beg)
          (while (re-search-forward "[^\n]+" end t)
            (add-text-properties (match-beginning 0) (match-end 0) face))))
      (unless (equal "" (nth 3 djvu-last-rect))
        ;; Use `make-button' instead of `make-text-button' because a face
        ;; can hide a text button.
        (make-button beg end :type 'djvu-url
                     'help-echo (format "mouse-2, RET: url `%s'%s"
                                        (nth 3 djvu-last-rect)
                                        (if (equal "" (nth 4 djvu-last-rect))
                                            ""
                                          (format "\n%s" (nth 4 djvu-last-rect))))
                     'djvu-args (list (nth 3 djvu-last-rect)))))
    (setq djvu-last-rect nil)))

(defun djvu-read-dpos (&optional point doc)
  "Return Djvu position of POINT in Djvu Read buffer.
This is either a list (XMIN YMIN XMAX YMAX) or (X Y)."
  (with-current-buffer (djvu-ref read-buf doc)
    (cond ((and djvu-image-mode
                (djvu-ref read-pos doc)))
          ((= (point-min) (point-max))
           ;; An empty djvu page gives us something like (page 0 0 0 0 "")
           ;; Take the center of an empty page
           (list (/ (car (djvu-ref pagesize doc)) 2)
                 (/ (cdr (djvu-ref pagesize doc)) 2)))
          (t
           (unless point
             (setq point (point)))
           ;; Things get rather complicated if the text does not contain
           ;; separate words.
           (or (get-text-property point 'word)
               (and (< 1 point)
                    (get-text-property (1- point) 'word))
               ;; Search backward because more often
               ;; point is at the end of region we operated on
               (let ((pos (previous-single-property-change
                           point 'word)))
                 (and pos (get-text-property (1- pos) 'word)))
               (list (/ (car (djvu-ref pagesize doc)) 2)
                     (/ (cdr (djvu-ref pagesize doc)) 2)))))))

(defun djvu-mean-dpos (dpos)
  "For Djvu position DPOS return mean coordinates (X Y).
DPOS is a list or vector (XMIN YMIN XMAX YMAX)."
  (if (elt dpos 2)
      (list (/ (+ (elt dpos 0) (elt dpos 2)) 2)
            (/ (+ (elt dpos 1) (elt dpos 3)) 2))
    dpos))

(defsubst djvu-dist (width height)
  (+ (* width width) (* height height)))

(defun djvu-goto-dpos (object dpos)
  "Go to OBJECT at position DPOS in the text or annotation buffer.
If found, return corresponding buffer position.
Otherwise, do nothing and return nil."
  ;; This code relies on the fact that we have all coordinates
  ;; in the format (xmin ymin xmax ymax) instead of the format
  ;; (xmin ymin width height) used by djvused for maparea annotations.
  (cond ((not dpos) nil) ; DPOS is nil, do nothing, return nil

        ((elt dpos 2) ; DPOS is a list or vector (XMIN YMIN XMAX YMAX)
         (goto-char (point-min))
         (or (re-search-forward (format "\\<%s\\>[ \t\n]+%s\\([ \t\n]+\"\\)?"
                                        object
                                        (mapconcat 'number-to-string dpos
                                                   "[ \t\n]+"))
                                nil t)
             ;; try again, using the mean value of DPOS
             (djvu-goto-dpos object (djvu-mean-dpos dpos))))

        (t ; DPOS is a list (X Y)
         ;; Look for OBJECT with either
         ;; - DPOS inside OBJECT -> exact match
         ;; - OBJECT nearest to DPOS -> approximate match
         ;; The latter always succeeds.
         (let* ((re (format "\\<%s\\>[ \t\n]+%s\\([ \t\n]+\"\\)?"
                            object
                            (mapconcat 'identity
                                       (make-list 4 "\\([[:digit:]]+\\)")
                                       "[ \t\n]+")))
                (x (nth 0 dpos)) (y (nth 1 dpos))
                (x2 (- (* 2 x))) (y2 (- (* 2 y)))
                (good-dist (* 4 (djvu-dist (car (djvu-ref pagesize))
                                           (cdr (djvu-ref pagesize)))))
                (good-pnt (point-min))
                pnt dist)
           (goto-char (point-min))
           (while (and (not (zerop good-dist))
                       (setq pnt (re-search-forward re nil t)))
             (let ((xmin (djvu-match-number 1)) (ymin (djvu-match-number 2))
                   (xmax (djvu-match-number 3)) (ymax (djvu-match-number 4)))
               (if (and (<= xmin x xmax) (<= ymin y ymax))
                   (setq good-dist 0 good-pnt pnt) ; exact match
                 (setq dist (djvu-dist (+ xmin xmax x2) (+ ymin ymax y2)))
                 (if (< dist good-dist)
                     (setq good-pnt pnt good-dist dist))))) ; approximate match
           (goto-char good-pnt)
           (if (/= good-pnt (point-min)) good-pnt)))))

(defun djvu-goto-read (&optional dpos)
  "Go to buffer position in Read buffer corresponding to Djvu position DPOS.
Return corresponding buffer position."
  (with-current-buffer (djvu-ref read-buf)
    (cond (djvu-image-mode
           (djvu-set read-pos dpos)
           (point-min))
          ((not dpos) nil) ; DPOS is nil, do nothing, return nil

          ((elt dpos 2) ; DPOS is a list or vector (XMIN YMIN XMAX YMAX)
           ;; Go to the buffer position of the first word inside DPOS.
           (let ((pnt (point-min))
                 (xmin (elt dpos 0)) (ymin (elt dpos 1))
                 (xmax (elt dpos 2)) (ymax (elt dpos 3))
                 word done)
             (goto-char (point-min))
             (while (progn ; Do while
                      (setq done
                            (and (setq word (djvu-mean-dpos
                                             (get-text-property pnt 'word)))
                                 (<= xmin (nth 0 word) xmax)
                                 (<= ymin (nth 1 word) ymax)))
                      (and (not done)
                           (setq pnt (next-single-property-change pnt 'word)))))
             (if done
                 (goto-char pnt)
               ;; try again, using the mean value of DPOS
               (djvu-goto-read (djvu-mean-dpos dpos)))))

          (t ; DPOS is a list (X Y)
           ;; Look for word with either
           ;; - DPOS inside word -> exact match
           ;; - word nearest to DPOS -> approximate match
           ;; The latter always succeeds.
           (let* ((x (nth 0 dpos)) (y (nth 1 dpos))
                  (x2 (- (* 2 x))) (y2 (- (* 2 y)))
                  (good-dist (* 4 (djvu-dist (car (djvu-ref pagesize))
                                             (cdr (djvu-ref pagesize)))))
                  (pnt (point-min)) (good-pnt (point-min))
                  word dist)
             (goto-char (point-min))
             (while (progn ; Do while
                      (when (setq word (get-text-property pnt 'word))
                        (if (and (<= (aref word 0) x (aref word 2))
                                 (<= (aref word 1) y (aref word 3)))
                            (setq good-dist 0 good-pnt pnt) ; exact match
                          (setq dist (djvu-dist (+ (aref word 0) (aref word 2) x2)
                                                (+ (aref word 1) (aref word 3) y2)))
                          (if (< dist good-dist)
                              (setq good-pnt pnt good-dist dist)))) ; approximate match
                      (and (not (zerop good-dist))
                           (setq pnt (next-single-property-change pnt 'word)))))
             (goto-char good-pnt)
             (if (/= good-pnt (point-min)) good-pnt))))))

;;; Djvu Annotation mode

(defvar djvu-annot-re
  (concat "(" (regexp-opt '("background" "zoom" "mode" "align"
                            "maparea" "metadata" "xmp") t) "\\>"))

(defun djvu-init-annot (buf doc &optional shared)
  "Initialize Annotations buffer BUF of Djvu document DOC.
SHARED should be non-nil for a Shared Annotations buffer."
  (djvu-convert-hash)
  (goto-char (point-min))
  (let (object alist)
    (while (progn (skip-chars-forward " \t\n") (not (eobp)))
      (if (looking-at djvu-annot-re)
          (push (read (current-buffer)) object)
        (error "Unknown annotation `%s'" (buffer-substring-no-properties
                                          (point) (line-end-position)))))

    ;; To simplify the editing of annotations, identify rect mapareas
    ;; sharing the same text string.
    (dolist (elt object)
      (if (not (eq 'maparea (car elt)))
          (push elt alist)
        (cond ((memq (car (nth 3 elt)) '(rect oval)) ; rect and oval
               (let ((area (djvu-area (nth 3 elt)))
                     e)
                 ;; Remove area destructively.
                 (setcdr (nthcdr 2 elt) (nthcdr 4 elt))
                 ;; The new elements of alist are cons cells, where the car
                 ;; is the maparea without area, and the cdr is the list
                 ;; of areas.  Even if we have just an empty string,
                 ;; we still want to massage the area.
                 (if (or (string= "" (nth 2 elt))
                         (not (setq e (assoc elt alist))))
                     (push (cons elt (list area)) alist)
                   (setcdr e (cons area (cdr e))))))
              ((eq 'text (car (nth 3 elt))) ; text
               (setcar (nthcdr 3 elt) (djvu-area (nth 3 elt)))
               (push elt alist))
              (t (push elt alist)))))

    (unless shared
      (let ((id 0) rect-list)
        (dolist (elt alist)
          (when (consp (car elt)) ; maparea rect and oval
            (setq id (1+ id))
            (push (djvu-rect-elt elt id) rect-list)))
        (djvu-set rect-list (apply 'nconc rect-list) doc)))

    ;; Pretty print annotations.
    (with-current-buffer buf
      (let ((standard-output (current-buffer))
            buffer-read-only)
        (erase-buffer)
        (dolist (elt alist)
          (cond ((consp (car elt)) ; maparea with list of areas
                 (let ((c (car elt)))
                   (insert (format "(maparea %S\n %S\n ("
                                   (djvu-resolve-url (nth 1 c) doc) (nth 2 c))
                           (mapconcat 'prin1-to-string (cdr elt) "\n  ") ")\n " ; rect and oval
                           (mapconcat 'prin1-to-string (nthcdr 3 c) " ") ; rest
                           ")")))
                ((eq 'metadata (car elt)) ; metadata
                 (insert "(metadata")
                 (dolist (entry (cdr elt))
                   (insert (format "\n (%s %S)" (car entry) (cadr entry))))
                 (insert ")"))
                ((not (eq 'maparea (car elt))) ; no maparea
                 (prin1 elt))
                ((memq (car (nth 3 elt)) '(text line)) ; maparea text, line
                 (insert (format "(maparea %S\n %S\n " (nth 1 elt) (nth 2 elt))
                         (mapconcat 'prin1-to-string (nthcdr 3 elt) " ") ; rest
                         ")"))
                (t (error "Djvu maparea %s undefined" (car (nth 3 elt)))))
          (insert "\n\n"))
        (djvu-convert-hash t))
      (goto-char (point-min))
      (set-buffer-modified-p nil)
      (setq buffer-undo-list nil))))

(defun djvu-rect-elt (rect id)
  "For rect RECT define entry for `djvu-rect-list' using ID."
  (let* ((maparea (car rect))
         (url (nth 1 maparea))
         (text (nth 2 maparea))
         (color (djvu-color-background
                 (cond ((nth 1 (assoc 'hilite maparea))) ; Use color if possible.
                       (url djvu-color-url) ; we have a URL
                       (t djvu-color-highlight))
                 nil
                 (or (nth 1 (assoc 'opacity maparea))
                     djvu-opacity))))
    ;; If multiple annotations differ only in the AREAs, it is assumed
    ;; that they belong together, so that they are collapsed in the
    ;; annotations buffer and their text properties in the Read buffer
    ;; are merged across word boundaries.  This is usually OK when URL
    ;; and TEXT are non-empty strings.  But we do not collapse such entries
    ;; in the annotations buffer if URL and TEXT are empty strings.
    ;; To achieve the same with text properties in the Read buffer, we add
    ;; the extra element ID to the elements of `djvu-rect-list'.
    (mapcar (lambda (area)
              (list (cdr area) url text color id))
            (cdr rect))))

(defun djvu-font-lock-url (bound)
  (let ((pnt (point)) case-fold-search found beg end)
    (cond ((memq djvu-buffer '(annot shared))
           (beginning-of-line)
           (while (and (not found)
                       (re-search-forward "^[ \t]*(maparea" bound t))
             (setq found (and (looking-at "[ \t]*\"")
                              (progn
                                (setq beg (match-end 0))
                                (>= beg pnt))
                              (<= beg bound)
                              (progn
                                (forward-sexp)
                                (setq end (1- (point))))))))
          ((eq djvu-buffer 'bookmarks)
           (re-search-backward "^[ \t]*(" nil t)
           (while (and (not found)
                       (re-search-forward "^[ \t]*(" bound t))
             (setq found (and (looking-at "[ \t]*\"")
                              (progn
                                (forward-sexp)
                                (looking-at "[ \t\n]+\""))
                              (progn
                                (setq beg (match-end 0))
                                (>= beg pnt))
                              (<= beg bound)
                              (progn
                                (forward-sexp)
                                (setq end (1- (point)))))))))
    (when found
      (remove-text-properties beg end '(face))
      (make-text-button beg end 'type 'djvu-url
                        'djvu-args (list (buffer-substring-no-properties beg end))))
    found))

(defun djvu-button-action (button)
  "Call BUTTON's Djvu function."
  (apply (button-get button 'djvu-function)
         (button-get button 'djvu-args)))

(define-button-type 'djvu-url
  'action 'djvu-button-action
  'djvu-function 'djvu-url
  'help-echo "mouse-2, RET: follow URL")

(defun djvu-url (url)
  "Browse URL in Djvu document.
If URL is an internal url, go to that page."
  (if (string-match "\\`#" url)
      (let* ((page-url (substring url 1))
             (page (or (car (rassoc page-url (djvu-ref page-id)))
                       (and (string-match "\\`[0-9]+\\'" page-url)
                            (string-to-number page-url)))))
        (unless page (error "Invalid internal url `%s'" page-url))
        (djvu-goto-page page)
        (djvu-switch-read))
    (browse-url url)))

;; Djvused maparea `text'
(defun djvu-interactive-text-area (&optional border backclr textclr pushpin)
  "Interactive spec for `djvu-text-area' and friends."
  (let ((dpos (djvu-mean-dpos (djvu-read-dpos)))
        (pagesize (djvu-ref pagesize))
        (color (djvu-interactive-color djvu-color-highlight)))
    (list nil (read-string (format "(%s) Text: " color)
                          nil nil nil djvu-inherit-input-method)
          (list (nth 0 dpos) (nth 1 dpos)
                (+ (nth 0 dpos) (/ (car pagesize) 2))
                (+ (nth 1 dpos) (/ (cdr pagesize) 30)))
          border
          (or backclr (djvu-color-background color))
          textclr pushpin)))

(defsubst djvu-insert-color (key color)
  (if color
      (format " (%s %s)" key
              (cond ((string-match "\\`#" color) color)
                    ((cdr (assoc color djvu-color-alist)))
                    (t (error "Color `%s' undefined" color))))
    ""))

(defun djvu-bound-area (area &optional doc)
  "Restrict AREA to page boundaries."
  (unless doc (setq doc djvu-doc))
  ;; AREA may be a list or vector.  Always return a list.
  (list (max 1 (min (elt area 0) (car (djvu-ref pagesize doc))))
        (max 1 (min (elt area 1) (cdr (djvu-ref pagesize doc))))
        (max 1 (min (elt area 2) (car (djvu-ref pagesize doc))))
        (max 1 (min (elt area 3) (cdr (djvu-ref pagesize doc))))))

(defun djvu-text-area (url comment area
                           &optional border backclr textclr pushpin)
  "Using strings URL and COMMENT, highlight AREA.
This defines a text maparea for djvused.
AREA is a list (XMIN YMIN XMAX YMAX).
Interactively, the command `djvu-mouse-text-area' in `djvu-image-mode'
is usually easier to use."
  (interactive (djvu-interactive-text-area))
  (setq area (djvu-bound-area area))
  (with-current-buffer (djvu-ref annot-buf)
    (goto-char (point-max))
    (insert (format "(maparea %S\n %S\n "
                    (or url "") (if comment (djvu-fill comment) ""))
            (apply 'format "(text %d %d %d %d)" area)
            (format " (%s)" (or border 'none))
            (djvu-insert-color "backclr" backclr)
            (djvu-insert-color "textclr" textclr)
            (if pushpin " (pushpin)" "")
            ")\n\n")
    (undo-boundary)))

(defun djvu-text-area-pushpin (url comment area
                                   &optional border backclr textclr pushpin)
  "Using URL and COMMENT, highlight AREA as pushpin.
This defines a rect area for djvused.
Interactively, the command `djvu-mouse-text-area-pushpin' in `djvu-image-mode'
is usually easier to use."
  (interactive (djvu-interactive-text-area nil nil nil t))
  (djvu-text-area url comment area border backclr textclr pushpin))

(defun djvu-mark-line-beg (pnt comment &optional left color)
  "Mark word at beginning of line.
With prefix LEFT mark left of beginning of line."
  (interactive
   (list (line-beginning-position)
         (read-string (format "(%s) Marker comment: " djvu-color-himark)
                      nil nil nil djvu-inherit-input-method)
         current-prefix-arg djvu-color-himark))
  (let* ((zone (get-text-property pnt 'word))
         (height (- (aref zone 3) (aref zone 1)))
         (xmin (- (aref zone 0) (round (* 2.5 height)))))
    (if left
        (djvu-text-area nil comment
                        (list xmin (aref zone 1)
                              (- (aref zone 0) (/ height 2)) (aref zone 3))
                        nil
                        (djvu-color-background color))
      (djvu-rect-area nil comment
                      `((,xmin ,(aref zone 1) ,(aref zone 2) ,(aref zone 3)))
                      color djvu-opacity))))

;; Djvused maparea `rect'
(defun djvu-himark (bookmark url beg end comment
                             &optional level color opacity border)
  ;; Fixme: Fix docstring.
  "Bookmark and highlight the region between BEG and END."
  (interactive
   (djvu-with-region region
     (let ((level (djvu-interactive-bookmark-level)) ; handle prefix arg first
           (bookmark (djvu-read-string "Bookmark: " region t)))
       (list bookmark (djvu-ref page) (car region) (cdr region) bookmark level
             djvu-color-himark djvu-opacity nil))))
  (djvu-bookmark bookmark url level)
  (djvu-rect-region beg end nil comment color opacity border))

(defun djvu-update-url (url &optional color opacity border)
  "Update URL"
  (interactive
   (let* ((color (djvu-interactive-color djvu-color-url))
          (url (djvu-interactive-url color)))
     (list url color djvu-opacity 'xor)))
  (let ((dpos (djvu-dpos))
        (doc djvu-doc))
    (with-current-buffer (djvu-ref annot-buf doc)
      (if (djvu-goto-dpos 'rect dpos)
          (djvu-update-url-internal url color opacity border)
        (user-error "No object to update")))))

(defun djvu-update-url-internal (url &optional color _opacity border)
  "Update URL internal."
  (interactive
   (let* ((color (djvu-interactive-color djvu-color-url))
          (url (djvu-interactive-url color)))
     (list url color djvu-opacity 'xor)))
  (let ((bounds (djvu-object-bounds)))
    (if bounds
        (save-excursion
          (save-restriction
            (narrow-to-region (car bounds) (cdr bounds))
            (goto-char (point-min))
            (if (not (looking-at "(maparea \\(\"[^\"]*\"\\)"))
                (user-error "Nothing to update")
              (replace-match (format "\"%s\"" url) nil nil nil 1)
              (djvu-update-color-internal color)
              (goto-char (point-min))
              (let ((border (format "(%s)" border)))
                (if (re-search-forward "(\\(none\\|xor\\))" nil t)
                    (replace-match border)
                  (goto-char (point-max))
                  (skip-chars-backward " \t\n")
                  (backward-char) ; skip closing ")"
                  (insert " " border)))))))))

(defun djvu-rect-region-url (beg end url comment &optional color opacity border)
  "Put URL over region between BEG and END, adding annotation COMMENT."
  ;; Same as `djvu-rect-region', but it also adds the url field
  (interactive
   (djvu-with-region region
     (let* ((color (djvu-interactive-color djvu-color-url))
            (url (djvu-interactive-url color))
            (comment (djvu-read-string
                      (format "(%s, %s) Annotation: " url color)
                      region)))
       (list (car region) (cdr region) url comment color djvu-opacity 'xor))))
  (djvu-rect-region beg end url comment color opacity border))

(defun djvu-rect-region (beg end url comment &optional color opacity border)
  "Highlight region between BEG and END, add URL and annotation COMMENT."
  (interactive
   (djvu-with-region region
     (let* ((color (djvu-interactive-color djvu-color-highlight))
            (comment (djvu-read-string (format "(%s) Annotation: " color)
                                       region)))
       (list (car region) (cdr region) nil comment color djvu-opacity 'none))))

  (unless (get-text-property beg 'word)
    (user-error "Start position `%s' not a word" beg))
  (unless (get-text-property (1- end) 'word)
    (user-error "End position `%s' not a word" end))
  (let ((lines (djvu-region-count beg end 'line))
        (paras (djvu-region-count beg end 'para))
        (regions (djvu-region-count beg end 'region))
        (columns (djvu-region-count beg end 'column))
        areas)
    (unless (and (>= 1 paras) (>= 1 regions) (>= 1 columns))
      (user-error "Region spans multiple paragraphs"))

    (if (eq 1 lines)
        (setq areas (list (djvu-scan-zone beg end 'word)))

      (if (eq 2 lines)
          (let ((c1 (djvu-scan-zone beg (djvu-property-end (1+ beg) 'line) 'word))
                (c2 (djvu-scan-zone (djvu-property-beg (1- end) 'line) end 'word)))
            ;; If BEG is beginning of first line, both lines share same left margin.
            (if (and (= beg (djvu-property-beg beg 'line))
                     (djvu-areas-justify t c1 c2))
                (djvu-justify-areas 'min 0 c1 c2))
            ;; If END is end of second line, both lines share same right margin.
            (if (and (= end (djvu-property-end end 'line))
                     (djvu-areas-justify nil c2 c1))
                (djvu-justify-areas 'max 2 c1 c2))
            (if (<= (aref c1 0) (aref c2 2))
                ;; Lower bound of upper box and upper bound of lower box coincide.
                (let ((tmp (/ (+ (aref c1 1) (aref c2 3)) 2)))
                  (aset c1 1 tmp) (aset c2 3 tmp)))
            (setq areas (list c1 c2)))
        ;; 3 lines
        (let* ((l1e (djvu-property-end (1+ beg) 'line))
               (l2b (djvu-property-beg (1- end) 'line))
               (c1  (djvu-scan-zone beg l1e 'word))
               (ci  (djvu-scan-zone (1+ l1e) (1- l2b) 'line))
               (c2  (djvu-scan-zone l2b end 'word)))
          ;; If BEG is beginning of first line, all lines share same left margin.
          (cond ((and (= beg (djvu-property-beg beg 'line))
                      (djvu-areas-justify t c1 ci c2))
                 (djvu-justify-areas 'min 0 c1 ci c2))
                ((djvu-areas-justify t ci c2)
                 (djvu-justify-areas 'min 0 ci c2)))
          ;; If END is end of last line, all lines share same right margin.
          (cond ((and (= end (djvu-property-end end 'line))
                      (djvu-areas-justify nil c2 ci c1))
                 (djvu-justify-areas 'max 2 c1 ci c2))
                ((djvu-areas-justify nil c1 ci)
                 (djvu-justify-areas 'max 2 c1 ci)))
          (let ((tmp1 (/ (+ (aref c1 1) (aref ci 3)) 2))
                (tmp2 (/ (+ (aref ci 1) (aref c2 3)) 2)))
            ;; Lower bound of upper boxes and upper bound of lower boxes coincide.
            (aset c1 1 tmp1) (aset ci 3 tmp1)
            (aset ci 1 tmp2) (aset c2 3 tmp2))
          (setq areas (list c1 ci c2)))))

    (djvu-rect-area url comment areas color opacity border)))

(defun djvu-merge-areas (areas)
  "Try to merge elements in AREAS.
This assumes that element N in AREAS is above element N+1.
If such a pair of elements has the same left and right boundaries,
and the lower boundary of N equals the upper boundary of N+1,
these elements are merged into one."
  (let ((areas areas))
    (while (nth 1 areas)
      (let ((c0 (nth 0 areas)) (c1 (nth 1 areas)))
        (if (and (eq (aref c0 0) (aref c1 0))
                 (eq (aref c0 2) (aref c1 2))
                 (eq (aref c0 1) (aref c1 3)))
            (progn (aset c0 1 (aref c1 1))
                   (setcdr areas (cddr areas)))
          (pop areas)))))
  areas)

(defun djvu-rect-area (url comment rects &optional color opacity border)
  "Using URL and COMMENT, highlight RECTS.
The elements in the list RECTS are 4-element sequences of coordinates
each defining a rect area for djvused."
  (setq rects (mapcar (lambda (rect) (apply 'format "(rect %d %d %d %d)"
                                            (djvu-bound-area rect)))
                      (djvu-merge-areas rects)))
  ;; Insert in Annotations buffer.
  (with-current-buffer (djvu-ref annot-buf)
    (unless (and djvu-rect-area-nodups
                 (save-excursion
                   (goto-char (point-min))
                   (re-search-forward (mapconcat 'identity rects "[ \t\n]*")
                                      nil t)))
      (goto-char (point-max))
      (insert (format "(maparea %S\n %S\n ("
                      (or url "") (if comment (djvu-fill comment) ""))
              (mapconcat 'identity rects "\n  ")
              ")\n"
              (djvu-insert-color "hilite" color)
              (if opacity (format " (opacity %s)" opacity) "")
              (format " (%s)" (or border 'none))
              ")\n\n")
      (undo-boundary))))

(defun djvu-fill (text)
  "Fill string TEXT using `fill-column' of the annotations buffer.
This value of `fill-column' defaults to `djvu-fill-column'."
  (let ((fcolumn (with-current-buffer (djvu-ref annot-buf)
                   fill-column)))
    (with-temp-buffer
      (insert text)
      (let ((fill-column fcolumn))
        (fill-region (point-min) (point-max)))
      (buffer-substring-no-properties
       (point-min) (point-max)))))

(defun djvu-toggle-rect-text-internal ()
  "Toggle between Mapareas rect and text."
  (interactive)
  (let ((bounds (djvu-object-bounds))
        (rect-re "(rect \\([0-9]+ [0-9]+ [0-9]+ [0-9]+\\))")
        (text-re "(text \\([0-9]+ [0-9]+ [0-9]+ [0-9]+\\))")
        (color-re (format djvu-color-re "#" "" "")))
    (if (not bounds)
        (user-error "No object to update")
      (save-excursion
        (save-restriction
          (narrow-to-region (car bounds) (cdr bounds))
          (goto-char (point-min))

          (cond ((re-search-forward rect-re nil t) ; Maparea rect
                 (if (save-match-data (re-search-forward rect-re nil t))
                     (user-error "Only single rect can be converted to text"))
                 (replace-match (format "text %s" (match-string 1)))
                 (goto-char (point-min))
                 (let ((opacity
                        (if (re-search-forward " *(opacity \\([0-9]+\\))" nil t)
                            (prog1 (djvu-match-number 1)
                              (replace-match ""))
                          djvu-opacity)))
                   (goto-char (point-min))
                   ;; Loop over matches of COLOR-RE as this general regexp
                   ;; also matches elements that so far we do not care about.
                   (while (re-search-forward color-re nil t)
                     (if (equal (match-string 1) "hilite")
                         (replace-match
                          (format "(backclr %s)"
                                  (save-match-data
                                    (djvu-color-background
                                     (match-string 2) nil opacity))))))))

                ((re-search-forward text-re nil t) ; Maparea text
                 ;; Only with maparea text we want to query the opacity.
                 ;; Putting this into the interactive spec would require
                 ;; to duplicate the job.
                 (let ((opacity (save-match-data
                                  (read-number "Opacity: " djvu-opacity))))
                   (replace-match (format "((rect %s))" (match-string 1)))
                   (goto-char (point-min))
                   ;; Loop over matches of COLOR-RE as this general regexp
                   ;; also matches elements that so far we do not care about.
                   (while (re-search-forward color-re nil t)
                     (if (equal (match-string 1) "backclr")
                         (replace-match
                          (format "(hilite %s) (opacity %d)"
                                  (save-match-data
                                    (djvu-color-background
                                     (match-string 2) nil opacity t))
                                  opacity))))))
                (t
                 (user-error "Nothing to toggle"))))))))

(defvar djvu-area-re
  (format "(%s \\(%s\\))"
          (regexp-opt '("rect" "oval" "text") t)
          (mapconcat (lambda (_) "\\([0-9]+\\)") '(1 2 3 4) " "))
  "Regexp matching a Djvu area.
Substring 1: area type, 2: coordinates, 3-6: individual coordinates.")

(defun djvu-resize-internal (step)
  "Resize Djvu mapareas rect and text by STEP."
  (interactive "nStep: ")
  (let ((bounds (djvu-object-bounds)))
    (if (not bounds)
        (user-error "No object to update")
      (save-excursion
        (save-restriction
          (narrow-to-region (car bounds) (cdr bounds))
          (goto-char (point-min))
          (while (re-search-forward djvu-area-re nil t)
            (replace-match (format "%d %d %d %d"
                                   (- (djvu-match-number 3) step)
                                   (- (djvu-match-number 4) step)
                                   (+ (djvu-match-number 5) step)
                                   (+ (djvu-match-number 6) step))
                             nil nil nil 2)))))))

(defun djvu-shift-internal (shiftx shifty &optional all)
  "Shift Djvu mapareas rect and text by SHIFTX and SHIFTY.
With prefix ALL non-nil shift all mapareas of current page."
  (interactive
   (let ((shift (mapcar 'string-to-number
                        (split-string (read-string "Shiftx, shifty: ")
                                      "[\t\s\n,;]+" t "[\t\s\n]"))))
     (list (nth 0 shift) (nth 1 shift) current-prefix-arg)))
  (save-excursion
    (save-restriction
      (unless all
        (let ((bounds (djvu-object-bounds)))
          (if bounds
              (narrow-to-region (car bounds) (cdr bounds))
            (user-error "No object to update"))))
      (goto-char (point-min))
      ;; FIXME: provide alternative regexp for text buffer.
      ;; FIXME: honor page boundaries:
      ;; Cut off visible areas, drop invisble areas (with warning?)
      (while (re-search-forward djvu-area-re nil t)
        (replace-match (format "%d %d %d %d"
                               (+ (djvu-match-number 3) shiftx)
                               (+ (djvu-match-number 4) shifty)
                               (+ (djvu-match-number 5) shiftx)
                               (+ (djvu-match-number 6) shifty))
                       nil nil nil 2)))))

(defun djvu-remove-linebreaks-internal ()
  "Remove linebreaks in Maparea string.
This may come handy for reformatting such strings."
  (interactive)
  (let ((bounds (djvu-object-bounds)))
    (if (not bounds)
        (user-error "No object to update")
      (save-excursion
        (goto-char (car bounds))
        ;; Skip over maparea and url
        (forward-char)
        (forward-sexp 2)
        (skip-chars-forward "\s\t\n")
        (save-restriction
          (narrow-to-region (point) (scan-sexps (point) 1))
          (while (re-search-forward "\n" nil t)
            (replace-match " ")))))))

;; The functions `djvu-property-beg' and `djvu-property-end' rely on the fact
;; that regions with property PROP are always surrounded by at least one
;; character without property PROP.  Repeated calls of `djvu-property-beg'
;; and `djvu-property-end' thus never go beyond this region.
(defun djvu-property-beg (pnt prop)
  "Starting from position PNT search backward for beginning of property PROP.
Return position found."
  (let ((p1 (get-text-property pnt prop)) pnt-1)
    (cond ((and p1 (< (point-min) pnt)
                (eq p1 (get-text-property (1- pnt) prop)))
           (previous-single-property-change pnt prop nil (point-min)))
          (p1 pnt)
          ((and (< (point-min) pnt)
                (setq p1 (get-text-property (setq pnt-1 (1- pnt)) prop)))
           ;; PNT is at the end position for property PROP
           (if (and (< (point-min) pnt-1)
                    (eq p1 (get-text-property (1- pnt-1) prop)))
               (previous-single-property-change pnt-1 prop nil (point-min))
             pnt-1))
          (t (error "Position %s does not have/end property %s" pnt prop)))))

(defun djvu-property-end (pnt prop)
  "Starting from position PNT search forward for end of property PROP.
Return position found."
  (let ((p1 (get-text-property pnt prop)))
    (cond ((and p1 (< pnt (point-max))
                (eq p1 (get-text-property (1+ pnt) prop)))
           (next-single-property-change pnt prop nil (point-max)))
          (p1 (1+ pnt))
          ((and (< (point-min) pnt)
                (get-text-property (1- pnt) prop))
           ;; We had PNT at the end position for property PROP
           pnt)
          (t (error "Position %s does not have/end property %s" pnt prop)))))

(defun djvu-areas-justify (left &rest ci)
  "Return non-nil if areas CI shall be justified horizontally.
If LEFT is nil analyze left boundaries of CI, otherwise the right boundaries."
  (let ((xl (apply 'min (mapcar (lambda (c) (aref c 0)) ci)))
        (xr (apply 'max (mapcar (lambda (c) (aref c 2)) ci))))
    (> djvu-areas-justify
       (/ (apply 'max (mapcar (lambda (cj)
                                (abs (float (if left (- (aref cj 0) xl)
                                              (- xr (aref cj 2))))))
                              ci))
          (float (- xr xl))))))

(defun djvu-justify-areas (fun n &rest ci)
  "Pass Nth elements of arrays CI to function FUN.
Set these elements to return value of FUN.
If FUN is `min' or `max' these elements are set to the respective minimum
or maximum among the Nth elements of all arrays CI."
  (let ((tmp (apply fun (mapcar (lambda (c) (aref c n)) ci))))
    (dolist (c ci)
      (aset c n tmp))))

(defun djvu-scan-zone (beg end prop)
  "Between BEG and END calculate total zone for PROP."
  ;; Assume that BEG has PROP.
  (let ((zone (copy-sequence (get-text-property beg prop)))
        (pnt beg) val)
    (while (and (/= pnt end)
                (setq pnt (next-single-property-change pnt prop nil end)))
      (when (setq val (get-text-property pnt prop))
        (aset zone 0 (min (aref zone 0) (aref val 0)))
        (aset zone 1 (min (aref zone 1) (aref val 1)))
        (aset zone 2 (max (aref zone 2) (aref val 2)))
        (aset zone 3 (max (aref zone 3) (aref val 3)))))
    zone))

(defun djvu-region-count (beg end prop)
  "Count regions between BEG and END with distinct non-nil values of PROP."
  (let ((count 0)
        (pnt beg))
    (while (and (/= pnt end)
                (setq pnt (next-single-property-change pnt prop nil end)))
      (if (get-text-property (1- pnt) prop)
          (setq count (1+ count))))
    count))

(defun djvu-read-annot (buf)
  "Read annotations of a Djvu document from annotations buffer."
  (let (object)
    (with-current-buffer buf
      (save-restriction
        (widen)
        (with-temp-buffer
          (insert-buffer-substring-no-properties buf)
          (djvu-convert-hash)
          (goto-char (point-min))
          (while (progn (skip-chars-forward " \t\n") (not (eobp)))
            (if (looking-at djvu-annot-re)
                (condition-case nil
                    (push (read (current-buffer)) object)
                  (error (error "Syntax error in annotations")))
              (error "Unknown annotation `%s'" (buffer-substring-no-properties
                                                (point) (line-end-position))))))))
    (nreverse object)))

(defun djvu-save-annot (script &optional doc shared)
  "Save annotations of the Djvu document DOC.
This dumps the content of DOC's annotations buffer into the djvused script
file SCRIPT.  DOC defaults to the current Djvu document."
  (unless doc (setq doc djvu-doc))
  (let ((object (djvu-read-annot (if shared
                                     (djvu-ref shared-buf doc)
                                   (djvu-ref annot-buf doc)))))
    (dolist (elt object)
      (if (eq 'maparea (car elt))
          ;; URL
          (setcar (cdr elt) (djvu-resolve-url (nth 1 elt)))))

    (with-temp-buffer
      (let ((standard-output (current-buffer))
            (buffer-file-coding-system 'utf-8)
            (id 0)
            rect-list)
        (insert (if shared
                    "create-shared-ant; remove-ant; set-ant\n"
                  (format "select %d; remove-ant; set-ant\n"
                          (djvu-ref page doc))))
        (dolist (elt object)
          (cond ((eq 'metadata (car elt)) ; metadata
                 (prin1 elt)
                 (insert "\n"))
                ((or (not (eq 'maparea (car elt))) ; not maparea
                     (eq 'line (car (nth 3 elt)))) ; maparea line
                 (prin1 elt)
                 (insert "\n"))
                ((consp (car (nth 3 elt))) ; maparea rect and oval
                 (dolist (area (nth 3 elt))
                   (insert (prin1-to-string
                            (apply 'list (car elt) (nth 1 elt) (nth 2 elt)
                                   (djvu-area area t) (nthcdr 4 elt))) "\n"))
                 (setq id (1+ id))
                 (push (djvu-rect-elt
                        ;; `djvu-rect-elt' expects that the rect areas are at
                        ;; the end.
                        (cons (append (list (nth 0 elt) (nth 1 elt) (nth 2 elt))
                                      (nthcdr 4 elt))
                              (nth 3 elt))
                        id)
                       rect-list))
                ((eq 'text (car (nth 3 elt))) ; maparea text
                 (insert (prin1-to-string
                          (apply 'list (car elt) (nth 1 elt) (nth 2 elt)
                                 (djvu-area (nth 3 elt) t)
                                 (nthcdr 4 elt))) "\n"))
                (t (error "Djvu maparea %s undefined" (car (nth 3 elt))))))
        (insert ".\n")
        (djvu-convert-hash t)
        (write-region nil nil script t 0) ; append to SCRIPT
        ;; It is not all correct to ignore rect-list for shared
        ;; annotations.  It should really go into a separate variable
        ;; `djvu-doc-shared-rect-list', so that then we can merge
        ;; these for all pages.
        (unless shared
          (djvu-set rect-list (apply 'nconc rect-list) doc))))))

(defun djvu-annot-script (&optional doc buffer page display)
  "Create djvused script for complete annotation layer of DOC in BUFFER.
If prefix PAGE is non-nil create instead script for only page PAGE.
BUFFER defaults to `djvu-script-buffer'.  If BUFFER is t use current buffer.

You can edit the annotations script in BUFFER.  Afterwards you can re-apply
this script using `djvu-process-script'.  This code will not (cannot) check
whether the edited script is meaningful for DOC.  Use at your own risk.
You get what you want."
  (interactive (list nil nil (if current-prefix-arg (djvu-ref page)) t))
  (let ((doc (or doc djvu-doc))
        (buffer (djvu-script-buffer buffer)))
    (djvu-save doc t)
    ;; Put this in a separate buffer!
    (with-current-buffer buffer
      (let ((buffer-undo-list t)
            buffer-read-only)
        (djvu-script-mode)
        (erase-buffer)
        ;; Always create a self-contained djvused script.
        (if page (insert (format "select \"%s\" # page %d\n"
                                 (cdr (assq page (djvu-ref page-id doc)))
                                 page)))
        (djvu-djvused doc t "-e" (format "select %s; output-ant;"
                                         (or page "")))
        (goto-char (point-min))
        (while (re-search-forward "^(maparea" nil t)
          (forward-sexp) ; jump over URL
          ;; replace newlines within text
          (let ((limit (save-excursion (forward-sexp) (point))))
            (while (search-forward "\\n" limit t)
              (replace-match "\n"))))
        (goto-char (point-min)))
      (set-buffer-modified-p nil)
      (setq buffer-undo-list nil))
    (if display (switch-to-buffer buffer))))

(defun djvu-annot-dpos (&optional point doc)
  "Return Djvu position of POINT in Djvu annotations buffer."
  (with-current-buffer (djvu-ref annot-buf doc)
    (save-excursion
      (if point (goto-char point))
      (let ((bounds (djvu-object-bounds)))
        (if bounds
            (let* ((object (djvu-object bounds))
                   (area (nth 3 object)))
              (if (eq (car object) 'maparea)
                  (cond ((memq (car area) '(text line))
                         (cdr (nth 3 object)))
                        ((consp area) ; maparea rect and oval
                         (cdar area))))))))))

;;; Manipulate annotations

(defvar djvu-beg-object-re
  (concat "^[\s\t]*(" (regexp-opt '("background" "zoom" "mode" "align"
                                    "maparea" "metadata" "bookmarks")
                                  t))
  "Regexp matching the beginning of Djvu annotation object.")

(defun djvu-object-bounds ()
  "Return bounds (BEG . END) of Djvu object that contains or follows point.
Return nil if no such object can be found."
  (save-excursion
    (let ((pnt (point)) found end)
      (beginning-of-line)
      (while (not (or (setq found (looking-at djvu-beg-object-re))
                      (bobp)))
        (forward-line -1))
      (if (and found
               (< pnt (setq end (save-excursion (forward-sexp) (point)))))
          (cons (point) end)
        (setq found nil)
        (goto-char pnt)
        (while (not (or (setq found (looking-at djvu-beg-object-re))
                        (eobp)))
          (forward-line 1))
        (if found
            (cons (point) (progn (forward-sexp) (point))))))))

(defun djvu-object (bounds)
  "Return Djvu object defined via BOUNDS, a cons cell (BEG . END)."
  ;; We cannot call `read' in a Djvu buffer because the Djvu hash syntax
  ;; is not compatible with the Emacs read syntax.
  (let ((string (buffer-substring-no-properties (car bounds) (cdr bounds))))
    (with-temp-buffer
      (insert string)
      (djvu-convert-hash)
      (goto-char (point-min))
      (read (current-buffer)))))

(defun djvu-update-color (color)
  "Update color attribute of Djvu maparea to COLOR."
  (interactive (list (completing-read "New Color: " djvu-color-alist nil t)))
  (let ((dpos (djvu-dpos))
        (doc djvu-doc))
    (with-current-buffer (djvu-ref annot-buf doc)
      (if (djvu-goto-dpos 'rect dpos)
          (djvu-update-color-internal color)
        (user-error "No object to update")))))

(defun djvu-update-color-internal (color)
  "Update color attribute of Djvu maparea to COLOR.
If no such attribute exists insert a new one."
  (interactive (list (completing-read "New Color: " djvu-color-alist nil t)))
  (let ((bounds (djvu-object-bounds)))
    (if bounds
        (save-excursion
          (goto-char (car bounds))
          (cond ((re-search-forward
                  (format djvu-color-re "#" "" "") (cdr bounds) t)
                 ;; update existing color attribute
                 (let ((attr (match-string 1)))
                   (cond ((member attr '("hilite" "lineclr"))
                          (replace-match (cdr (assoc color djvu-color-alist))
                                         nil nil nil 2))
                         ((string= attr "backclr")
                          (replace-match (save-match-data
                                          (djvu-color-background color))
                                         nil nil nil 2))
                         (t (message "Color update for attribute `%s' undefined"
                                     attr)))))
                ;; insert new color attribute (dependent on area attribute)
                ((re-search-forward "(rect" (cdr bounds) t)
                 (goto-char (1- (cdr bounds)))
                 (insert (format " (hilite %s)"
                                 (cdr (assoc color djvu-color-alist))))
                 (unless (save-excursion
                           (goto-char (car bounds))
                           (re-search-forward "(opacity [0-9]+)" (cdr bounds) t))
                   (insert (format " (opacity %d)" djvu-opacity))))
                ((re-search-forward "(text" (cdr bounds) t)
                 (goto-char (1- (cdr bounds)))
                 (insert (format " (backclr %s)"
                                 (djvu-color-background color))))
                (t (message "Do not know how to update color")))))))

(defun djvu-merge-mapareas (beg end)
  "Merge Djvu mapareas from BEG to END."
  (interactive "r")
  (let (bounds url text rect hilite opacity border)
    (goto-char beg)
    (while (and (< (point) end)
                (setq bounds (djvu-object-bounds)))
      (if (< (car bounds) beg) (setq beg (car bounds)))
      (if (< end (cdr bounds)) (setq end (cdr bounds)))
      (let ((maparea (djvu-object bounds)))
        (unless (eq 'maparea (car maparea))
          (error "Cannot merge `%s'" (car maparea)))
        (push (nth 1 maparea) url)
        (push (nth 2 maparea) text)
        (dolist (elt (nthcdr 3 maparea))
          (cond ((consp (car elt)) ; list of rects
                 (mapc (lambda (r) (push r rect)) elt))
                ((memq (car elt) '(text line))
                 (user-error "Cannot merge text or line mapareas"))
                ((eq (car elt) 'hilite)
                 (push (cadr elt) hilite))
                ((eq (car elt) 'opacity)
                 (push (cadr elt) opacity))
                ((memq (car elt) '(none xor))
                 (push (car elt) border))
                (t
                 (error "Unknown attribute `%s'" elt)))))
      (goto-char (cdr bounds))
      (skip-chars-forward "\s\t\n"))

    ;; Remove duplicate attribute
    (setq url (or (delete-dups (delete "" url)) '("")))
    (if (nth 1 url) (user-error "Cannot merge multiple URLs"))
    (setq text (mapconcat 'identity (nreverse (delete "" text)) "\n"))
    (setq hilite (delete-dups hilite))
    (if (nth 1 hilite) (user-error "Cannot merge multiple hilites"))
    (setq opacity (delete-dups opacity))
    (if (nth 1 opacity) (user-error "Cannot merge multiple opacities"))
    ;; Border `none' is given lower precedence than other borders
    (setq border (or (delete-dups (delq 'none border)) '(none)))
    (if (nth 1 border) (user-error "Cannot merge multiple borders"))

    (goto-char beg)
    (delete-region beg end)
    (insert (format "(maparea %S\n %S\n (" (car url) text)
            (mapconcat 'prin1-to-string (nreverse rect) "\n  ") ")\n"
            (if hilite (format " (hilite %s)" (car hilite)) "")
            (if opacity (format " (opacity %s)" (car opacity)) "")
            (format " (%s)" (car border))
            ")\n")
    (save-restriction
      (narrow-to-region beg (point))
      (djvu-convert-hash t))))

;;; Djvu Bookmarks mode

(defun djvu-bookmarks-page (&optional pnt doc)
  "In Bookmarks buffer return page number at position PNT.
PNT defaults to position of point."
  (djvu-url-page
   (save-excursion
     (if pnt (goto-char pnt))
     (beginning-of-line)
     (while (not (or (bobp)
                     (looking-at "^[\t\s]*(\\(\"\\)")))
       (forward-line -1))
     (when (match-beginning 1)
       (goto-char (match-beginning 1))
       (forward-sexp)
       (read (current-buffer))))
   doc))

(defun djvu-url-page (url &optional doc)
  "For the internal URL return the corresponding page number.
This is the inverse of `djvu-page-url'.
Return nil if URL is not an internal URL."
  ;; If we try to grab URL from a bookmarks or outline buffer, URL may be nil.
  (if url
      ;; Internal URLs start with "#".
      (cond ((string-match "\\`#\\([0-9]+\\)\\'" url)
             (djvu-match-number 1 url))
            ((string-match "\\`#" url)
             (car (rassoc (substring-no-properties url 1)
                          (djvu-ref page-id doc)))))))

(defun djvu-bookmark (text page &optional level)
  "Create bookmark"
  (interactive
   (djvu-with-region region
     (list (djvu-read-string "Bookmark: " region t)
           (djvu-ref page) (djvu-interactive-bookmark-level))))
  ;; Remove newlines from TEXT that are ignored anyway
  (setq text (replace-regexp-in-string "[\n ]+" " " text))
  (let (object)
    (with-current-buffer (djvu-ref bookmarks-buf)
      (goto-char (point-min))
      (if (equal (point) (point-max))
          (setq object (list 'bookmarks))
        (condition-case nil
            (setq object (read (current-buffer)))
          (error (error "Syntax error in bookmarks"))))
      (unless (eq 'bookmarks (car object))
        (error "No bookmarks"))
      ;; We keep bookmarks sorted by page number.  So each time we add
      ;; a new bookmark, we rewrite the complete bookmarks buffer.
      ;; This can blow up `buffer-undo-list'.  Can we be smarter?
      (let* ((djvu-bookmark-level -1)
             ;; Catch user errors from splicing before modifying
             ;; the bookmarks buffer.
             (object (djvu-splice-bookmark text page (cdr object) level)))
        (erase-buffer)
        (insert "(bookmarks")
        (djvu-insert-bookmarks object " ")
        (insert ")\n"))
      (goto-char (point-min))
      (undo-boundary))))

(defun djvu-interactive-bookmark-level ()
  "Return bookmark level for interactive commands.
Value is nil if the command is called without prefix arg.
Value is t (one level down) if called with prefix C-u.
Otherwise the raw prefix arg should be a non-negative integer
specifying the absolute level of the bookmark."
  (cond ((consp current-prefix-arg))
        ((integerp current-prefix-arg)
         (abs current-prefix-arg))))

(defun djvu-splice-bookmark (text page object &optional level)
  "Splice bookmark (TEXT PAGE) into tree of bookmarks OBJECT.
If LEVEL is t put bookmark one sublevel below the level
of the preceding bookmark.
If LEVEL is a non-negative integer put bookmark on level LEVEL.
This throws a user error if a bookmark subtree at PAGE extends
beyond PAGE so that putting a new bookmark for PAGE past this subtree
would break the page ordering of the bookmarks.
This code assumes that bookmarks are ordered by page number and that
external URLs appear at the beginning of a subtree of bookmarks."
  (setq djvu-bookmark-level (1+ djvu-bookmark-level))
  (if (or (null object)
          (let ((page-url (djvu-url-page (nth 1 (car object)))))
            (and page-url ; ignore external url
                 (< page page-url))))
      ;; put new bookmark before first bookmark on current level
      (cons (list text (djvu-page-url page)) object)
    (let ((object object))
      (while object
        (if (or (not (djvu-url-page (nth 1 (car object)))) ; ignore external url
                (and (cdr object)
                     (>= page (djvu-url-page (nth 1 (nth 1 object))))))
            (setq object (cdr object)) ; keep searching
          (if (or (and (not level)
                       (nth 2 (car object)))
                  (eq t level)
                  ;; If LEVEL is greater than `djvu-bookmark-level',
                  ;; we add only one level beyond `djvu-bookmark-level',
                  ;; irrespective of the actual value of LEVEL.
                  (and (integerp level)
                       (< djvu-bookmark-level level)))
              ;; go down one level
              (setcar object (cons (nth 0 (car object))
                                   (cons (nth 1 (car object))
                                         (djvu-splice-bookmark
                                          text page (nthcdr 2 (car object))
                                          level))))
            (let (page-max)
              (and (eq level djvu-bookmark-level)
                   (setq page-max (djvu-bookmarks-page-max
                                   (nthcdr 2 (car object))))
                   (< page page-max)
                   (user-error "Bookmark level %d invalid on page %d: preceding subtree extends to page %d"
                               level page page-max)))
            ;; put new bookmark after current bookmark on current level
            (setcdr object (cons (list text (djvu-page-url page))
                                 (cdr object))))
          (setq object nil))))
    object))

(defun djvu-bookmarks-page-max (object)
  "Return maximum page number of a bookmark tree OBJECT.
Return nil if OBJECT does not have internal URLs."
  (let (page page-max)
    (dolist (elt object)
      (and (setq page (djvu-url-page (nth 1 elt)))
           (setq page-max (if page-max
                              (max page-max page)
                            page)))
      (and (nth 2 elt)
           (setq page (djvu-bookmarks-page-max (nthcdr 2 elt)))
           (setq page-max (if page-max
                              (max page-max page)
                            page))))
    page-max))

(defun djvu-insert-bookmarks (object indent)
  "Insert Bookmarks OBJECT recursively."
  (let ((indent1 (concat indent " ")))
    (dolist (elt object)
      (insert (format "\n%s(%S\n%s %S" indent (car elt) indent
                      (djvu-resolve-url (nth 1 elt))))
      (djvu-insert-bookmarks (nthcdr 2 elt) indent1)
      (insert ")"))))

(defun djvu-init-outline (object &optional doc)
  (with-current-buffer (djvu-ref outline-buf doc)
    (let (buffer-read-only)
      (erase-buffer)
      (djvu-insert-outline object ""))
    (set-buffer-modified-p nil)
    (setq buffer-read-only t)
    (djvu-goto-outline (or (djvu-ref page doc) 1))))

(defun djvu-insert-outline (object indent)
  "Insert Outline OBJECT recursively."
  (let ((indent1 (concat indent "  ")))
    (dolist (elt object)
      (let ((beg (point)))
        (insert indent (car elt))
        (make-text-button beg (point) 'type 'djvu-url
                          ;; Inspired by function `outline-font-lock-face'
                          'face (aref djvu-outline-faces
                                      (% (/ (length indent) 2)
                                         (length djvu-outline-faces)))
                          'help-echo (format "mouse-2, RET: url `%s'"
                                             (nth 1 elt))
                          'djvu-args (list (nth 1 elt))))
      (insert "\n")
      (djvu-insert-outline (nthcdr 2 elt) indent1))))

(defun djvu-outline-page (&optional pnt doc)
  "In Outline buffer return page number at position PNT.
PNT defaults to position of point."
  (djvu-url-page
   (car (get-text-property
         (save-excursion
           (if pnt (goto-char pnt))
           (beginning-of-line)
           (skip-chars-forward "\s\t")
           (point))
         'djvu-args))
   doc))

(defun djvu-goto-outline (&optional page doc)
  "In Outline buffer go to first bookmark matching PAGE."
  (unless page (setq page (djvu-ref page doc)))
  (goto-char (point-min))
  (let ((pnt (point)) p done)
    (while (not (or done (eobp)))
      (when (setq p (djvu-outline-page (point) doc))
        (if (<= p page)
            (setq pnt (point)))
        (setq done (= p page)))
      (forward-line))
    (goto-char pnt)))

(defun djvu-read-bookmarks (&optional doc)
  "Read bookmarks of a Djvu document from bookmarks buffer."
  (let (object)
    (with-current-buffer (djvu-ref bookmarks-buf doc)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (unless (eobp)
            (condition-case nil
                (setq object (read (current-buffer)))
              (error (error "Syntax error in bookmarks"))))
          (skip-chars-forward " \t\n")
          ;; We should have swallowed all bookmarks.
          (unless (eobp)
            (error "Syntax error in bookmarks (end of buffer)")))))
    (if (and object (not (eq 'bookmarks (car object))))
        (error "Malformed bookmarks"))
    object))

(defun djvu-reformat-bookmarks (&optional doc)
  "Reformat Bookmarks buffer for Djvu document DOC."
  (interactive)
  (with-current-buffer (djvu-ref bookmarks-buf doc)
    (let ((pnt (point))
          (object (djvu-read-bookmarks doc)))
      (erase-buffer)
      (insert "(bookmarks")
      (djvu-insert-bookmarks (cdr object) " ")
      (insert ")\n")
      (goto-char pnt))))

(defun djvu-save-bookmarks (script &optional doc)
  "Save bookmarks of a Djvu document.
This dumps the content of DOC's bookmarks buffer into the djvused script
file SCRIPT. DOC defaults to the current Djvu document."
  (unless doc (setq doc djvu-doc))
  (let ((object (djvu-read-bookmarks doc)))
    (with-temp-buffer
      (setq buffer-file-coding-system 'utf-8)
      (insert "set-outline\n")
      (when object
        (insert "(bookmarks")
        (let ((djvu-doc doc)) ; DOC should definitely be initialized above
          (djvu-insert-bookmarks (cdr object) " "))
        (insert ")\n"))
      (insert ".\n")
      (write-region nil nil script t 0)) ; append to SCRIPT
    (djvu-init-outline (cdr object) doc)))

;;; Image minor mode

(defmacro djvu-with-event-buffer (event &rest body)
  "With buffer of EVENT current, evaluate BODY."
  (declare (indent 1))
  ;; Fixme: abort if `minibufferp' returns non-nil?
  `(with-current-buffer (window-buffer (posn-window (event-start ,event)))
     ,@body))

(defun djvu-image-toggle ()
  "Toggle image display of current page."
  (interactive)
  (if (display-images-p)
      ;; arg as in interactive definition of
      ;; `define-derived-mode'
      (djvu-image-mode (or current-prefix-arg 'toggle))
    (message "Cannot display images")))

(define-minor-mode djvu-image-mode
  "Image display of current page."
  :lighter "Image"
  :keymap '(([drag-mouse-1]   . djvu-mouse-rect-area)
            ([S-drag-mouse-1] . djvu-mouse-text-area)
            ([C-drag-mouse-1] . djvu-mouse-text-area-pushpin)
            ([drag-mouse-2]   . djvu-mouse-line-area)
            ([S-drag-mouse-2] . djvu-mouse-line-area-horiz)
            ([C-drag-mouse-2] . djvu-mouse-line-area-vert)
            ([C-S-drag-mouse-2] . djvu-mouse-line-area-arrow)
            ;;
            ([down-mouse-1]   . djvu-mouse-drag-track-area)
            ([S-down-mouse-1] . djvu-mouse-drag-track-area)
            ([C-down-mouse-1] . djvu-mouse-drag-track-area)
            ([down-mouse-2]   . (lambda (event) (interactive "e")
                                  (djvu-mouse-drag-track-area event t)))
            ([S-down-mouse-2] . (lambda (event) (interactive "e")
                                  (djvu-mouse-drag-track-area event 'horiz)))
            ([C-down-mouse-2] . (lambda (event) (interactive "e")
                                  (djvu-mouse-drag-track-area event 'vert)))
            ([C-S-down-mouse-2] . (lambda (event) (interactive "e")
                                    (djvu-mouse-drag-track-area event 'arrow)))
            ;; FIXME: The following binding has no effect.  Why??
            ([M-drag-mouse-1] . djvu-mouse-word-area)
            ([M-down-mouse-1] . djvu-mouse-drag-track-area)
            ([drag-mouse-3]   . djvu-mouse-word-area) ; substitute
            ([down-mouse-3]   . djvu-mouse-drag-track-area) ; substitute
            ;;
            ("+" . djvu-image-zoom-in)
            ("-" . djvu-image-zoom-out))
  (if (and djvu-image-mode
           (not (get-text-property (point-min) 'display)))
      ;; Remember DPOS if we enable `djvu-image-mode'.
      (djvu-set read-pos (let (djvu-image-mode)
                           (djvu-read-dpos))))
  (let ((tmp (and (not djvu-image-mode)
                  (get-text-property (point-min) 'display))))
    (djvu-image)
    ;; Go to DPOS if we disable `djvu-image-mode'.
    (if tmp (djvu-goto-read (djvu-ref read-pos)))))

(defun djvu-image (&optional isize)
  "If `djvu-image-mode' is enabled, display image of current Djvu page.
Otherwise remove the image."
  ;; Strange!  `djvu-image' modifies the buffer (its text properties).
  ;; Nonetheless, we end up with an unmodified buffer.  This holds,
  ;; in particular, for the "bare" calls of `djvu-image' by
  ;; `djvu-image-zoom-in' and `djvu-image-zoom-out'.
  (if (not djvu-image-mode)
      (if (get-text-property (point-min) 'display)
          (let (buffer-read-only)
            (remove-text-properties (point-min) (point-max) '(display nil))))
    ;; Update image if necessary.
    (if (or (not (eq (djvu-ref page) (car (djvu-ref image))))
            (and isize
                 (not (eq isize (nth 1 (djvu-ref image))))))
        (let* ((isize (or isize
                         (nth 1 (djvu-ref image))
                         djvu-image-size))
               (scaling-factor (/ isize (float (cdr djvu-doc-pagesize))))
               (doc djvu-doc)
               (inhibit-quit t))
          (djvu-annots-listify)
          (with-temp-buffer
            (set-buffer-multibyte nil)
            (let* ((coding-system-for-read 'raw-text)
                   ;; For a rectangular image, ISIZE does not give us
                   ;; the actual size of the image, but (max width height)
                   ;; will be equal to ISIZE.
                   (status (call-process "ddjvu" nil t nil
                                         (format "-size=%dx%d" isize isize)
                                         "-format=ppm"
                                         (format "-page=%d" (djvu-ref page doc))
                                         (djvu-ref file doc))))
              (djvu-annots-draw isize scaling-factor)
              (unless (zerop status)
                (error "Ddjvu error %s" status))
              (djvu-set image
               (append (list (djvu-ref page doc) isize)
                       ;; Images are lists
                       (create-image (buffer-substring-no-properties
                                      (point-min) (point-max))
                                     'pbm t))
               doc)))))
    ;; Display image.
    (let (buffer-read-only)
      (if (= (point-min) (point-max)) (insert " "))
      (put-text-property (point-min) (point-max)
                         'display (nthcdr 2 (djvu-ref image))))))

(defun djvu-mouse-drag-track-area (start-event &optional line)
  "Track drag over image."
  (interactive "e")
  ;; Inspired by `mouse-drag-track'.
  (setq track-mouse t)
  (set-transient-map
     (let ((map (make-sparse-keymap)))
       (define-key map [mouse-movement]
         (lambda (event) (interactive "e")
           (djvu-with-event-buffer event
             (djvu-image-rect (list 'down-mouse-1
                                    (event-start start-event)
                                    (event-end event))
                              line))))
       map)
     t (lambda ()
         (setq track-mouse nil))))

(defun djvu-image-rect (&optional event line)
  "For PPM image specified via EVENT mark rectangle by inverting bits."
  ;; FIXME: Can the following be implemented more efficiently in the
  ;; image display code?  Could this be useful for other packages, too?
  (if event
      (let* ((e-start (event-start event))
             (e-end   (event-end   event))
             (_ (unless (and (posn-image e-start) (posn-image e-end))
                  (user-error "Area not over image")))
             (start (posn-object-x-y e-start))
             (end   (posn-object-x-y e-end))
             (x1 (if line (car start)
                   (min (car start) (car end))))
             (y1 (if line (cdr start)
                   (min (cdr start) (cdr end))))
             (x2 (if line (car end)
                   (max (car start) (car end))))
             (y2 (if line (cdr end)
                   (max (cdr start) (cdr end))))
             (image (copy-sequence (nth 6 (djvu-ref image))))
             (_ (unless (string-match "\\`P6\n\\([0-9]+\\) +\\([0-9]+\\)\n\\([0-9]+\\)\n" image)
                  (error "Not a PPM image")))
             (width (djvu-match-number 1 image))
             ; (height (djvu-match-number 2 image))
             (depth (djvu-match-number 3 image))
             (i0 (match-end 0))
             (old-image (get-text-property (point-min) 'display)))
        (unless (= depth 255)
          (error "Cannot handle depth %d" depth))
        (cl-flet ((invert (i imax)
                          (while (< i imax)
                            ;; Invert bits
                            (aset image i (- 255 (aref image i)))
                            (setq i (1+ i)))))
          (if (not line)
              (while (< y1 y2)
                ;; i = i0 + 3 * (y * width + x)
                (let ((i (+ i0 (* 3 (+ x1 (* width y1))))))
                  (invert i (+ i (* 3 (- x2 x1)))))
                (setq y1 (1+ y1)))
            (cond ((eq line 'horiz) (setq y2 y1))
                  ((eq line 'vert)  (setq x2 x1)))
            (if (< (abs (- x2 x1)) (abs (- y2 y1)))
                (let ((dx (/ (- x2 x1) (float (- y2 y1))))
                      (y y1) (step (cl-signum (- y2 y1))))
                  (while (/= y y2)
                    ;; x = (y - y1) * dx + x1
                    (let ((i (+ i0 (* 3 (+ (* y width) x1
                                           (round (* (- y y1) dx)))))))
                      (invert i (+ i 3)))
                    (setq y (+ y step))))
              (let ((dy (/ (- y2 y1) (float (- x2 x1))))
                    (x x1) (step (cl-signum (- x2 x1))))
                (while (/= x x2)
                  ;; y = (x - x1) * dy + y1
                  (let ((i (+ i0 (* 3 (+ x (* (+ y1 (round (* (- x x1) dy)))
                                              width))))))
                    (invert i (+ i 3)))
                  (setq x (+ x step)))))))
        (with-silent-modifications
          (put-text-property
           (point-min) (point-max) 'display
           (create-image image 'pbm t)))
        (image-flush old-image))
    ;; Restore unmodified image
    (let ((old-image (get-text-property (point-min) 'display)))
      (with-silent-modifications
        (put-text-property (point-min) (point-max)
                           'display (nthcdr 2 (djvu-ref image))))
      (image-flush old-image))))

(defun djvu-image-zoom-in ()
  (interactive)
  (djvu-image (round (* (nth 1 (djvu-ref image)) 1.2))))

(defun djvu-image-zoom-out ()
  (interactive)
  (djvu-image (round (/ (nth 1 (djvu-ref image)) 1.2))))

(defun djvu-event-to-area (event &optional sorted)
  "Convert mouse EVENT to Djvu area coordinates."
  (let* ((e-start (event-start event))
         (e-end   (event-end   event))
         (_ (unless (and (posn-image e-start) (posn-image e-end))
              (user-error "Area not over image")))
         (start (posn-object-x-y e-start))
         (end   (posn-object-x-y e-end))
         (x1 (car start)) (y1 (cdr start)) (x2 (car end)) (y2 (cdr end))
         (size (posn-object-width-height e-start))
         (_ (if (equal size '(0 . 0))
                (error "See Emacs bug#18839 (GNU Emacs 24.4)")))
         (width  (/ (float (car (djvu-ref pagesize))) (car size)))
         (height (/ (float (cdr (djvu-ref pagesize))) (cdr size)))
         (area
          (list (round (* (if sorted (min x1 x2) x1) width))
                (round (* (- (cdr size) (if sorted (max y1 y2) y1)) height))
                (round (* (if sorted (max x1 x2) x2) width))
                (round (* (- (cdr size) (if sorted (min y1 y2) y2)) height)))))
    (djvu-set read-pos (djvu-mean-dpos area))
    area))

(defun djvu-mouse-rect-area (event)
  (interactive "e")
  ;; Mouse events ignore prefix args?
  (djvu-with-event-buffer event
    (djvu-image-rect event)
    (let ((color (djvu-interactive-color djvu-color-highlight)))
      (djvu-rect-area nil (read-string (format "(%s) Highlight: " color)
                                      nil nil nil djvu-inherit-input-method)
                      (list (djvu-event-to-area event t))
                      color djvu-opacity 'none))
    (djvu-image-rect)
    (djvu-set image nil)
    (djvu-image-toggle)
    (djvu-image-toggle)
    ))

(defun djvu-mouse-text-area (event)
  (interactive "e")
  (djvu-mouse-text-area-internal event "Text"))

(defun djvu-mouse-text-area-pushpin (event)
  (interactive "e")
  (djvu-mouse-text-area-internal event "Text w/Pushpin" t))

(defun djvu-mouse-text-area-internal (event prompt &optional pushpin)
  ;; Mouse events ignore prefix args?
  (djvu-with-event-buffer event
    (djvu-image-rect event)
    (let ((color (djvu-interactive-color djvu-color-highlight)))
      (djvu-text-area nil (read-string (format "(%s) %s: " color prompt)
                                      nil nil nil djvu-inherit-input-method)
                      (djvu-event-to-area event t) nil
                      (djvu-color-background color)
                      nil pushpin))
    (djvu-image-rect)
    (djvu-set image nil)
    (djvu-image-toggle)
    (djvu-image-toggle)
))

(defun djvu-mouse-line-area (event)
  (interactive "e")
  (djvu-mouse-line-area-internal event))

(defun djvu-mouse-line-area-horiz (event)
  (interactive "e")
  (djvu-mouse-line-area-internal event 'horiz))

(defun djvu-mouse-line-area-vert (event)
  (interactive "e")
  (djvu-mouse-line-area-internal event 'vert))

(defun djvu-mouse-line-area-arrow (event)
  (interactive "e")
  (djvu-mouse-line-area-internal event 'arrow))

(defun djvu-mouse-line-area-internal (event &optional dir)
  (djvu-with-event-buffer event
    (let* ((line (djvu-event-to-area event))
           (color (djvu-interactive-color djvu-color-line))
           (text (read-string (format "(%s) Line: " color)
                              nil nil nil djvu-inherit-input-method)))
      (cond ((eq dir 'horiz)
             (setq line (list (nth 0 line) (nth 1 line)
                              (nth 2 line) (nth 1 line))))
            ((eq dir 'vert)
             (setq line (list (nth 0 line) (nth 1 line)
                              (nth 0 line) (nth 3 line)))))
      (if (eq dir 'arrow)
          (djvu-line-area nil text line nil t djvu-line-width djvu-color-line)
        (djvu-line-area nil text line nil nil djvu-line-width djvu-color-line))
      (djvu-set image nil)
      (djvu-image-toggle)
      (djvu-image-toggle)
)))

(defun djvu-line-area (url text line &optional border arrow width lineclr)
  ;; Record position where annotation was made.
  (with-current-buffer (djvu-ref annot-buf)
    (goto-char (point-max))
    ;; It seems that TEXT is ignored by djview.
    (insert (format "(maparea %S\n %S\n "
                    (or url "") (if text (djvu-fill text) ""))
            (apply 'format "(line %d %d %d %d)" (djvu-bound-area line))
            ;; According to Sec. 8.3.4.2.3.1 of djvu3spec.djvu
            ;; lines may have border options.
            ;; Man djvused: Border options do not apply to line areas.
            (format " (%s)" (or border 'none))
            (if arrow " (arrow)" "")
            (if width (format " (width %d)" width) "")
            (djvu-insert-color "lineclr" lineclr)
            ")\n\n")
    (undo-boundary)))

(defun djvu-mouse-word-area (event)
  "Insert word."
  (interactive "e")
  (with-current-buffer (djvu-with-event-buffer event
                         (djvu-ref text-buf))
    (goto-char (point-max))
    (skip-chars-backward " \t\n")
    (backward-char) ; ")"
    (let ((area (djvu-bound-area (djvu-event-to-area event t))))
      (insert (apply 'format "\n (line %d %d %d %d\n" area)
              (apply 'format "  (word %d %d %d %d" area)
              (format " %S))" (read-string "Word: " nil nil nil
                                           djvu-inherit-input-method))))))

;;; Miscellaneous commands

(defun djvu-interactive-pages (&optional doc)
  "Specify page range to operate on in interactive calls.
Without a prefix, return nil meaning \"all pages\".
Otherwise return a cons pair (PAGE1 . PAGE2).
With prefix C-u, this becomes the current page.
With prefix C-u C-u, read page range from minibuffer."
  (let ((pages (cond ((equal '(16) current-prefix-arg)
                      (cons (read-number "First page: " 1)
                            (read-number "Last page: "
                                         (djvu-ref pagemax doc))))
                     (current-prefix-arg
                      (cons (djvu-ref page doc) (djvu-ref page doc))))))
    ;; Return cons (STRING . PAGES).
    (cons (if pages
              (if (eq (car pages) (cdr pages))
                  (if (eq (car pages) (djvu-ref page doc)) "current page"
                    (format "page %d" (car pages)))
                (format "pages %d-%d" (car pages) (cdr pages)))
            "all pages")
          pages)))

(defun djvu-pages-action (pages action doc)
  "Apply ACTION to PAGES of Djvu document DOC.
If PAGES is nil, operate on all pages.
Otherwise PAGES is a cons pair (PAGE1 . PAGE2)."
  (unless doc (setq doc djvu-doc))
  (djvu-save doc t)
  (if pages
      (djvu-djvused doc nil "-e"
                    (mapconcat
                     (lambda (page)
                       (format "select %s; %s" page action))
                     (number-sequence
                      (max 1 (car pages))
                      (min (djvu-ref pagemax doc) (cdr pages)))
                     "; ")
                    "-s")
    (djvu-djvused doc nil "-e"
                  (format "select; %s" action)
                  "-s")))

(defun djvu-dpi (dpi &optional pages doc)
  "Set DPI resolution of djvu document DOC.
If optional arg PAGES is nil, operate on all pages.
Otherwise PAGES is a cons pair (PAGE1 . PAGE2).
With prefix C-u, PAGES becomes the current page.
With prefix C-u C-u, read range PAGES from minibuffer."
  ;; PAGES could also be a proper list.  Useful??
  (interactive
   (let ((pages (djvu-interactive-pages)))
     (list (read-number (format "(%s) Dpi: " (car pages)))
           (cdr pages))))
  (djvu-pages-action pages (format "set-dpi %d" dpi) doc))

(defun djvu-dpi-unify (width dpi &optional doc)
  "Unify the ratio WIDTH / DPI of all pages of a Djvu document.
If the width of a page exceeds WIDTH, increase the page resolution DPI
accordingly."
  (interactive "nWidth: \nnWidth: %s, dpi: ")
  (unless doc (setq doc djvu-doc))
  (let ((count 0) job)
    (with-temp-buffer
      (djvu-djvused doc t "-e" "size")
      (goto-char (point-min))
      (let ((page 0))
        (while (looking-at "width=\\([[:digit:]]+\\)")
          (setq page (1+ page))
          (let ((w (djvu-match-number 1)))
            (when (< width w)
              (push (cons page (/ (* w dpi) width)) job)
              (setq count (1+ count))))
          (forward-line))))
    (if (not job)
        (message "Nothing to unify")
      (djvu-djvused doc nil "-e"
                    (mapconcat (lambda (elt)
                                 (format "select %s; set-dpi %d"
                                         (car elt) (cdr elt)))
                               job "; ")
                    "-s")
      (message "%s pages updated: %s" count
               (mapconcat (lambda (elt) (format "%d" (car elt)))
                          (nreverse job) ", ")))))

(defun djvu-rotate (&optional rot pages doc)
  "Set rotation of Djvu document DOC.
The rotation angle ROT is in multiples of 90 degrees counterclockwise.
If string ROT has prefix [+-] apply relative rotation.
If optional arg PAGES is nil, operate on all pages.
Otherwise PAGES is a cons pair (PAGE1 . PAGE2).
With prefix C-u, PAGES becomes the current page.
With prefix C-u C-u, read range PAGES from minibuffer."
  (interactive
   (let ((pages (djvu-interactive-pages)))
     (list (read-string
            (format "(%s) Rotate ([+-]0...3, default +1): " (car pages))
            nil nil "+1")
           (cdr pages))))
  (cond ((or (not rot) (equal rot ""))
         (setq rot "+1"))
        ((not (string-match "\\`[-+]?[0123]\\'" rot))
         (user-error "Djvu rotation `%s' invalid" rot)))
  (djvu-pages-action pages (format "set-rotation %s" rot) doc))

(defun djvu-page-title (title &optional pages doc)
  "Set page TITLE of Djvu document DOC.
If TITLE is empty string or nil remove page title.
If optional arg PAGES is nil, operate on all pages.
Otherwise PAGES is a cons pair (PAGE1 . PAGE2).
With prefix C-u, PAGES becomes the current page.
With prefix C-u C-u, read range PAGES from minibuffer."
  ;; Fixme: we could also generate some generic distinct title
  ;; for each page.  Is this useful?
  (interactive
   (let ((pages (djvu-interactive-pages)))
     (list (read-string (format "(%s) Page title: " (car pages)))
           (cdr pages))))
  (unless doc (setq doc djvu-doc))
  (if (and (stringp title)
           (not (equal "" title)))
      ;; set-page-title only operates on individual pages,
      ;; though page titles need not be distinct.
      (djvu-pages-action (or pages (cons 1 (djvu-ref pagemax doc)))
                         (format "set-page-title %s" title) doc)
    ;; Remove page titles:
    ;; djvused does not have a command remove-page-title.
    ;; Instead for each page we must set the page title to the page-id.
    (djvu-save doc t)
    (djvu-djvused doc nil "-e"
                  (mapconcat (lambda (page)
                               (format "select %d; set-page-title %s" page
                                       (cdr (assq page (djvu-ref page-id doc)))))
                             (number-sequence (or (car pages) 1)
                                              (or (cdr pages) (djvu-ref pagemax doc)))
                             "; ")
                  "-s")))

(defun djvu-ls (&optional doc)
  "List component files in the Djvu document.
This uses the command \"djvused doc.djvu -e ls\"."
  (interactive)
  (let ((buffer (get-buffer-create "*djvu-ls*"))
        (doc (or doc djvu-doc)))
    (with-current-buffer buffer
      (let ((buffer-undo-list t)
            buffer-read-only)
        (erase-buffer)
        (djvu-djvused doc t "-e" "ls"))
      (set-buffer-modified-p nil)
      (setq buffer-read-only t)
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

;;;###autoload
(defun djvu-inspect-file (file &optional page)
  "Inspect Djvu FILE on PAGE.
Call djvused with the same sequence of arguments that is used
by `djvu-init-page'.  Display the output in `djvu-script-buffer'.
This may come handy if `djvu-find-file' chokes on a Djvu file."
  (interactive (djvu-read-file-name))
  (with-current-buffer (get-buffer-create djvu-script-buffer)
    (erase-buffer)
    (let* ((coding-system-for-read 'utf-8)
           (fmt (concat "create-shared-ant; print-ant; n; ls; print-outline; "
                        "select %d; size; print-txt; print-ant;"))
           (status (apply 'call-process "djvused" nil t nil
                          (list "-u" file "-e" (format fmt (or page 1))))))
      (unless (zerop status)
        (error "Djvused error %s" status)))
    (set-buffer-modified-p nil)
    (goto-char (point-min)))
  (pop-to-buffer djvu-script-buffer))

;;; Destructive commands: use with care!

(defun djvu-delete-page (&optional doc)
  "Delete current page from the Djvu document.  Use with care!"
  (interactive)
  (unless doc (setq doc djvu-doc))
  (djvu-save doc t)
  (when (and (< 1 (djvu-ref pagemax doc))
             (yes-or-no-p "Delete current page "))
    ;; We resolve all internal URLs to `long'.
    ;; So those URLs pointing to pages that are not deleted remain valid.
    ;; Internal URLs pointing to the deleted page become meaningless.
    ;; We do not worry about this here and now as it is harmless.
    ;; Yet `djvu-unresolve-url' will issue a warning message next time
    ;; such a meaningless internal URL is read or stored again.
    (djvu-resolve-all-urls 'long doc)
    (djvu-backup doc)
    (let* ((inhibit-quit t)
           (page (djvu-ref page doc))
           (status (call-process "djvm" nil nil nil "-d"
                                 (djvu-ref file doc) (number-to-string page))))
      (unless (zerop status) (error "Djvm error %s" status))
      (djvu-all-buffers doc
        (set-visited-file-modtime))
      ;; Update internal variables
      (djvu-set image nil doc)
      (let ((page-id (delq (assq page (djvu-ref page-id doc))
                           (djvu-ref page-id doc)))
            (p (1+ page))
            p-i)
        (while (<= p (djvu-ref pagemax doc))
          (setq p-i (assq p page-id)
                page-id (cons (cons (1- p) (cdr p-i))
                              (delq p-i page-id))
                p (1+ p)))
        (djvu-set page-id page-id doc))
      (djvu-set pagemax (1- (djvu-ref pagemax doc)) doc)
      ;; Redisplay
      (djvu-init-page (min page (djvu-ref pagemax doc)) doc))))

(defun djvu-remove-annot (&optional doc outline)
  "Remove Annotations.  Use with care!
With prefix OUTLINE non-nil remove Outline, too."
  (interactive (list nil current-prefix-arg))
  (unless doc (setq doc djvu-doc))
  (djvu-save doc t)
  (when (yes-or-no-p (format "Remove Annotations%s: "
                             (if outline " and Outline" "")))
    (djvu-djvused doc nil "-e"
                  (format "select; remove-ant;%s"
                          (if outline " set-outline;\n." ""))
                  "-s")
    (djvu-init-page nil doc)))

;;;; Emacs bookmark integration (inspired by doc-view.el)

(declare-function bookmark-make-record-default "bookmark"
                  (&optional no-file no-context posn))
(declare-function bookmark-prop-get "bookmark" (bookmark prop))
(declare-function bookmark-get-filename "bookmark" (bookmark))
(declare-function bookmark-get-front-context-string "bookmark" (bookmark))
(declare-function bookmark-get-rear-context-string "bookmark" (bookmark))
(declare-function bookmark-get-position "bookmark" (bookmark))

(defun djvu-bookmark-make-record ()
  (nconc (bookmark-make-record-default)
         `((page . ,(djvu-ref page))
           (d-buffer . ,djvu-buffer)
           (handler . djvu-bookmark-handler))))

;; Adapted from `bookmark-default-handler'.
;;;###autoload
(defun djvu-bookmark-handler (bmk)
  "Handler to jump to a particular bookmark location in a djvu document.
BMK is a bookmark record, not a bookmark name (i.e., not a string).
Changes current buffer and point and returns nil, or signals a `file-error'."
  (let ((file          (bookmark-get-filename bmk))
	(buf           (bookmark-prop-get bmk 'buffer))
        (d-buffer      (bookmark-prop-get bmk 'd-buffer))
        (page          (bookmark-prop-get bmk 'page))
        (forward-str   (bookmark-get-front-context-string bmk))
        (behind-str    (bookmark-get-rear-context-string bmk))
        (pos           (bookmark-get-position bmk)))
    (set-buffer
     (cond
      ((and file (file-readable-p file) (not (buffer-live-p buf)))
       (find-file-noselect file))
      ;; No file found.  See if buffer BUF has been created.
      ((and buf (get-buffer buf)))
      (t ;; If not, raise error.
       (signal 'bookmark-error-no-filename (list 'stringp file)))))
    (if page (djvu-goto-page page))
    (if d-buffer
        (set-buffer
         (pcase d-buffer
           (`read (djvu-ref read-buf))
           (`text (djvu-ref text-buf))
           (`annot (djvu-ref annot-buf))
           (`shared (djvu-ref shared-buf))
           (`bookmarks (djvu-ref bookmarks-buf))
           (`outline (djvu-ref outline-buf)))))
    (if pos (goto-char pos))
    ;; Go searching forward first.  Then, if forward-str exists and
    ;; was found in the file, we can search backward for behind-str.
    ;; Rationale is that if text was inserted between the two in the
    ;; file, it's better to be put before it so you can read it,
    ;; rather than after and remain perhaps unaware of the changes.
    (when (and forward-str (search-forward forward-str (point-max) t))
      (goto-char (match-beginning 0)))
    (when (and behind-str (search-backward behind-str (point-min) t))
      (goto-char (match-end 0)))
    nil))



;;;; ChangeLog:

;; 2019-06-17  Roland Winkler  <winkler@gnu.org>
;; 
;; 	* packages/djvu/djvu.el: Release v1.1.
;; 
;; 2019-01-01  Roland Winkler  <winkler@gnu.org>
;; 
;; 	djvu.el: be compatible with uniquify
;; 
;; 2018-12-27  Roland Winkler  <winkler@gnu.org>
;; 
;; 	Release djvu.el v1.0
;; 
;; 2016-07-11  Paul Eggert	 <eggert@cs.ucla.edu>
;; 
;; 	Fix some quoting problems in doc strings
;; 
;; 	Most of these are minor issues involving, e.g., quoting `like this' 
;; 	instead of 'like this'.	 A few involve escaping ` and ' with a preceding
;; 	\= when the characters should not be turned into curved single quotes.
;; 
;; 2012-03-24  Chong Yidong  <cyd@gnu.org>
;; 
;; 	Commentary fix for quarter-plane.el.
;; 
;; 2011-11-01  Roland Winkler  <winkler@gnu.org>
;; 
;; 	Small bugfixes
;; 
;; 2011-10-29  Roland Winkler  <winkler@gnu.org>
;; 
;; 	new package djvu.el
;; 

(provide 'djvu)
;;; djvu.el ends here
