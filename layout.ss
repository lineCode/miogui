;; * MIOGUI *
;;
;; Copyright 2016 Aldo Nicolas Bruno
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

(import (only (srfi s1 lists) fold))

;(define layout-state (make-eq-hashtable))

(define (get-last-coords id)
  (check-arg symbol? id get-last-coords)

  (let ([e (hashtable-ref old-element-table id #f)])
    (if e 
	(parameterize ([mi-el e])
		      (values (mi-x) (mi-y) (mi-w) (mi-h)))
	(values 0 0 0 0))))

;; flex-direction: row(default)|row-reverse|column|column-reverse|initial|inherit;
;; justify-content: flex-start (default) | flex-end | center | space-between | space-around
;; align-items: flex-start (default) | flex-end | center | baseline | stretch
;; flex-wrap: nowrap (default) | wrap | wrap-reverse
;; align-content: stretch (default) | flex-start | flex-end | center | space-between | space-around
;; flex: number. where number will be used to do a proportion. default 1
;; =>>>WE DONT SUPPORT SUCH STUFF:  flex: flex-grow flex-shrink flex-basis|auto|initial|inherit; default: 0 1 auto
;; align-self: auto (default) | stretch  | flex-start | flex-end | center | space-between | space-around
(define (layout-flex parent)
  ;(printf "layout-flex ~d~n" parent)  (mi-element-id parent) (mi-element-children parent))
  (let ( [justify-content (mi-element-justify-content parent)]
	 [align-items (mi-element-align-items parent)]
	 [flex-direction (mi-element-flex-direction parent)] 
	 ;[direction (mi-element-direction parent)]
	 [children 
	  (sort (lambda (a b) 
		  (< (mi-element-order a) (mi-element-order b)))
		(reverse (mi-element-children parent)))]
	 [current-x 0] [current-y 0]
	 [p-w (- (mi-element-w parent) (* 2 (mi-element-padding parent)))]
	 [p-h (- (mi-element-h parent) (* 2 (mi-element-padding parent)))]
	 [p-x (+ (mi-element-padding parent ) (mi-element-x parent))]
	 [p-y (+ (mi-element-padding parent) (mi-element-y parent))]
	 [new-w 0] [new-h 0])
     (let ([total-w    (fold (lambda (e acc) (+ acc (mi-element-w e)))    0 children)]
	   [total-h    (fold (lambda (e acc) (+ acc (mi-element-h e)))    0 children)]
	   [flex-total (fold (lambda (e acc) (+ acc (mi-element-flex e))) 0 children)]
	   )
       (define (default-size e)
	 (let* ([csz (mi-element-content-size e)]
	        [w (mi-element-min-width e)]
		[h (mi-element-min-height e)])
	   (let-values ([(max-w max-h)
			 (if (list? csz)
			     (values (max w (+ (car csz) (* (mi-element-padding e) 2)))
				     (max h (+ (cadr csz) (* (mi-element-padding e) 2))))
			     (values w h))])
	     (cons max-w max-h))))
       (define n-w 1) ;; this will be needed when wrap 
       (define n-h 1)
       (define (calc-max-size l n)
	 (let loop ([count 0] [e l] [w 0] [h 0])
	   (if (or (null? e) (= count n)) 
	       (cons w h)
	       (let ([sz (default-size (car e))])
		 ;(printf "~d ~d~n" (mi-element-id (car e)) sz)
		 (loop (+ count 1) (cdr e) 
		       (max (* n-w p-w) w (car sz)) 
		       (max (* n-h p-h) h (cdr sz)))))))
       (define (calc-total-size l n)
	 (let loop ([count 0] [e l] [w 0] [h 0])
	   (if (or (null? e) (= count n)) 
	       (cons w h)
	       (let ([sz (default-size (car e))])
		 ;(printf "~d ~d~n" (mi-element-id (car e)) sz)
		 (loop (+ count 1) (cdr e) 
		       (+ w (car sz))
		       (+ h (cdr sz)))))))
       (let* (
	     ;; msz: this is a simplification. when we'll implement wrap then this 
	     ;; must be moved inside the for-each somehow
	      [dir? (case flex-direction [(row row-reverse) #t] [(column column-reverse) #f])] 
	      #;[reverse? (case flex-direction
			  [(column row) #f] 
			  [(column-reverse row-reverse) #t])] 
	      [n-items (length children)]
	      [msz (calc-max-size children n-items)]
	      [tsz (calc-total-size children n-items)]
	      [max-w (car msz)] [max-h (cdr msz)]
	      [tot-w (car tsz)] [tot-h (cdr tsz)]
	      [main-tot     (if dir? tot-w tot-h)]
	      [p-main-pos   (if dir? p-x   p-y)]
	      [p-main-size  (if dir? max-w max-h)]
	      [p-cross-pos  (if dir? p-y   p-x)] 
	      [p-cross-size (if dir? max-h max-w)]
	      [free-space (- p-main-size main-tot)]
	      [first-main-pos 
	       (case justify-content 
		 [(flex-start space-between) p-main-pos]
		 [flex-end (+ p-main-pos free-space)]
		 [center (+ p-main-pos (/ free-space 2))]
		 [space-around (+ p-main-pos (/ free-space (+ n-items 1)))])]
	      [next-main-pos first-main-pos]) 
	 ;(printf "main-tot: ~d p-main-size: ~d n-items ~d free-space: ~d first-main-pos ~d~n" main-tot  p-main-size n-items free-space first-main-pos)
      (for-each (lambda (e)
		  (let* ([align-self (mi-element-align-self e)] 
			 [flex (mi-element-flex e)]
			 [x 0] [y 0] [w (mi-element-w e)] [h (mi-element-h e)]
			 [dsz (default-size e)]
			 [main-pos   (if dir? x y)]
			 [main-size  (if dir? (car dsz) (cdr dsz))]
			 [cross-pos  (if dir? y x)]
			 [cross-size (if dir? (cdr dsz) (car dsz))])
		      ;; ALIGN-ITEMS : cross line alignment
			 (case (if (eq? align-self 'auto) align-items align-self) 
			   [flex-start 
			    (set! cross-pos p-cross-pos)]
			   [flex-end
			    (set! cross-pos (- (+ p-cross-pos p-cross-size ) cross-size))]
			   [center
			    (set! cross-pos (+ p-cross-pos 
					       (- (/ p-cross-size 2) (/ cross-size 2))))]
			   [baseline (printf "layout-flex: error baseline not supported! defaulting to flex-start~n")
				     (set! cross-pos p-cross-pos)]
			   [stretch
			    (set! cross-pos p-cross-pos)
			    (set! cross-size p-cross-size)])

		      ;; JUSTIFY-CONTENT : main line alignment
			 (case justify-content
			   [(flex-start flex-end)
			    (set! main-pos next-main-pos)
			    (set! next-main-pos (+ main-pos main-size))]
			   [center 
			    (set! main-pos next-main-pos)
			    (set! next-main-pos (+ main-pos main-size))]
			   [space-between 
			    (set! main-pos next-main-pos)
			    (set! next-main-pos (+ main-pos main-size 
						   (if (> n-items 1)
						       (/ free-space (- n-items 1))
						       0)))]
			   [space-around 
			    (set! main-pos next-main-pos)
			    (set! next-main-pos (+ main-pos main-size (/ free-space (+ n-items 1) )))]
			   [stretch ;;NON STANDARD! :D
			    (set! main-size (* (/ flex flex-total) p-main-size))]
			   
			   [else (printf "layout-flex: error unsupported justify-content: ~d~n" 
					 justify-content)])
			 (cond
			  [dir? ; row
			    (mi-element-y-set! e cross-pos)
			    (mi-element-w-set! e main-size)
			    (mi-element-h-set! e cross-size)
			    ;; FIXME: this is calculated differently with wrap.
			    (set! new-w (+ new-w main-size))
			    ;(printf "id ~d new-h ~d cross-size ~d~n" (mi-element-id e) new-h cross-size)
			    (set! new-h (max new-h cross-size))]
			   [else ; column
			    (mi-element-x-set! e cross-pos)
			    (mi-element-h-set! e main-size)
			    (mi-element-w-set! e cross-size)
			    ;; FIXME: this is calculated differently with wrap.
			    (set! new-h (+ new-h main-size))
			    (set! new-w (max new-w cross-size))])
			 (case flex-direction
			   [row
			    (mi-element-x-set! e main-pos)]
			   [row-reverse
			    (let ([rel-main-pos (- main-pos )])
			      (mi-element-x-set! e (- (+ p-main-pos p-main-size) 
						      (- main-pos p-main-pos) 
						      main-size )))]
			   [column
			    (mi-element-y-set! e main-pos)]
			   [column-reverse
			    (let ([rel-main-pos (- main-pos p-main-pos)])
			      (mi-element-y-set! e (- (+ p-main-pos p-main-size) 
						      (- main-pos p-main-pos) 
						      main-size )))])
			   
			 #;(printf "~d size ~d ~d ~d ~d ~d ~d~n" (mi-element-id e) main-pos main-size cross-pos cross-size new-w new-h)))
		children)
      (mi-element-content-size-set! parent (list new-w new-h))))))

(define (mi-element-add-child parent element)
  ;(printf "child add: ~d > ~d~n" (mi-element-id parent) (mi-element-id element))
  (mi-element-children-set! parent (cons element (mi-element-children parent))))

(define (layout-block parent)
  ;(printf "layout-block ~d ls ~d~n" (mi-element-id parent) (mi-state))
  (let* ([children 
	  (sort (lambda (a b) 
		  (< (mi-element-order a) (mi-element-order b)))
		(reverse  (mi-element-children parent)))]
	[n-items (length children)]
	[current-x 0] [current-y 0]
	[p-padding (mi-element-padding parent)]
	[p-w (case (mi-state) 
		  [first (if (number? (mi-element-width parent))
			     (mi-element-width parent)
			     0)]
		  [second (mi-element-w parent)])]
	[p-h (case (mi-state) 
		  [first (if (number? (mi-element-height parent))
			     (mi-element-height parent)
			     0)]
		  [second (mi-element-h parent)]) ]
	[p-x (+ p-padding (mi-element-x parent))]
	[p-y (+ p-padding (mi-element-y parent))]
	[new-w 0] [new-h 0]
	[s-x p-x] [s-y p-y] [s-w 0] [s-h 0])
   ;(printf "parent id ~d xywh ~d ~d ~d ~d ~d ~n" (mi-element-id parent) p-x p-y p-w p-h  p-padding)
    (for-each 
     (lambda (e)
       (cond [(eq? (mi-element-el e) 'force-break)
	     (set! s-x +inf.0)]
	     [(eq? (mi-element-position e) 'absolute) 
	      (layout-element e)]
	     [else
	      (layout-element e)
	      (let*([position (mi-element-position e)]
		 [x (case position [static 0] [relative (mi-element-left e)])]
		 [y (case position [static 0] [relative (mi-element-top e)])]
		 [h (mi-element-height e)]
		 [w (mi-element-width e)]
		 [w-max (let loop ([p parent][m 0])
		      (if p (if (number? (mi-element-width p))
				(- (mi-element-width p) m)
				(loop (mi-element-parent p) (+ m (* 2 (mi-element-padding p)))))
			  0))]
		 [h-max (let loop ([p parent] [m 0]) 
		      (if p (if (number? (mi-element-height p))
				(- (mi-element-height p) m)
				(loop (mi-element-parent p)  (+ m (* 2 (mi-element-padding p)))))
			  0))]
		 [margin (mi-element-margin e)]
		 [padding (mi-element-padding e)]
		 [parent (mi-element-parent e)]
		 [csz (mi-element-content-size e)]
		 [sz-w (+ (* 2 padding) (if (list? csz) (car csz) 0))]
		 [sz-h (+ (* 2 padding) (if (list? csz) (cadr csz) 0))]
		 [w* (case w 
			    [expand 0]
			    [auto sz-w]
			    [else (max w sz-w)])]
		 [h* (case h
			    [expand 0]
			    [auto  sz-h]
			    [else (max h sz-h)])])
	   ;(printf "block ~d ~d ~d ~d ~d ~d ~d ~d s: ~d ~d ~d ~d padding ~d max: ~d ~d~n" (mi-element-id e) x y w h w* h* csz s-x s-y s-w s-h padding w-max h-max)
	     (cond 
	      #;[(equal? `(s-x s-y s-w s-h) '(0 0 0 0))
	      (values (list (+ p-x margin p-padding)))]
	      [(> (+ w* s-w s-x (* 2 p-padding)) p-w)
	       ;; LINE BREAK
	       (if (eq? w 'expand) (set! w* (max w* w-max)))
	       (if (eq? h 'expand) (set! h* (max h* h-max)))
	       (mi-element-x-set! e (+ x p-x  margin))
	       (mi-element-y-set! e (+ y margin s-y s-h))
	       (set! s-x (+ x p-x margin))
	       (set! s-y (+ y s-y s-h))
	       (set! s-w (+ w*  2 margin))
	       (set! s-h (+ h* (* 2 margin)))]
	      [else 
	       ;; SAME LINE
	       (if (eq? w 'expand) (set! w* (- w-max s-w )))
	       (if (eq? h 'expand) (set! h* (- h-max s-h (* 2 (mi-padding)))))
	       
	       (mi-element-x-set! e (+ x s-x s-w margin))
	       (mi-element-y-set! e (+ y margin s-y))
	       (set! s-x (+ x s-x s-w margin))
	       (set! s-y (+ y s-y))
	       (set! s-w (+ x w* margin))
	       (set! s-h (max (+ h* margin) s-h))])

	     (mi-element-w-set! e w*) 
	     (mi-element-h-set! e h*)

	     ;(printf "block ~d x ~d y ~d w ~d h ~d ~n" 
		     (mi-element-id e) (mi-element-x e)
		     (mi-element-y e) (mi-element-w e) (mi-element-h e))]
	     ))
     children)
    (mi-element-content-size-set! parent (list s-w (+ s-h (- s-y p-y))))
    (mi-element-w-set! parent (max s-w p-w))
    (mi-element-h-set! parent (+ s-h (- s-y p-y)))
    #;(printf "s-y p-y s-h ~d ~d ~d sz: ~d wh: ~d ~d~n" s-y p-y s-h 
	    (mi-element-content-size parent) 
	    (mi-element-w parent) (mi-element-h parent))
    ))

(define (absolute-position element)
  (check-arg mi-element? element layout-element)
  (let* ( [x (mi-element-left element)]
	  [y (mi-element-top element)]
	  [w (mi-element-width element)];(style-query (mi-element-style element) 'width 0)]
	  [h (mi-element-height element)];(style-query (mi-element-style element) 'height 0)]
	  [padding (mi-element-padding element)]
	  [csz (mi-element-content-size element)]
	  [sz-w (+ (if (list? csz) (car csz) 0)  (* 2 padding))]
	  [sz-h (+ (if (list? csz) (cadr csz) 0) (* 2 padding))]
	  [w* (case w 
		[auto sz-w]
		[else (max sz-w w)])]
	  [h* (case h
		[auto sz-h]
		[else (max sz-h h)])])
	  (check-arg number? w* layout-element)
	  (check-arg number? h* layout-element) 
	  ;; FIXME absolute should positioned relative to the nearest positioned ancestor (e.g. not static)
    (mi-element-x-set! element x)
    (mi-element-y-set! element y)
    (mi-element-w-set! element w*)
    (mi-element-h-set! element h*)
    (mi-element-layout-state-set! element #t)))

(define (mi-force-break id)
  (check-arg symbol? id mi-force-break)
  (mi-element-add-child (mi-el-by-id id) (make-mi-element 'force-break  #f #f id)))

;; (case (mi-element-display element)
;;     [(flex block)
;;      (mi-element-children-set! element '())]
;;     [else
;;      (printf "start-layout: unsupported display: ~d~n" (mi-element-display element))]))

(define (layout-element element)
  (check-arg mi-element? element layout-element)
  ;(printf "layout element ~d~n" (mi-element-id element))
  (case (mi-element-position element)
    [absolute
     (absolute-position element)])
  (case (mi-element-display element)
    [block
     (layout-block element)]
    [flex
     (layout-flex element)]
    [else #f]))
    
