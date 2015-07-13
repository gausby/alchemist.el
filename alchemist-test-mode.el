;;; alchemist-test-mode.el --- Minor mode for Elixir test files.

;; Copyright © 2015 Samuel Tonini

;; Author: Samuel Tonini <tonini.samuel@gmail.com

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Minor mode for Elixir test files.

;;; Code:

(require 'ansi-color)

(defgroup alchemist-test-mode nil
  "Minor mode for Elixir ExUnit files."
  :prefix "alchemist-test-mode-"
  :group 'alchemist)

;; Variables

(defvar alchemist-test-report-buffer-name "*alchemist-test-report*"
  "Name of the test report buffer.")

(defcustom alchemist-test-mode-highlight-tests t
  "Non-nil means that specific functions for testing will
be highlighted with more significant font faces."
  :type 'boolean
  :group 'alchemist-test-mode)

(defvar alchemist-test-at-point #'alchemist-mix-test-at-point)
(defvar alchemist-test-this-buffer #'alchemist-mix-test-this-buffer)
(defvar alchemist-test #'alchemist-mix-test)
(defvar alchemist-test-file #'alchemist-mix-test-file)
(defvar alchemist-test-jump-to-previous-test #'alchemist-test-mode-jump-to-previous-test)
(defvar alchemist-test-jump-to-next-test #'alchemist-test-mode-jump-to-next-test)
(defvar alchemist-test-list-tests #'alchemist-test-mode-list-tests)

(defvar alchemist-test-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c , s") alchemist-test-at-point)
    (define-key map (kbd "C-c , v") alchemist-test-this-buffer)
    (define-key map (kbd "C-c , a") alchemist-test)
    (define-key map (kbd "C-c , f") alchemist-test-file)
    (define-key map (kbd "C-c , p") alchemist-test-jump-to-previous-test)
    (define-key map (kbd "C-c , n") alchemist-test-jump-to-next-test)
    (define-key map (kbd "C-c , l") alchemist-test-list-tests)
    map)
  "Keymap for `alchemist-test-mode'.")

(defvar alchemist-test-mode--test-regex
  (let ((whitespace-opt "[[:space:]]*")
        (whitespace "[[:space:]]+"))
    (concat "\\(^" whitespace-opt "test" whitespace "\\(?10:.+\\)" whitespace "do" whitespace-opt "$"
            "\\|"
            whitespace " [0-9]+) test .+\\)")))

;; Private functions

(defun alchemist-test--sential (process event)
  (cond ((string-match-p "finished" event)
         (with-current-buffer (process-buffer process)))))

(defun alchemist-test--ansi-color-insertion-filter (proc string)
  (with-current-buffer (process-buffer proc)
    (let* ((buffer-read-only nil)
          (moving (= (point) (process-mark proc))))
      (save-excursion
        (goto-char (process-mark proc))
        (insert string)
        (set-marker (process-mark proc) (point))
        (ansi-color-apply-on-region (point-min) (point-max)))
      (if moving (goto-char (process-mark proc))))))

(defun alchemist-test--cleanup-report ()
  (let ((buffer (get-buffer alchemist-test-report-buffer-name)))
    (kill-buffer buffer)))

(defun alchemist-test-mode--buffer-contains-tests-p ()
  "Return nil if the current buffer contains no tests, non-nil if it does."
  (alchemist-utils--regex-in-buffer-p (current-buffer) alchemist-test-mode--test-regex))

(defun alchemist-test-mode--tests-in-buffer ()
  "Return an alist of tests in this buffer.

The keys in the list are the test names (e.g., the string passed to the test/2
macro) while the values are the position at which the test matched."
  (save-match-data
    (save-excursion
      (goto-char (point-min))
      (let ((tests '()))
        (while (re-search-forward alchemist-test-mode--test-regex nil t)
          (let* ((position (car (match-data)))
                 (matched-string (match-string 10)))
            (set-text-properties 0 (length matched-string) nil matched-string)
            (add-to-list 'tests (cons matched-string position) t)))
        tests))))

(defun alchemist-test-mode--highlight-syntax ()
  (if alchemist-test-mode-highlight-tests
      (font-lock-add-keywords nil
                              '(("^\s+\\(test\\)\s+" 1
                                 font-lock-variable-name-face t)
                                ("^\s+\\(assert[_a-z]*\\|refute[_a-z]*\\)\s+" 1
                                 font-lock-type-face t)
                                ("^\s+\\(assert[_a-z]*\\|refute[_a-z]*\\)\(" 1
                                 font-lock-type-face t)))))

;; Public functions

(defun alchemist-test-mode-jump-to-next-test ()
  "Jump to the next ExUnit test. If there are no tests after the current
position, jump to the first test in the buffer. Do nothing if there are no tests
in this buffer."
  (interactive)
  (alchemist-utils--jump-to-next-matching-line alchemist-test-mode--test-regex 'back-to-indentation))

(defun alchemist-test-mode-jump-to-previous-test ()
  "Jump to the previous ExUnit test. If there are no tests before the current
position, jump to the last test in the buffer. Do nothing if there are no tests
in this buffer."
  (interactive)
  (alchemist-utils--jump-to-previous-matching-line alchemist-test-mode--test-regex 'back-to-indentation))

(defun alchemist-test-mode-list-tests ()
  "List ExUnit tests (calls to the test/2 macro) in the current buffer and jump
to the selected one."
  (interactive)
  (let* ((tests (alchemist-test-mode--tests-in-buffer))
         (selected (completing-read "Test: " tests))
         (position (cdr (assoc selected tests))))
    (goto-char position)
    (back-to-indentation)))

;;;###autoload
(define-minor-mode alchemist-test-mode
  "Minor mode for Elixir ExUnit files.

The following commands are available:

\\{alchemist-test-mode-map}"
  :lighter ""
  :keymap alchemist-test-mode-map
  :group 'alchemist
  (when alchemist-test-mode
    (alchemist-test-mode--highlight-syntax)))

;;;###autoload
(defun alchemist-test-enable-mode ()
  (if (alchemist-utils--is-test-file-p)
      (alchemist-test-mode)))

;;;###autoload
(dolist (hook '(alchemist-mode-hook))
  (add-hook hook 'alchemist-test-enable-mode))

(defvar alchemist-test-report-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "q" #'quit-window)
    map))

(defun alchemist-test--display-report-buffer (buffer)
  (with-current-buffer buffer
    (alchemist-test-report-mode))
  (display-buffer buffer))

(define-derived-mode alchemist-test-report-mode fundamental-mode "Alchemist Test Report"
  "Major mode for presenting Elixir test results.

\\{alchemist-test-report-mode-map}"
  (setq buffer-read-only t)
  (setq-local truncate-lines t)
  (setq-local electric-indent-chars nil))

(defun  alchemist-test-execute (command-list)
  (alchemist-test--cleanup-report)
  (message "Testing...")
  (let* ((buffer (get-buffer-create alchemist-test-report-buffer-name))
         (project-root (alchemist-project-root))
         (default-directory (if project-root
                                project-root
                              default-directory))
         (command (mapconcat 'concat command-list " "))
         (process (start-process-shell-command "alchemist-test-report" buffer command)))
    (set-process-sentinel process 'alchemist-test--sential)
    (set-process-filter process 'alchemist-test--ansi-color-insertion-filter)
    (alchemist-test--display-report-buffer buffer)))

(provide 'alchemist-test-mode)

;;; alchemist-test-mode.el ends here
