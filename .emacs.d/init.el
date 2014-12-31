(global-set-key [f2] 'save-some-buffers)
(global-set-key [f5] 'other-window)
(global-set-key [f6] 'sr-speedbar-toggle)
(global-set-key (kbd "C-`")
		(lambda () (interactive)
          (switch-to-buffer (other-buffer))))
(global-set-key (kbd "C-S-K") 'kill-whole-line)
(global-set-key (kbd "C-S-A") 'mark-whole-buffer)

(setq-default indent-tabs-mode nil)

(global-visual-line-mode)
(column-number-mode)
(size-indication-mode)
(require 'paren)
(set-face-foreground 'show-paren-match-face "#def")
(set-face-attribute 'show-paren-match-face nil :weight 'extra-bold)
(show-paren-mode)

; don't ask confirmation on saving all buffers
(add-hook 'find-file-hook (lambda () (setq buffer-save-without-query t)))

; duplicate line
(defun duplicate-line()
  (interactive)
  (move-beginning-of-line 1)
  (kill-line)
  (yank)
  (open-line 1)
  (next-line 1)
  (yank)
)
(global-set-key "\C-c\C-d" 'duplicate-line)

(defun disable-backups-hook ()
  "My hook for disabling backups. "
  (setq backup-inhibited t)
  (setq auto-save-default nil)
  )

; enter and indent
(defun my-coding-config ()
  (local-set-key (kbd "RET") (key-binding (kbd "M-j")))
  (local-set-key (kbd "<S-return>") 'newline)
  (local-set-key (kbd "<f7>") 'ack)
  (setq indent-tabs-mode nil)
  (setq tab-width 4)
  (sr-speedbar-open)
  (linum-mode))

(disable-backups-hook)
;(add-hook 'before-save-hook 'delete-trailing-whitespace)
(scroll-bar-mode -1)
(tool-bar-mode -1)

(setq inhibit-splash-screen t)

(when window-system
   (set-frame-size (selected-frame) 130 44)
)

(mapc
 (lambda (language-mode-hook)
   (add-hook language-mode-hook 'my-coding-config))
 '(cperl-mode-hook
   perl-mode-hook
   css-mode-hook
   emacs-lisp-mode-hook
   js-mode-hook
   c-mode-hook
   glsl-mode-hook
   emacs-lisp-mode-hook
   ;; etc...
   ))


;;;;; extenstions
(add-to-list 'load-path "~/.emacs.d/custom-lisp/")

;;; extenstion: smart-tab
(require 'smart-tab)
(global-smart-tab-mode 1)

;;; extenstion: web-mode
(require 'web-mode)
(add-to-list 'auto-mode-alist '("\\.html?\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.php\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.html.ep\\'" . web-mode))

;;; extenstion: markdown-mode
(autoload 'markdown-mode "markdown-mode"
   "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.text\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))

;;; extenstion: glsl-mode
(autoload 'glsl-mode "glsl-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.glsl\\'" . glsl-mode))

;;; extenstion: cperl-mode
(require 'cperl-mode)
(add-to-list 'auto-mode-alist '("\\.t\\'" . cperl-mode))
(add-to-list 'auto-mode-alist '("\\.psgi\\'" . cperl-mode))

(defun cperl-backward-to-start-of-continued-exp (lim)
  (goto-char (1+ lim))
  (forward-sexp)
  (beginning-of-line)
  (skip-chars-forward " \t")
  )

(defalias 'perl-mode 'cperl-mode)
(add-hook 'cperl-mode-hook
	  (lambda ()
	    (setq cperl-indent-level 4
		  cperl-close-paren-offset -4
		  cperl-continued-statement-offset 4
		  cperl-indent-parens-as-block t
		  cperl-tab-always-indent t)
	    (setq cperl-hairy t) ;; Turns on most of the CPerlMode options
	    (defvaralias 'c-basic-offset 'tab-width)
	    (defvaralias 'cperl-indent-level 'tab-width)
	    (local-set-key (kbd "{") 'cperl-electric-paren)
	    (local-set-key (kbd "}") 'cperl-electric-rparen)
	    (my-coding-config)
	    ))

;;; extenstion: sr-speedbar
(require 'sr-speedbar)
(setq speedbar-show-unknown-files t)
;(sr-speedbar-open)

;;;;; customizations

; don't ask confirmation on exit
(defun my-kill-emacs ()
  "save some buffers, then exit unconditionally"
  (interactive)
  (save-some-buffers nil t)
  (kill-emacs))
(global-set-key (kbd "C-x C-c") 'my-kill-emacs)

(custom-set-variables
 '(custom-enabled-themes (quote (wombat)))
 '(js-indent-level 2)
 '(nil nil t)
 '(speedbar-after-create-hook (quote (speedbar-frame-reposition-smartly my-speedbar-hook)))
 '(speedbar-before-popup-hook (quote (my-speedbar-hook)))
 '(speedbar-directory-button-trim-method (quote trim))
 '(speedbar-directory-unshown-regexp "'"))
(custom-set-faces
 '(cperl-array-face ((t (:background "navy" :foreground "yellow"))))
 '(cperl-hash-face ((t (:background "navy" :foreground "Red"))))
)
