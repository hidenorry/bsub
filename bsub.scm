#!/usr/bin/env gosh
(use gauche.parseopt)
(use gauche.process)
(use file.util)

(define (write-to-file string file)
  (with-output-to-file file
    (lambda ()
      (print string))))

(define (submit-file file)
  (call-with-input-process
      #"qsub ~|file|"
    port->string))

(define (list2string lis)
  ;; (list2string '("a" "b" "c")) => "a b c  "
  (fold (lambda (l a) (string-append l " " a)) " " (reverse lis)))

(define (add-extension str)
  (string-append str ".sh"))

(define (mkinput file :key (nodes 1) (host bqua) (ppn 1) (nice 10))
  (let (
        (nodes nodes)
        (host host)
        (ppn ppn)
        (nice nice)
        (pwd (current-directory))
        )
    #"#!/bin/sh 
#PBS -l nodes=~|nodes|:~|host|:ppn=~|ppn|
#PBS -j oe
#PBS -l nice=~|nice|
#
#------------------------------------------------
GAUSSVER=g09
DATAHOME=~|pwd|
#------------------------------------------------

cleanup()
{
 /bin/rm -rf $1
         }

#
#trap \"cleanup /work/${USER}/${MOL}.$$ \" 1 2 3 15
for MOL in ~|file|
do
MOL=`basename $MOL`
WORK=/work/${USER}/${MOL}.$$
trap \"cleanup ${WORK}\" 1 2 3 15
#
MOL=${MOL%.inp}
INP=${MOL}.gjf
OUT=${MOL}.out
CHK=${MOL}.chk
#

export LANG=C
export GAUSS_SCRDIR=$WORK
#
#sed 's/NProcShared=4/NProcShared=~|ppn|/g' ${DATAHOME}/${MOL}.inp > ${DATAHOME}/${MOL}.gjf
echo '%NProcShared=~|ppn|'  >  ${DATAHOME}/${MOL}.gjf
cat ${DATAHOME}/${MOL}.inp >> ${DATAHOME}/${MOL}.gjf

if [ ! -d $WORK ]; then mkdir -p $WORK; fi
if [ -f ${DATAHOME}/${CHK} ]; then cp ${DATAHOME}/${CHK} $WORK; fi
#
#cd $DATAHOME
(cd $WORK;
    $GAUSSVER < ${DATAHOME}/${INP} > ${DATAHOME}/${OUT};
    )
#echo $HOSTNAME  >> ${DATAHOME}/${OUT};
#
if [ -f ${WORK}/${CHK} ]; then cp ${WORK}/${CHK} $DATAHOME; fi
mv $WORK/* $DATAHOME
#if [ -d $WORK ]; then /bin/rm -rf $WORK; fi
#
done  

exit 0

"
))

(define (main args)
  ;;(mkinput files :key (nodes 1) (host bqua) (ppn 1) (nice 10))
  (let-args (cdr args)
      (
       (sept   "s|sept"    #f)     ;; submit jobs files separately
       (nodes  "n|nodes=s" "1")    ;; the number of nodes
       (host   "h|host=s"  "bqua") ;; host name
       (ppn    "p|ppn=s"   "4")    ;; the number of core
       (nice   "nice=s"    "10")   ;; the number of nice  normal:10  highest:-20 lowest:19
       . restargs
       )
    (if sept
        (for-each
         (lambda (gfile)
           (let1 ofile (add-extension gfile)
             (write-to-file
              (mkinput gfile :nodes nodes :host host :ppn ppn :nice nice)
              ofile)
            (submit-file ofile)))
         restargs)
        (let ((ofile (add-extension (car restargs))))
          (write-to-file
           (mkinput (list2string restargs) :nodes nodes :host host :ppn ppn :nice nice)
           ofile)
          (submit-file ofile)))
    ))




